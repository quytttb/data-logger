#!/usr/bin/env python3
"""Modbus RTU slave gia lap cho Data Logger tren Raspberry Pi.

Register map cua slave:
  Holding register (4x)
    0   int16   Nhiet do, don vi 0.1 C (giu tuong thich simulator cu)
    10  uint16  Do am, don vi 0.1 %RH
    20  int32   Ap suat, Pa (ABCD)
    30  uint32  Tong luu luong, L (ABCD)
    40  float32 Luu luong, m3/h (ABCD)
  Input register (3x)
    0   int16   Nhiet do thiet bi, don vi 0.1 C
    10  float32 Muc bon, % (ABCD)
  Discrete input (1x)
    0   DI loai 00: Monitoring
    1   DI loai 01: Calibrating
    2   DI loai 02: Error
    3   DI loai 03: Maintenance
  (4 trang thai DI luan phien, moi thoi diem chi 1 DI on)
  Coil (0x)
    0   DO lien ket alarm max
    1   DO lien ket alarm min
    2   DO doc lap / dieu khien tay

Alarm duoc tinh o Data Logger. Nhiet do holding[0] dao dong quanh gia tri
--value voi bien do --amplitude, de nguong min/max trong app co the kich hoat
DO va hien thi alarm.
"""

import argparse
import logging
import math
import struct
import threading
import time

from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from pymodbus.server import StartSerialServer

# pymodbus 3.8.x dùng FramerType enum; 3.6.x dùng class ModbusRtuFramer.
try:
    from pymodbus.framer import FramerType
    RTU_FRAMER = FramerType.RTU
except ImportError:
    from pymodbus.framer import ModbusRtuFramer
    RTU_FRAMER = ModbusRtuFramer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True)
    parser.add_argument("--slave-id", type=int, default=1)
    parser.add_argument("--baudrate", type=int, default=9600)
    parser.add_argument("--value", type=float, default=25.0)
    parser.add_argument("--amplitude", type=float, default=10.0)
    parser.add_argument("--period", type=float, default=60.0)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    holding = ModbusSequentialDataBlock(0, [0] * 128)
    inputs = ModbusSequentialDataBlock(0, [0] * 128)
    coils = ModbusSequentialDataBlock(0, [0] * 32)
    discrete_inputs = ModbusSequentialDataBlock(0, [0] * 32)
    # pymodbus 3.6.x accepts zero_mode in constructor; 3.8.x removed it.
    try:
        context = ModbusSlaveContext(
            hr=holding, ir=inputs, co=coils, di=discrete_inputs, zero_mode=True
        )
    except TypeError:
        context = ModbusSlaveContext(hr=holding, ir=inputs, co=coils, di=discrete_inputs)
        context.zero_mode = True
    server_context = ModbusServerContext(slaves={args.slave_id: context}, single=False)

    def write_u32(block: ModbusSequentialDataBlock, address: int, value: int) -> None:
        raw = value & 0xFFFFFFFF
        words = [(raw >> 16) & 0xFFFF, raw & 0xFFFF]
        # Một số bản pymodbus áp dụng offset +1 khi dispatch RTU request.
        block.setValues(address, words)
        block.setValues(address + 1, words)

    def write_float32(block: ModbusSequentialDataBlock, address: int, value: float) -> None:
        raw = struct.unpack(">I", struct.pack(">f", value))[0]
        write_u32(block, address, raw)

    def update_value() -> None:
        phase = time.time() * 2 * math.pi / args.period
        temperature = args.value + args.amplitude * math.sin(phase)
        humidity = 55.0 + 20.0 * math.sin(phase / 1.4)
        pressure = 101_325 + round(8_000 * math.sin(phase / 1.9))
        total_flow = 250_000 + round(20_000 * (1.0 + math.sin(phase / 2.2)))
        flow = 12.5 + 7.5 * math.sin(phase / 1.6)
        device_temperature = 31.0 + 6.0 * math.sin(phase / 1.3)
        tank_level = 50.0 + 45.0 * math.sin(phase / 2.5)

        temp_word = max(-32768, min(32767, round(temperature * 10))) & 0xFFFF
        humidity_word = max(0, min(65535, round(humidity * 10)))
        holding.setValues(0, [temp_word, temp_word])
        holding.setValues(10, [humidity_word, humidity_word])
        write_u32(holding, 20, pressure)
        write_u32(holding, 30, total_flow)
        write_float32(holding, 40, flow)
        device_temp_word = max(-32768, min(32767, round(device_temperature * 10))) & 0xFFFF
        inputs.setValues(0, [device_temp_word, device_temp_word])
        write_float32(inputs, 10, tank_level)

        # Luân phiên Monitoring -> Calibrating -> Error -> Maintenance, mỗi
        # trạng thái giữ 15 giây; mỗi thời điểm chỉ một DI được bật.
        state = int(time.time() / 15) % 4
        discrete_inputs.setValues(0, [
            1 if state == 0 else 0,
            1 if state == 1 else 0,
            1 if state == 2 else 0,
            1 if state == 3 else 0,
        ])
        discrete_inputs.setValues(4, [
            1 if state == 0 else 0,
            1 if state == 1 else 0,
            1 if state == 2 else 0,
            1 if state == 3 else 0,
        ])

    update_value()
    def updater() -> None:
        while True:
            update_value()
            time.sleep(1)

    threading.Thread(target=updater, daemon=True).start()
    logging.info(
        "Gia lap slave=%d port=%s baudrate=%d; analog 4x/3x, DI 1x, DO 0x; "
        "holding[0]=%.1f +/- %.1f",
        args.slave_id, args.port, args.baudrate, args.value, args.amplitude,
    )
    StartSerialServer(
        context=server_context,
        framer=RTU_FRAMER,
        port=args.port,
        baudrate=args.baudrate,
        bytesize=8,
        parity="N",
        stopbits=1,
        timeout=1,
    )


if __name__ == "__main__":
    main()
