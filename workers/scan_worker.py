import logging
from PySide6.QtCore import QThread, Signal

logger = logging.getLogger(__name__)


class ScanWorker(QThread):
    progress = Signal(int, int)
    result = Signal(int, str)
    finished_scan = Signal(int)
    error = Signal(str)

    def __init__(
        self,
        modbus_client,
        start_addr,
        end_addr,
        count,
        reg_type,
        data_type,
        slave,
        data_format="ABCD",
    ):
        super().__init__()
        self.modbus = modbus_client
        self.start_addr = start_addr
        self.end_addr = end_addr
        self.count = count
        self.reg_type = reg_type
        self.data_type = data_type
        self.slave = slave
        self.data_format = data_format
        self.running = True

    def run(self):
        found = 0
        total = self.end_addr - self.start_addr + 1
        for i, addr in enumerate(range(self.start_addr, self.end_addr + 1)):
            if not self.running:
                break
            self.progress.emit(i + 1, total)
            try:
                value = self.modbus.read(
                    self.reg_type, addr, self.count, self.slave, self.data_type, self.data_format
                )
                if value is not None:
                    value_str = str(value)
                    self.result.emit(addr, value_str)
                    found += 1
            except Exception:
                pass
        self.finished_scan.emit(found)

    def stop(self):
        self.running = False
