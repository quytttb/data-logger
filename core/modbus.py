"""
Modbus Communication Module — Modbus RTU (serial) only.

Modbus TCP is not supported in this version; it may be added later if needed.
"""
import logging
import struct
from abc import ABC, abstractmethod
from typing import Any, List, Union

from pymodbus.client import ModbusSerialClient

logger = logging.getLogger(__name__)

# DB / ModbusWorker dùng "holding" | "input"; Modbus Tester (QML) dùng nhãn đầy đủ.
_REG_TYPE_ALIASES: dict[str, str] = {
    "holding": "Holding Register",
    "holding registers": "Holding Register",
    "holding register": "Holding Register",
    "hr": "Holding Register",
    "input": "Input Register",
    "input registers": "Input Register",
    "input register": "Input Register",
    "ir": "Input Register",
    "coil": "Coil",
    "coils": "Coil",
    "discrete input": "Discrete Input",
    "discrete inputs": "Discrete Input",
    "inputs": "Discrete Input",
    "discrete_input": "Discrete Input",
    "di": "Discrete Input",
    "invalid": "Invalid"
}


def _normalize_register_type(reg_type: str) -> str:
    """Chuẩn hoá loại thanh ghi về nhãn dùng nội bộ (khớp func_map)."""
    key = str(reg_type).strip()
    return _REG_TYPE_ALIASES.get(key.lower(), key)


