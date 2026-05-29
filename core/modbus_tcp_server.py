"""Modbus TCP Server — xuất dữ liệu realtime cho hệ tập trung (SCADA / Central App).

Kiến trúc:
  - Logger giữ vai trò **Modbus RTU Master** xuống cảm biến (worker `ModbusWorker`).
  - Đồng thời mở **Modbus TCP Server (Slave)** trên LAN để Central App đọc bản
    sao gần nhất (snapshot) của các cảm biến đang poll.

Cách đồng bộ giá trị (KHÔNG đẩy xuống SimData mỗi lần cập nhật):
  - `self._registers` là source of truth (cập nhật từ luồng Qt khi có data_ready).
  - Khi pymodbus nhận một request, hàm `action` của SimDevice được gọi trên
    asyncio loop của server; nó **đọc trực tiếp** từ `self._registers` và patch
    đoạn `current_registers[address..address+count]` được yêu cầu.
  - Nhờ đó server không bị "đói lịch" khi luồng Qt cập nhật snapshot liên tục
    (đã từng gây timeout cho mbpoll / pymodbus client).

Bản đồ thanh ghi (register map v1) — Holding Registers, Big-endian / ABCD:

    HR 0     : map version (=1)
    HR 1     : logger status flags
                 bit0 = polling on
                 bit1 = RTU connected
                 bit2 = any alarm
    HR 2..3  : unix timestamp lần cập nhật cuối (uint32)
    HR 4     : sensor count (ANALOG only — DI/DO không nằm trong block HR 10+)
    HR 5     : số kênh DI (FC02 quantity tối đa = Ndi)
    HR 6     : số kênh DO (FC01 quantity tối đa = Ndo)
    HR 10 + i*8 + 0 : sensor_id (uint16)
    HR 10 + i*8 + 1 : per-sensor flags
                       bit0 = valid (đã có giá trị thật)
                       bit1 = alarm
                       bit2 = stale (polling không chạy)
    HR 10 + i*8 + 2..3 : value (float32, ABCD)
    HR 10 + i*8 + 4..7 : reserved

Bản đồ bit (bit map v1):

    HR 5 (Ndi) / HR 6 (Ndo) = max(register_address)+1 trên DI/DO (bit index = register_address).
    FC02 / FC01: bit N = trạng thái sensor có register_address == N (contract Central App).

Sensor được sắp theo `id` tăng dần (chỉ ANALOG/top-level). Map cố định trong
phiên polling — đổi danh sách cảm biến cần restart polling.

Endian xuất TCP cố định ABCD/big-endian, KHÔNG phụ thuộc `data_format` của
từng sensor (data_format chỉ dùng để decode khi đọc RTU). Central App chỉ cần
biết một quy ước duy nhất.

Service v1 chỉ đọc (read-only) — chưa hỗ trợ write_coil / write_register từ
phía Central.

Implementation:
  - `self._registers` (list[int]) là **single source of truth**: mọi update
    snapshot ghi vào đây trước (dùng được trong unit test mà không cần socket).
  - Khi server đang chạy, **pull-mode**: SimDevice được khởi tạo với
    `action=self._sim_action` — pymodbus gọi action mỗi lần có request và
    action patch `current_registers` từ `self._registers`. Không có vòng push.
  - pymodbus 3.13 dùng SimData/SimDevice (API mới); ModbusTcpServer được khởi
    tạo với snapshot hiện tại làm giá trị ban đầu.
  - DI/DO blocks được pre-allocate với _DI_DO_BLOCK_BITS cố định để tránh lỗi
    ILLEGAL_ADDRESS khi TCP server khởi động trước khi set_di_do_map được gọi.
"""

from __future__ import annotations

import asyncio
import logging
import struct
import threading
import time

from PySide6.QtCore import QObject, Property, Signal, Slot

from pymodbus.constants import ExcCodes
from pymodbus.server import ModbusTcpServer
from pymodbus.simulator import DataType, SimData, SimDevice

