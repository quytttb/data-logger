import logging

import serial.tools.list_ports
from PySide6.QtCore import QObject, QThread, Slot, Signal, Property

from core.modbus import create_modbus_client
from workers.scan_worker import ScanWorker

logger = logging.getLogger(__name__)


class _ConnectWorker(QThread):
    """Chạy modbus.connect() trong background để tránh block UI."""

    finished = Signal(bool, str)  # (success, port)
    error = Signal(str)  # error message

    def __init__(self, modbus, port, baudrate, bytesize, parity, stopbits, parent=None):
        super().__init__(parent)
        self._modbus = modbus
        self._port = port
        self._baudrate = baudrate
        self._bytesize = bytesize
        self._parity = parity
        self._stopbits = stopbits

    def run(self):
        try:
            ok = self._modbus.connect(
                port=self._port,
                baudrate=self._baudrate,
                bytesize=self._bytesize,
                parity=self._parity,
                stopbits=self._stopbits,
                timeout=1,
            )
            self.finished.emit(bool(ok), self._port)
        except Exception as exc:
            logger.error("connect_serial exception: %s", exc)
            self.error.emit(str(exc))


class TesterController(QObject):
    connectionChanged = Signal(bool)
    connectingChanged = Signal(bool)
    scanningChanged = Signal(bool)
    stoppingChanged = Signal()
    messageReceived = Signal(str, str, bool)  # title, message, isError → QML: Dialog vs toast
    scanResultReceived = Signal(int, str)
    scanProgress = Signal(int, int)
    portsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.modbus = create_modbus_client()
        self._is_connected = False
        self._is_connecting = False
        self._is_scanning = False
        self._is_stopping = False
        self._scan_worker = None
        self._connect_worker = None
        self._ports: list[str] = []
        self._refresh_ports()

    # ── Port scanning ──

    def _refresh_ports(self):
        try:
            import glob

            ports = serial.tools.list_ports.comports()
            # Lọc bỏ các cổng chung chung không khả dụng (ttyS* n/a)
            valid_ports = [p.device for p in ports if p.description != "n/a" or "USB" in p.device]
            self._ports = sorted(valid_ports)

            pts_ports = [p for p in glob.glob("/dev/pts/*") if p != "/dev/pts/ptmx"]
            for p in sorted(pts_ports):
                if p not in self._ports:
                    self._ports.append(p)
        except Exception:
            self._ports = []
        if not self._ports:
            self._ports = ["/dev/ttyUSB0"]

    @Property("QVariantList", notify=portsChanged)
    def availablePorts(self):
        return self._ports

    @Slot()
    def refresh_ports(self):
        self._refresh_ports()
        self.portsChanged.emit()

    @Property(bool, notify=connectionChanged)
    def isConnected(self):
        return self._is_connected

    @Property(bool, notify=connectingChanged)
    def isConnecting(self):
        return self._is_connecting

    @Property(bool, notify=scanningChanged)
    def isScanning(self):
        return self._is_scanning

    @Property(bool, notify=stoppingChanged)
    def isStopping(self):
        return self._is_stopping

    def _set_connecting(self, val: bool):
        if self._is_connecting != val:
            self._is_connecting = val
            self.connectingChanged.emit(val)

    def _on_connect_finished(self, success: bool, port: str):
        self._is_connected = success
        self._set_connecting(False)
        self.connectionChanged.emit(self._is_connected)
        if success:
            self.messageReceived.emit(
                "Success",
                "Connected to port {0}.".format(port),
                False,
            )
        else:
            self.messageReceived.emit(
                "Error",
                "Could not connect to {0}.\nCheck the port and device.".format(port),
                True,
            )

    def _on_connect_error(self, msg: str):
        self._is_connected = False
        self._set_connecting(False)
        self.connectionChanged.emit(False)
        self.messageReceived.emit("Connection error", msg, True)

    @Slot(str, int, int, str, int)
    def connect_serial(self, port: str, baudrate: int, bytesize: int, parity: str, stopbits: int):
        if self._is_connecting:
            return
        self._set_connecting(True)
        self._connect_worker = _ConnectWorker(
            self.modbus, port, baudrate, bytesize, parity, stopbits
        )
        self._connect_worker.finished.connect(self._on_connect_finished)
        self._connect_worker.error.connect(self._on_connect_error)
        self._connect_worker.start()

    @Slot()
    def disconnect_serial(self):
        self.stop_scan()
        self.modbus.disconnect()
        self._is_connected = False
        self.connectionChanged.emit(False)
        self.messageReceived.emit("Notice", "Disconnected.", False)

    @Slot(str, int, int, int, str, str, result=str)
    def read_single(
        self,
        reg_type: str,
        addr: int,
        count: int,
        slave: int,
        data_type: str,
        data_format: str = "ABCD",
    ) -> str:
        if not self._is_connected:
            return "ERR: Not connected"
        try:
            val = self.modbus.read(reg_type, addr, count, slave, data_type, data_format)
            return str(val)
        except Exception as e:
            logger.error("Modbus read error: %s", e)
            return f"ERR: {e}"

    @Slot(str, int, str, int, str, result=str)
    def write_single(
        self, reg_type: str, addr: int, value_str: str, slave: int, data_type: str
    ) -> str:
        if not self._is_connected:
            return "ERR: Not connected"
        try:
            # Các kiểu integer parse thành int, kiểu float parse thành float
            int_types = ("int16", "uint16", "int32", "uint32", "decimal")
            val = int(value_str) if data_type.lower() in int_types else float(value_str)
        except ValueError:
            return "ERR: Invalid value"
        try:
            self.modbus.write(reg_type, addr, val, slave, data_type)
            return "SUCCESS"
        except Exception as e:
            logger.error("Modbus write error: %s", e)
            return f"ERR: {e}"

    @Slot(int, int, int, str, str, int, str)
    def start_scan(
        self,
        start_addr: int,
        end_addr: int,
        count: int,
        reg_type: str,
        data_type: str,
        slave: int,
        data_format: str = "ABCD",
    ):
        if not self._is_connected:
            self.messageReceived.emit("Error", "Not connected to Modbus.", True)
            return
        if self._is_scanning:
            return

        self._scan_worker = ScanWorker(
            self.modbus, start_addr, end_addr, count, reg_type, data_type, slave, data_format
        )
        self._scan_worker.progress.connect(self.scanProgress)
        self._scan_worker.result.connect(self.scanResultReceived)
        self._scan_worker.finished_scan.connect(self._on_scan_finished)
        self._scan_worker.start()

        self._is_scanning = True
        self.scanningChanged.emit(True)

    @Slot()
    def stop_scan(self):
        if self._scan_worker and self._is_scanning and not self._is_stopping:
            self._is_stopping = True
            self.stoppingChanged.emit()
            self._scan_worker.stop()

    def _on_scan_finished(self, found: int):
        self._is_scanning = False
        self.scanningChanged.emit(False)
        if self._is_stopping:
            self._is_stopping = False
            self.stoppingChanged.emit()
            self.messageReceived.emit("Notice", "Scan stopped.", False)
        else:
            self.messageReceived.emit(
                "Scan complete",
                "Scan finished. Found {0} register(s) with values.".format(found),
                False,
            )