class ModbusBase(ABC):
    """Abstract base class for Modbus clients."""
    
    def __init__(self):
        self.client = None
    
    @abstractmethod
    def connect(self, **kwargs) -> bool:
        """Connect to the Modbus device."""
        pass
    
    def disconnect(self):
        """Disconnect from the Modbus device."""
        if self.client and self.client.connected:
            self.client.close()
            logger.info("🔴 Disconnected")
    
    def is_connected(self) -> bool:
        """Check if connected to a device."""
        return self.client is not None and self.client.connected
    
    def read(self, reg_type: str, addr: int, count: int, slave: int,
             data_type: str, data_format: str = "ABCD") -> Any:
        """Read Modbus data and decode."""
        if not self.is_connected():
            raise ConnectionError("Device not connected")

        reg_type = _normalize_register_type(reg_type)

        func_map = {
            "Holding Register": "read_holding_registers",
            "Input Register": "read_input_registers",
            "Coil": "read_coils",
            "Discrete Input": "read_discrete_inputs"
        }

        if reg_type not in func_map:
            raise ValueError(f"Invalid register type: {reg_type}")

        # Handle parameter compatibility for pymodbus 3.x vs older versions
        kwargs = {"count": count}
        # 3.0+ uses slave= or device_id= depending on minor version, try inspection
        try:
            import inspect
            sig = inspect.signature(getattr(self.client, func_map[reg_type]))
            if "device_id" in sig.parameters:
                kwargs["device_id"] = slave
            elif "slave" in sig.parameters:
                kwargs["slave"] = slave
            else:
                kwargs["unit"] = slave # Fallback for <3.0
        except Exception:
            kwargs["slave"] = slave

        result = getattr(self.client, func_map[reg_type])(addr, **kwargs)
        if result.isError():
            raise IOError(f"Modbus read error: {result}")

        # Phân tách logic xử lý trả về theo loại thanh ghi
        if reg_type in ["Coil", "Discrete Input"]:
            if hasattr(result, "bits"):
                # Pymodbus luôn trả về danh sách bits.
                # Lấy bit đầu tiên vì count=1 (cho mỗi address scan), trả về 1 hoặc 0 cho giao diện.
                return 1 if result.bits[0] else 0
            raise IOError("No boolean data returned from device")
        else:
            if hasattr(result, "registers"):
                regs = result.registers
                return self.decode_data(regs, data_type, data_format)
            raise IOError("No register data returned from device")

    def write(self, reg_type: str, addr: int, value: Any, slave: int, data_type: str) -> bool:
        """Write Modbus data."""
        if not self.is_connected():
            raise ConnectionError("Device not connected")

        reg_type = _normalize_register_type(reg_type)

        kwargs = {}
        try:
            import inspect
            if reg_type == "Coil":
                func_name = "write_coil"
            else:
                encoded_preview = self.encode_data(value, data_type)
                func_name = "write_registers" if isinstance(encoded_preview, list) else "write_register"
            sig = inspect.signature(getattr(self.client, func_name))
            if "device_id" in sig.parameters:
                kwargs["device_id"] = slave
            elif "slave" in sig.parameters:
                kwargs["slave"] = slave
            else:
                kwargs["unit"] = slave
        except Exception:
            kwargs["slave"] = slave

        if reg_type == "Coil":
            val = bool(int(value))
            result = self.client.write_coil(addr, val, **kwargs)
        else:
            val = self.encode_data(value, data_type)
            if isinstance(val, list):
                result = self.client.write_registers(addr, val, **kwargs)
            else:
                result = self.client.write_register(addr, val, **kwargs)

        if result.isError():
            raise IOError(f"Modbus write error: {result}")

        return True

    @staticmethod
    def _pack_regs_32(regs: List[int], data_format: str) -> bytes:
        """Pack two 16-bit registers into 4 bytes respecting endianness.

        Supported formats:
            AB / ABCD  — Big-endian (default, Modicon standard)
            BA / CDAB  — Big-endian word-swapped (Schneider, ABB)
            BADC       — Little-endian
            DCBA       — Little-endian word-swapped
        """
        fmt = data_format.upper().strip()
        if fmt in ("CDAB", "BA"):
            return struct.pack(">HH", regs[1], regs[0])
        if fmt == "BADC":
            return struct.pack("<HH", regs[0], regs[1])
        if fmt == "DCBA":
            return struct.pack("<HH", regs[1], regs[0])
        # Default: ABCD / AB
        return struct.pack(">HH", regs[0], regs[1])

    @staticmethod
    def decode_data(regs: List[int], data_type: str,
                    data_format: str = "ABCD") -> Union[int, float, List[int]]:
        """Decode register values based on data type and byte order.

        Supports both legacy names (Decimal, Float, Swapped Float) for Tester
        and new standard names (int16, uint16, int32, uint32, float32) for sensors.

        Args:
            regs: Raw register values from Modbus read.
            data_type: Type name (int16, uint16, float32, Decimal, Float, ...).
            data_format: Byte order for 32-bit types (ABCD, CDAB, BADC, DCBA).
                         Defaults to ABCD (Big-endian). Ignored for 16-bit types.
        """
        dt_lower = str(data_type).lower().replace(" ", "_")

        # Legacy Tester names
        if dt_lower == "decimal":
            return regs[0] if len(regs) == 1 else regs
        if dt_lower == "float" and len(regs) >= 2:
            raw = ModbusBase._pack_regs_32(regs, data_format)
            return round(struct.unpack(">f", raw)[0], 4)
        if dt_lower == "swapped_float" and len(regs) >= 2:
            # Legacy: always word-swap regardless of data_format
            raw = struct.pack(">HH", regs[1], regs[0])
            return round(struct.unpack(">f", raw)[0], 4)

        # Standard sensor data types — 16-bit
        if dt_lower == "uint16":
            return regs[0] if len(regs) >= 1 else regs
        if dt_lower == "int16":
            val = regs[0] if len(regs) >= 1 else 0
            return val - 65536 if val >= 32768 else val

        # Standard sensor data types — 32-bit (endian-aware)
        if dt_lower == "uint32" and len(regs) >= 2:
            raw = ModbusBase._pack_regs_32(regs, data_format)
            fmt = "<I" if data_format.upper().strip() in ("BADC", "DCBA") else ">I"
            return struct.unpack(fmt, raw)[0]
        if dt_lower == "int32" and len(regs) >= 2:
            raw = ModbusBase._pack_regs_32(regs, data_format)
            fmt = "<i" if data_format.upper().strip() in ("BADC", "DCBA") else ">i"
            return struct.unpack(fmt, raw)[0]
        if dt_lower == "float32" and len(regs) >= 2:
            raw = ModbusBase._pack_regs_32(regs, data_format)
            fmt = "<f" if data_format.upper().strip() in ("BADC", "DCBA") else ">f"
            return round(struct.unpack(fmt, raw)[0], 4)

        return regs

    @staticmethod
    def encode_data(value: Any, data_type: str) -> Union[int, List[int]]:
        """Encode value to register format based on data type."""
        dt_lower = str(data_type).lower()
        if dt_lower == "decimal":
            return int(value)
        if dt_lower == "float":
            f = float(value)
            b = struct.pack(">f", f)
            return list(struct.unpack(">HH", b))
        if dt_lower in ["swapped float", "swapped_float"]:
            f = float(value)
            b = struct.pack(">f", f)
            r1, r2 = struct.unpack(">HH", b)
            return [r2, r1]
        return int(value)