logger = logging.getLogger("datalogger.modbus_tcp")

# ── Register map constants ───────────────────────────────────────────────
MAP_VERSION = 1
HR_TOTAL = 1024  # đủ cho ~126 sensor (10 + 126*8 = 1018)
HR_VERSION = 0
HR_STATUS = 1
HR_TS_HI = 2
HR_TS_LO = 3
HR_SENSOR_COUNT = 4
HR_NDI = 5
HR_NDO = 6
SENSOR_BASE = 10
SENSOR_STRIDE = 8

# Logger status flags (HR_STATUS)
FLAG_POLLING = 1 << 0
FLAG_RTU_CONNECTED = 1 << 1
FLAG_ANY_ALARM = 1 << 2

# Per-sensor flags
SF_VALID = 1 << 0
SF_ALARM = 1 << 1
SF_STALE = 1 << 2

# Function code 3 = Read Holding Registers (cùng block với write fc=6/16 trong
# pymodbus SimRuntime _fx_mapper).
_FC_HOLDING = 3

# Pre-allocated size for DI/DO bit blocks. Must be a multiple of 16 (pymodbus
# requirement). Fixed at startup so the SimDevice is large enough regardless of
# when set_di_do_map is called relative to server start.
_DI_DO_BLOCK_BITS = 256


def _uint16_wire_to_pymodbus_int(v: int) -> int:
    """Thanh ghi Modbus là 16 bit không dấu trên dây; pymodbus SimData(REGISTERS) pack bằng 'h'.

    Giá trị 0x8000..0xFFFF phải chuyển sang int16 âm (-32768..-1) để struct không lỗi.
    """
    x = int(v) & 0xFFFF
    if x >= 0x8000:
        return x - 0x10000
    return x


def _float32_to_regs_abcd(value: float) -> tuple[int, int]:
    """Encode float32 thành 2 thanh ghi 16-bit theo Big-endian (ABCD)."""
    raw = struct.pack(">f", float(value))
    return struct.unpack(">HH", raw)


def _u32_to_regs(value: int) -> tuple[int, int]:
    v = int(value) & 0xFFFFFFFF
    return (v >> 16) & 0xFFFF, v & 0xFFFF


