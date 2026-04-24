import sys
import threading
import logging
import serial
import struct
import time
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QSpinBox, QPushButton, QComboBox, QGroupBox, QGridLayout,
    QCheckBox
)
from PySide6.QtCore import Qt, QTimer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ModbusSimulator")

def calculate_crc(data: bytes) -> bytes:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc >>= 1
                crc ^= 0xA001
            else:
                crc >>= 1
    return struct.pack("<H", crc)

class ModbusSimWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Data Logger - Modbus Slave Simulator (Raw Serial)")
        self.resize(500, 400)
        
        self.server_thread = None
        self.is_running = False
        
        self.hr_val = 5000
        self.di_val = False
        self.do_val = False
        
        # UI Setup
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        
        # --- Connection Setup ---
        conn_group = QGroupBox("Cấu hình Cổng Serial (Slave)")
        conn_layout = QHBoxLayout()
        
        import serial.tools.list_ports
        import glob
        ports = [p.device for p in sorted(serial.tools.list_ports.comports(), key=lambda x: x.device)]
        pts_ports = [p for p in glob.glob("/dev/pts/*") if p != "/dev/pts/ptmx"]
        for p in sorted(pts_ports):
            if p not in ports:
                ports.append(p)
        if not ports:
            ports = ["/dev/pts/2", "/dev/ttyUSB1"]
            
        self.port_input = QComboBox()
        self.port_input.setEditable(True)
        self.port_input.addItems(ports)
        conn_layout.addWidget(QLabel("Port:"))
        conn_layout.addWidget(self.port_input)
        
        self.btn_start = QPushButton("Start Simulator")
        self.btn_start.clicked.connect(self.toggle_server)
        conn_layout.addWidget(self.btn_start)
        
        conn_group.setLayout(conn_layout)
        main_layout.addWidget(conn_group)
        
        # --- Registers Setup ---
        reg_group = QGroupBox("Giả lập Dữ liệu (Slave ID 1)")
        reg_layout = QGridLayout()
        
        reg_layout.addWidget(QLabel("Holding Register 0 (Analog):"), 0, 0)
        self.spin_hr0 = QSpinBox()
        self.spin_hr0.setRange(0, 65535)
        self.spin_hr0.setValue(self.hr_val)
        self.spin_hr0.valueChanged.connect(self.update_values)
        reg_layout.addWidget(self.spin_hr0, 0, 1)
        
        reg_layout.addWidget(QLabel("Discrete Input 10 (DI):"), 1, 0)
        self.chk_di10 = QCheckBox("ON / OFF")
        self.chk_di10.stateChanged.connect(self.update_values)
        reg_layout.addWidget(self.chk_di10, 1, 1)
        
        reg_layout.addWidget(QLabel("Coil 0 (DO Relay Status):"), 2, 0)
        self.lbl_coil0 = QLabel("OFF")
        self.lbl_coil0.setStyleSheet("font-weight: bold; color: gray;")
        reg_layout.addWidget(self.lbl_coil0, 2, 1)
        
        reg_group.setLayout(reg_layout)
        main_layout.addWidget(reg_group)
        
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_ui)
        self.timer.start(500)

    def update_values(self):
        self.hr_val = self.spin_hr0.value()
        self.di_val = self.chk_di10.isChecked()

    def update_ui(self):
        if self.do_val:
            self.lbl_coil0.setText("ON (ALARM TRIPPED)")
            self.lbl_coil0.setStyleSheet("font-weight: bold; color: red;")
        else:
            self.lbl_coil0.setText("OFF")
            self.lbl_coil0.setStyleSheet("font-weight: bold; color: green;")

    def toggle_server(self):
        if not self.is_running:
            port = self.port_input.currentText()
            self.is_running = True
            self.server_thread = threading.Thread(target=self.run_server, args=(port,), daemon=True)
            self.server_thread.start()
            self.btn_start.setText("Stop Simulator")
            self.port_input.setEnabled(False)
        else:
            logger.info("Stopping Simulator... Please close and restart script.")
            sys.exit(0)

    def run_server(self, port):
        logger.info(f"Starting raw Modbus RTU Server on {port}...")
        try:
            with serial.Serial(port, 9600, timeout=0.1) as ser:
                buffer = bytearray()
                while self.is_running:
                    if ser.in_waiting:
                        buffer.extend(ser.read(ser.in_waiting))
                        
                    if len(buffer) >= 8: # Modbus RTU requests are usually 8 bytes
                        req = buffer[:8]
                        # Check CRC
                        if calculate_crc(req[:6]) == req[6:8]:
                            slave_id = req[0]
                            fc = req[1]
                            addr = struct.unpack(">H", req[2:4])[0]
                            val_count = struct.unpack(">H", req[4:6])[0]
                            
                            response = bytearray()
                            if slave_id == 1:
                                if fc == 3: # Read Holding Registers
                                    response.append(slave_id)
                                    response.append(fc)
                                    response.append(val_count * 2) # Byte count
                                    # We only pretend addr 0 has self.hr_val
                                    for i in range(val_count):
                                        if addr + i == 0:
                                            response.extend(struct.pack(">H", self.hr_val))
                                        else:
                                            response.extend(struct.pack(">H", 0))
                                    response.extend(calculate_crc(response))
                                    ser.write(response)
                                    
                                elif fc == 2: # Read Discrete Inputs
                                    response.append(slave_id)
                                    response.append(fc)
                                    # Calculate byte count
                                    byte_count = (val_count + 7) // 8
                                    response.append(byte_count)
                                    # We only pretend addr 10 has self.di_val
                                    byte_val = 0
                                    if addr <= 10 and addr + val_count > 10 and self.di_val:
                                        bit_offset = 10 - addr
                                        if bit_offset < 8:
                                            byte_val |= (1 << bit_offset)
                                    response.append(byte_val)
                                    # Append empty bytes if more than 1
                                    for _ in range(byte_count - 1):
                                        response.append(0)
                                    response.extend(calculate_crc(response))
                                    ser.write(response)
                                    
                                elif fc == 5: # Write Single Coil
                                    # req[4:6] is value (FF00 = ON, 0000 = OFF)
                                    if addr == 0:
                                        self.do_val = (val_count == 0xFF00)
                                    # Echo back exactly what was received
                                    ser.write(req)
                        
                        # Shift buffer
                        buffer = buffer[8:]
                    elif len(buffer) > 0 and not ser.in_waiting:
                        # Clear invalid junk
                        time.sleep(0.05)
                        if not ser.in_waiting:
                            buffer.clear()
                    
                    time.sleep(0.01)
        except Exception as e:
            logger.error(f"Serial error: {e}")
            self.is_running = False

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = ModbusSimWindow()
    window.show()
    sys.exit(app.exec())
