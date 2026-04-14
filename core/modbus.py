"""
Modbus Communication Module.
Supports both RTU (serial) and TCP connections.
"""
import logging
import struct
from abc import ABC, abstractmethod
from typing import Any, List, Union

from pymodbus.client import ModbusSerialClient, ModbusTcpClient

logger = logging.getLogger(__name__)


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
    
    def read(self, reg_type: str, addr: int, count: int, slave: int, data_type: str) -> Any:
        """Read Modbus data and decode."""
        if not self.is_connected():
            raise ConnectionError("Device not connected")

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

        if hasattr(result, "registers"):
            regs = result.registers
            return self.decode_data(regs, data_type)
        elif hasattr(result, "bits"):
            return result.bits
        else:
            raise IOError("No data returned from device")

    def write(self, reg_type: str, addr: int, value: Any, slave: int, data_type: str) -> bool:
        """Write Modbus data."""
        if not self.is_connected():
            raise ConnectionError("Device not connected")

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
    def decode_data(regs: List[int], data_type: str) -> Union[int, float, List[int]]:
        """Decode register values based on data type."""
        dt_lower = str(data_type).lower()
        if dt_lower == "decimal":
            return regs[0] if len(regs) == 1 else regs
        if dt_lower == "float" and len(regs) >= 2:
            return round(struct.unpack(">f", struct.pack(">HH", regs[0], regs[1]))[0], 4)
        if dt_lower in ["swapped float", "swapped_float"] and len(regs) >= 2:
            return round(struct.unpack(">f", struct.pack(">HH", regs[1], regs[0]))[0], 4)
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


class ModbusTCP(ModbusBase):
    """Modbus TCP client."""
    
    def connect(
        self,
        host: str,
        port: int = 502,
        timeout: int = 5
    ) -> bool:
        """
        Connect to a Modbus TCP device.
        
        Args:
            host: IP address or hostname
            port: TCP port (default: 502)
            timeout: Connection timeout in seconds (default: 5)
            
        Returns:
            True if connected successfully
        """
        if self.client and self.client.connected:
            self.client.close()

        self.client = ModbusTcpClient(
            host=host,
            port=int(port),
            timeout=timeout
        )
        
        if self.client.connect():
            logger.info(f"✅ Connected to TCP device at {host}:{port}")
            return True
        else:
            logger.error(f"❌ Failed to connect to {host}:{port}")
            return False


# Backward compatibility alias
class Modbus(ModbusRTU):
    """
    Legacy Modbus class for backward compatibility.
    Inherits from ModbusRTU to maintain existing behavior.
    """
    pass


def create_modbus_client(modbus_type: str = "RTU") -> ModbusBase:
    """
    Factory function to create the appropriate Modbus client.
    
    Args:
        modbus_type: "RTU" or "TCP"
        
    Returns:
        ModbusRTU or ModbusTCP instance
    """
    if modbus_type.upper() == "TCP":
        return ModbusTCP()
    else:
        return ModbusRTU()