class ModbusRTU(ModbusBase):
    """Modbus RTU (Serial) client."""
    
    def connect(
        self,
        port: str,
        baudrate: int = 9600,
        bytesize: int = 8,
        parity: str = "N",
        stopbits: int = 1,
        timeout: int = 2
    ) -> bool:
        """
        Connect to a Modbus RTU device via serial port.
        
        Args:
            port: Serial port (e.g., /dev/ttyUSB0)
            baudrate: Communication speed (default: 9600)
            bytesize: Data bits (default: 8)
            parity: Parity check - N/E/O (default: N)
            stopbits: Stop bits (default: 1)
            timeout: Read timeout in seconds (default: 2)
            
        Returns:
            True if connected successfully
        """
        if self.client and self.client.connected:
            self.client.close()

        # ── Kiểm tra quyền truy cập cổng serial ──
        import os
        if os.path.exists(port) and not os.access(port, os.R_OK | os.W_OK):
            logger.warning(f"⚠️ Không có quyền truy cập {port}, đang thử cấp quyền...")
            if not self._try_fix_permission(port):
                raise PermissionError(
                    f"Không có quyền truy cập cổng {port}.\n"
                    f"Hãy chạy lệnh sau trong Terminal rồi thử lại:\n"
                    f"  sudo chmod a+rw {port}\n"
                    f"  sudo usermod -aG dialout $USER"
                )

        self.client = ModbusSerialClient(
            port=port,
            baudrate=int(baudrate),
            bytesize=int(bytesize),
            parity=parity,
            stopbits=int(stopbits),
            timeout=timeout
        )
        
        if self.client.connect():
            logger.info(f"✅ Connected to RTU device at {port}")
            return True
        else:
            logger.error(f"❌ Failed to connect to {port}")
            return False

    @staticmethod
    def _try_fix_permission(port: str) -> bool:
        """Thử cấp quyền truy cập cổng serial qua pkexec (hộp thoại nhập mật khẩu đồ hoạ)."""
        import subprocess
        import shutil
        # Ưu tiên pkexec (có GUI prompt), fallback sang gksu/kdesu
        for sudo_gui in ("pkexec", "gksudo", "kdesudo"):
            if shutil.which(sudo_gui):
                try:
                    result = subprocess.run(
                        [sudo_gui, "chmod", "a+rw", port],
                        timeout=60,  # Cho phép người dùng 60s nhập mật khẩu
                    )
                    if result.returncode == 0:
                        logger.info(f"✅ Đã cấp quyền truy cập {port} thành công")
                        # Thêm user vào nhóm dialout (cho các lần sau)
                        import os
                        user = os.environ.get("USER", "")
                        if user:
                            subprocess.run(
                                [sudo_gui, "usermod", "-aG", "dialout", user],
                                timeout=10,
                            )
                        return True
                except (subprocess.TimeoutExpired, Exception) as e:
                    logger.warning(f"Cấp quyền bằng {sudo_gui} thất bại: {e}")
                    continue
        return False


# Backward compatibility alias
class Modbus(ModbusRTU):
    """
    Legacy Modbus class for backward compatibility.
    Inherits from ModbusRTU to maintain existing behavior.
    """
    pass


def create_modbus_client(modbus_type: str = "RTU") -> ModbusRTU:
    """Return a Modbus RTU (serial) client. TCP is not supported (may be added later)."""
    if (modbus_type or "RTU").upper() != "RTU":
        raise ValueError(
            "Chỉ hỗ trợ Modbus RTU (RS-485/serial). Modbus TCP chưa triển khai — có thể bổ sung sau."
        )
    return ModbusRTU()