class ModbusTcpServerService(QObject):
    """Quản lý vòng đời Modbus TCP server + snapshot register map thread-safe."""

    STATE_STOPPED = "stopped"
    STATE_STARTING = "starting"
    STATE_LISTENING = "listening"
    STATE_ERROR = "error"

    stateChanged = Signal()
    lastErrorChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._lock = threading.RLock()
        self._registers: list[int] = [0] * HR_TOTAL
        self._registers[HR_VERSION] = MAP_VERSION

        self._bind = "0.0.0.0"
        self._port = 5020
        self._unit_id = 1

        self._thread: threading.Thread | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._server: ModbusTcpServer | None = None
        self._state = self.STATE_STOPPED
        self._last_error = ""

        # sensor_id -> slot index (0..N-1)
        self._sensor_slots: dict[int, int] = {}

        self._di_map: dict[int, int] = {}  # sensor_id -> FC02 bit index (= register_address)
        self._do_map: dict[int, int] = {}  # sensor_id -> FC01 bit index (= register_address)
        self._di_bits: list[bool] = []
        self._do_bits: list[bool] = []

    # ── QML-facing properties ──────────────────────────────────────────────

    @Property(str, notify=stateChanged)
    def state(self) -> str:
        return self._state

    @Property(bool, notify=stateChanged)
    def isListening(self) -> bool:
        return self._state == self.STATE_LISTENING

    @Property(str, notify=lastErrorChanged)
    def lastError(self) -> str:
        return self._last_error

    @Property(str, notify=stateChanged)
    def listeningEndpoint(self) -> str:
        if self._state != self.STATE_LISTENING:
            return ""
        return f"{self._bind}:{self._port}"

    @Slot(result=str)
    def primaryIp(self) -> str:
        """Trả về IP LAN gần đúng (best effort) để hiển thị trên UI."""
        from core.lan_ip import get_primary_lan_ip

        return get_primary_lan_ip()

    # ── Lifecycle ──────────────────────────────────────────────────────────

    def start(self, bind: str, port: int, unit_id: int) -> None:
        """Khởi động (idempotent — gọi lại cùng cấu hình sẽ bỏ qua)."""
        if self._state in (self.STATE_LISTENING, self.STATE_STARTING):
            if self._bind == bind and self._port == port and self._unit_id == unit_id:
                return
            self.stop()

        self._bind = bind or "0.0.0.0"
        self._port = int(port)
        self._unit_id = int(unit_id)
        self._set_state(self.STATE_STARTING, "")

        self._thread = threading.Thread(
            target=self._run_loop,
            name="ModbusTcpServer",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        loop = self._loop
        server = self._server
        if loop is not None and server is not None and loop.is_running():
            try:
                asyncio.run_coroutine_threadsafe(server.shutdown(), loop)
            except Exception as e:
                logger.warning("server.shutdown() schedule error: %s", e)
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=3.0)
        self._loop = None
        self._thread = None
        self._server = None
        self._set_state(self.STATE_STOPPED, "")

    def _run_loop(self) -> None:
        loop = asyncio.new_event_loop()
        self._loop = loop
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(self._serve())
        except Exception as e:
            logger.error("Modbus TCP server crashed: %s", e, exc_info=True)
            self._set_state(self.STATE_ERROR, str(e))
        finally:
            try:
                loop.close()
            except Exception:
                pass

    async def _serve(self) -> None:
        try:
            with self._lock:
                initial = [_uint16_wire_to_pymodbus_int(x) for x in self._registers]

            coils_data = [SimData(address=0, values=False, datatype=DataType.BITS, count=_DI_DO_BLOCK_BITS)]
            discrete_data = [SimData(address=0, values=False, datatype=DataType.BITS, count=_DI_DO_BLOCK_BITS)]
            holding_data = [SimData(address=0, values=initial, datatype=DataType.REGISTERS, count=HR_TOTAL)]
            input_data = [SimData(address=0, values=0, datatype=DataType.REGISTERS, count=16)]

            dev = SimDevice(
                id=self._unit_id,
                simdata=(coils_data, discrete_data, holding_data, input_data),
                action=self._sim_action,
            )
            self._server = ModbusTcpServer(
                context=[dev],
                address=(self._bind, self._port),
            )
            self._set_state(self.STATE_LISTENING, "")
            logger.info(
                "Modbus TCP server listening %s:%d (unit_id=%d)",
                self._bind, self._port, self._unit_id,
            )
            await self._server.serve_forever()
        except OSError as e:
            logger.error("Modbus TCP bind failed: %s", e)
            self._set_state(self.STATE_ERROR, f"Bind failed: {e}")
        except Exception as e:
            logger.error("Modbus TCP server error: %s", e, exc_info=True)
            self._set_state(self.STATE_ERROR, str(e))
        finally:
            self._server = None
            if self._state == self.STATE_LISTENING:
                self._set_state(self.STATE_STOPPED, "")

    # ── Snapshot API (gọi từ luồng Qt / MonitorController) ─────────────────

    def set_sensor_map(self, sensor_ids: list[int]) -> None:
        """Gán slot index cho từng sensor + reset block, đặt sensor_count."""
        slots: dict[int, int] = {int(sid): idx for idx, sid in enumerate(sensor_ids)}
        with self._lock:
            self._sensor_slots = slots
            for i in range(SENSOR_BASE, HR_TOTAL):
                self._registers[i] = 0
            for sid, idx in slots.items():
                base = SENSOR_BASE + idx * SENSOR_STRIDE
                self._registers[base] = sid & 0xFFFF
            self._registers[HR_SENSOR_COUNT] = len(slots) & 0xFFFF

    def clear_sensor_map(self) -> None:
        """Polling dừng — xóa map, giữ version & status flags."""
        with self._lock:
            self._sensor_slots = {}
            for i in range(SENSOR_BASE, HR_TOTAL):
                self._registers[i] = 0
            self._registers[HR_SENSOR_COUNT] = 0

    def set_di_do_map(self, di_map: dict[int, int], do_map: dict[int, int]) -> None:
        """Map sensor_id -> FC bit index (= register_address); HR_NDI/NDO = max index + 1."""
        with self._lock:
            self._di_map = {int(sid): int(addr) for sid, addr in di_map.items()}
            self._do_map = {int(sid): int(addr) for sid, addr in do_map.items()}
            ndi = max(self._di_map.values()) + 1 if self._di_map else 0
            ndo = max(self._do_map.values()) + 1 if self._do_map else 0
            self._registers[HR_NDI] = ndi & 0xFFFF
            self._registers[HR_NDO] = ndo & 0xFFFF
            self._di_bits = [False] * ndi
            self._do_bits = [False] * ndo

    def update_di(self, sensor_id: int, state: bool) -> None:
        with self._lock:
            idx = self._di_map.get(int(sensor_id))
            if idx is None or idx >= len(self._di_bits):
                return
            self._di_bits[idx] = bool(state)

    def update_do(self, sensor_id: int, state: bool) -> None:
        with self._lock:
            idx = self._do_map.get(int(sensor_id))
            if idx is None or idx >= len(self._do_bits):
                return
            self._do_bits[idx] = bool(state)

    def update_value(self, sensor_id: int, value: float, is_alarm: bool) -> None:
        """Ghi giá trị 1 sensor + cập nhật timestamp + bit any_alarm tổng."""
        idx = self._sensor_slots.get(int(sensor_id))
        if idx is None:
            return
        try:
            hi, lo = _float32_to_regs_abcd(value)
        except (TypeError, ValueError):
            return
        ts_hi, ts_lo = _u32_to_regs(int(time.time()))
        base = SENSOR_BASE + idx * SENSOR_STRIDE
        flags = SF_VALID | (SF_ALARM if is_alarm else 0)

        with self._lock:
            self._registers[base + 1] = flags
            self._registers[base + 2] = hi
            self._registers[base + 3] = lo
            self._registers[HR_TS_HI] = ts_hi
            self._registers[HR_TS_LO] = ts_lo
            self._refresh_any_alarm_bit()

    def _refresh_any_alarm_bit(self) -> None:
        """(Phải gọi khi đã cầm self._lock)."""
        any_alarm = False
        for idx in self._sensor_slots.values():
            f = self._registers[SENSOR_BASE + idx * SENSOR_STRIDE + 1]
            if f & SF_ALARM:
                any_alarm = True
                break
        cur = self._registers[HR_STATUS]
        new = (cur & ~FLAG_ANY_ALARM) | (FLAG_ANY_ALARM if any_alarm else 0)
        self._registers[HR_STATUS] = new

    def set_logger_status(self, polling: bool, rtu_connected: bool) -> None:
        with self._lock:
            cur = self._registers[HR_STATUS]
            new = cur & FLAG_ANY_ALARM  # giữ lại bit any_alarm
            if polling:
                new |= FLAG_POLLING
            if rtu_connected:
                new |= FLAG_RTU_CONNECTED
            self._registers[HR_STATUS] = new
            if not polling:
                self._mark_all_stale()

    def _mark_all_stale(self) -> None:
        """(Phải gọi khi đã cầm self._lock)."""
        for idx in self._sensor_slots.values():
            addr = SENSOR_BASE + idx * SENSOR_STRIDE + 1
            self._registers[addr] = self._registers[addr] | SF_STALE

    # ── Test helpers (read snapshot without socket) ────────────────────────

    def get_register(self, addr: int) -> int:
        with self._lock:
            return self._registers[addr]

    def get_registers(self, addr: int, count: int) -> list[int]:
        with self._lock:
            return list(self._registers[addr:addr + count])

    # ── Internal ───────────────────────────────────────────────────────────

    async def _sim_action(
        self,
        function_code: int,
        start_address: int,
        address: int,
        count: int,
        current_registers: list[int],
        set_values,
    ):
        """Hook pymodbus: được gọi trên asyncio loop khi có request.

        - Read holding (FC=3): patch đoạn `current_registers` được yêu cầu từ
          snapshot `self._registers` (do Qt thread cập nhật, có lock).
          Giá trị ghi vào `current_registers` là **uint16 unsigned (0..65535)** —
          chính là dạng SimData lưu nội bộ sau khi đã được constructor chuyển từ
          signed `h` về unsigned qua `bytesToRegisters`. Nếu ghi signed (âm), bước
          đóng gói response của pymodbus dùng `struct.pack(">H", v)` sẽ raise.
        - Read Discrete Inputs (FC=2) & Read Coils (FC=1): đồng bộ mảng bit trạng thái
          chuyển đổi qua SimUtils.bitsToRegisters vào current_registers.
        - Write (FC=6/16): bỏ qua — map v1 read-only.
        """
        if set_values is not None:
            return None

        if function_code == _FC_HOLDING:
            offset = address - start_address
            if offset < 0 or count <= 0:
                return None
            end_src = min(address + count, HR_TOTAL)
            src_count = max(0, end_src - address)
            if src_count <= 0:
                return None
            with self._lock:
                slice_vals = [int(v) & 0xFFFF for v in self._registers[address:address + src_count]]
            end_dst = min(offset + src_count, len(current_registers))
            for i in range(end_dst - offset):
                current_registers[offset + i] = slice_vals[i]
            return None

        if function_code == 2:  # FC02: Read Discrete Inputs
            return self._read_bit_block(
                address, count, current_registers, self._di_bits,
            )

        if function_code == 1:  # FC01: Read Coils
            return self._read_bit_block(
                address, count, current_registers, self._do_bits,
            )

        return None

    def _read_bit_block(
        self,
        address: int,
        count: int,
        current_registers: list[int],
        bit_states: list[bool],
    ):
        """Serve FC01/FC02.

        pymodbus `get_bit_block` passes `count = int(bit_count/16)+1` (register units)
        and `current_registers` = the FULL device block. After our action returns, pymodbus
        reads `registers[0:reg_count]` and converts to bits via `registersToBits`.
        Therefore we must write PACKED words (16 bits per register, LSB-first) to
        `current_registers[0..]`, NOT one-entry-per-bit.
        """
        from pymodbus.simulator.simutils import SimUtils

        with self._lock:
            n = len(bit_states)
        if n == 0 or address >= n or count <= 0:
            return ExcCodes.ILLEGAL_ADDRESS

        num_bits = min(n - address, count * 16)
        if num_bits <= 0:
            return ExcCodes.ILLEGAL_ADDRESS

        for i in range(len(current_registers)):
            current_registers[i] = 0

        slice_bits = [bool(bit_states[address + i]) for i in range(num_bits)]
        pad = (16 - (len(slice_bits) % 16)) % 16
        slice_bits.extend([False] * pad)
        regs = SimUtils.bitsToRegisters(slice_bits)
        end_dst = min(len(regs), len(current_registers))
        for i in range(end_dst):
            current_registers[i] = regs[i]
        return None

    def _set_state(self, state: str, err: str) -> None:
        changed_state = state != self._state
        changed_err = err != self._last_error
        self._state = state
        self._last_error = err
        if changed_state:
            self.stateChanged.emit()
        if changed_err:
            self.lastErrorChanged.emit()
