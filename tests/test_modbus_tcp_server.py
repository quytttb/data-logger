"""Test Modbus TCP Server — register map snapshot (no real socket).

Kiểm tra encode float32 ABCD, set/clear sensor map, status flags, stale bit.
"""

import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pymodbus.constants import ExcCodes

from core.modbus_tcp_server import (
    FLAG_ANY_ALARM,
    FLAG_POLLING,
    FLAG_RTU_CONNECTED,
    HR_SENSOR_COUNT,
    HR_STATUS,
    HR_TS_HI,
    HR_VERSION,
    HR_NDI,
    HR_NDO,
    MAP_VERSION,
    SENSOR_BASE,
    SENSOR_STRIDE,
    SF_ALARM,
    SF_STALE,
    SF_VALID,
    ModbusTcpServerService,
    _float32_to_regs_abcd,
)


def _read(svc: ModbusTcpServerService, addr: int, count: int = 1):
    return svc.get_registers(addr, count)


def test_encode_float32_abcd():
    hi, lo = _float32_to_regs_abcd(1.5)
    raw = struct.pack(">HH", hi, lo)
    assert struct.unpack(">f", raw)[0] == 1.5
    print("  float32 ABCD round-trip OK ✓")


def test_initial_state():
    svc = ModbusTcpServerService()
    assert _read(svc, HR_VERSION)[0] == MAP_VERSION
    assert _read(svc, HR_STATUS)[0] == 0
    assert _read(svc, HR_SENSOR_COUNT)[0] == 0
    print("  initial register state OK ✓")


def test_set_sensor_map_and_update_value():
    svc = ModbusTcpServerService()
    svc.set_sensor_map([10, 20, 30])
    assert _read(svc, HR_SENSOR_COUNT)[0] == 3

    base0 = SENSOR_BASE + 0 * SENSOR_STRIDE
    base1 = SENSOR_BASE + 1 * SENSOR_STRIDE
    assert _read(svc, base0)[0] == 10
    assert _read(svc, base1)[0] == 20

    svc.update_value(sensor_id=20, value=3.25, is_alarm=False)
    flags = _read(svc, base1 + 1)[0]
    assert flags & SF_VALID and not (flags & SF_ALARM)

    hi, lo = _read(svc, base1 + 2, 2)
    val = struct.unpack(">f", struct.pack(">HH", hi, lo))[0]
    assert val == 3.25

    ts_hi, ts_lo = _read(svc, HR_TS_HI, 2)
    assert (ts_hi << 16 | ts_lo) > 0
    print("  set_sensor_map + update_value OK ✓")


def test_alarm_and_any_alarm_flag():
    svc = ModbusTcpServerService()
    svc.set_sensor_map([1, 2])
    svc.update_value(1, 10.0, is_alarm=False)
    assert (_read(svc, HR_STATUS)[0] & FLAG_ANY_ALARM) == 0

    svc.update_value(2, 99.0, is_alarm=True)
    assert _read(svc, HR_STATUS)[0] & FLAG_ANY_ALARM
    flags2 = _read(svc, SENSOR_BASE + SENSOR_STRIDE + 1)[0]
    assert flags2 & SF_ALARM

    svc.update_value(2, 50.0, is_alarm=False)
    assert (_read(svc, HR_STATUS)[0] & FLAG_ANY_ALARM) == 0
    print("  alarm bits propagate to HR_STATUS OK ✓")


def test_logger_status_and_stale():
    svc = ModbusTcpServerService()
    svc.set_sensor_map([7])
    svc.update_value(7, 1.0, is_alarm=False)

    svc.set_logger_status(polling=True, rtu_connected=True)
    s = _read(svc, HR_STATUS)[0]
    assert s & FLAG_POLLING and s & FLAG_RTU_CONNECTED

    svc.set_logger_status(polling=False, rtu_connected=False)
    s = _read(svc, HR_STATUS)[0]
    assert (s & FLAG_POLLING) == 0
    f = _read(svc, SENSOR_BASE + 1)[0]
    assert f & SF_STALE, "stale bit must be set when polling stops"
    print("  logger_status + stale flag OK ✓")


def test_unknown_sensor_id_is_noop():
    svc = ModbusTcpServerService()
    svc.set_sensor_map([1])
    svc.update_value(999, 42.0, is_alarm=False)  # not in map
    flags = _read(svc, SENSOR_BASE + 1)[0]
    assert flags == 0
    print("  unknown sensor_id is no-op OK ✓")


def test_clear_sensor_map():
    svc = ModbusTcpServerService()
    svc.set_sensor_map([1, 2, 3])
    svc.update_value(1, 5.0, is_alarm=False)
    svc.clear_sensor_map()
    assert _read(svc, HR_SENSOR_COUNT)[0] == 0
    assert _read(svc, SENSOR_BASE)[0] == 0
    print("  clear_sensor_map zeros block OK ✓")


def test_di_do_map_and_updates():
    svc = ModbusTcpServerService()
    di_map = {101: 0, 102: 2}
    do_map = {201: 1}
    svc.set_di_do_map(di_map, do_map)

    assert _read(svc, HR_NDI)[0] == 3
    assert _read(svc, HR_NDO)[0] == 2

    svc.update_di(101, True)
    svc.update_di(102, False)
    svc.update_do(201, True)

    assert svc._di_bits[0] is True
    assert svc._di_bits[2] is False
    assert svc._do_bits[1] is True

    svc.update_di(999, True)

    # Test _sim_action for FC02 (Discrete Inputs)
    current_regs_di = [0, 0]
    import asyncio
    async def run_action_di():
        await svc._sim_action(
            function_code=2,
            start_address=0,
            address=0,
            count=1,
            current_registers=current_regs_di,
            set_values=None
        )
    asyncio.run(run_action_di())
    assert current_regs_di[0] == 1  # only bit 0 is True -> 1

    async def run_action_di_oversize():
        return await svc._sim_action(
            function_code=2,
            start_address=0,
            address=3,
            count=1,
            current_registers=[0],
            set_values=None,
        )
    assert asyncio.run(run_action_di_oversize()) == ExcCodes.ILLEGAL_ADDRESS

    # pymodbus passes reg_count=1 for a 12-bit FC02 read; bit 10 must appear in word
    svc2 = ModbusTcpServerService()
    svc2.set_di_do_map({16: 10, 17: 11}, {14: 0})
    svc2.update_di(16, True)
    current_sparse = [0]
    async def run_action_di_sparse():
        await svc2._sim_action(
            function_code=2,
            start_address=0,
            address=0,
            count=1,
            current_registers=current_sparse,
            set_values=None,
        )
    asyncio.run(run_action_di_sparse())
    assert current_sparse[0] == 1024

    # Test _sim_action for FC01 (Coils)
    current_regs_do2 = [0, 0]
    async def run_action_do():
        return await svc._sim_action(
            function_code=1,
            start_address=0,
            address=0,
            count=2,
            current_registers=current_regs_do2,
            set_values=None
        )
    asyncio.run(run_action_do())
    assert current_regs_do2[0] == 2  # packed: bit1=True → reg0 = 0b10 = 2

    print("  di_do_map + updates + sim_action OK ✓")


if __name__ == "__main__":
    print("=== Modbus TCP Server tests ===")
    test_encode_float32_abcd()
    test_initial_state()
    test_set_sensor_map_and_update_value()
    test_alarm_and_any_alarm_flag()
    test_logger_status_and_stale()
    test_unknown_sensor_id_is_noop()
    test_clear_sensor_map()
    test_di_do_map_and_updates()
    print("All Modbus TCP Server tests passed ✓")
