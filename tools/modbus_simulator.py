import sys
import threading
import logging
import serial
import struct
import time
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QDoubleSpinBox, QPushButton, QComboBox, QGroupBox, QGridLayout,
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
        
        self.temp_val = 25.5
        self.hum_val = 60.0
        self.di10_val = False
        self.di11_val = False
        self.do0_val = False
        self.do1_val = False
        
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
        
        reg_layout.addWidget(QLabel("Nhiệt độ (IR 200, Float32):"), 0, 0)
        self.spin_temp = QDoubleSpinBox()
        self.spin_temp.setRange(-100.0, 1000.0)
        self.spin_temp.setDecimals(2)
        self.spin_temp.setSingleStep(0.1)
        self.spin_temp.setValue(self.temp_val)
        self.spin_temp.valueChanged.connect(self.update_values)
        reg_layout.addWidget(self.spin_temp, 0, 1)

        reg_layout.addWidget(QLabel("Độ ẩm (IR 202, Float32):"), 1, 0)
        self.spin_hum = QDoubleSpinBox()
        self.spin_hum.setRange(0.0, 100.0)
        self.spin_hum.setDecimals(2)
        self.spin_hum.setSingleStep(0.1)
        self.spin_hum.setValue(self.hum_val)
        self.spin_hum.valueChanged.connect(self.update_values)
        reg_layout.addWidget(self.spin_hum, 1, 1)
        
        reg_layout.addWidget(QLabel("Trạng thái (DI 10, DI 11):"), 2, 0)
        di_layout = QHBoxLayout()
        self.chk_di10 = QCheckBox("DI 10 (Lỗi)")
        self.chk_di11 = QCheckBox("DI 11 (Bảo trì)")
        self.chk_di10.stateChanged.connect(self.update_values)
        self.chk_di11.stateChanged.connect(self.update_values)
        di_layout.addWidget(self.chk_di10)
        di_layout.addWidget(self.chk_di11)
        reg_layout.addLayout(di_layout, 2, 1)
        
        reg_layout.addWidget(QLabel("Đèn báo DO 0 (Coil 0):"), 3, 0)
        self.lbl_coil0 = QLabel("⚫")
        self.lbl_coil0.setStyleSheet("font-size: 32px; color: gray;")
        reg_layout.addWidget(self.lbl_coil0, 3, 1)

        reg_layout.addWidget(QLabel("Đèn báo DO 1 (Coil 1):"), 4, 0)
        self.lbl_coil1 = QLabel("⚫")
        self.lbl_coil1.setStyleSheet("font-size: 32px; color: gray;")
        reg_layout.addWidget(self.lbl_coil1, 4, 1)
        
        reg_group.setLayout(reg_layout)
        main_layout.addWidget(reg_group)
        
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_ui)
        self.timer.start(500)

    def update_values(self):
        self.temp_val = self.spin_temp.value()
        self.hum_val = self.spin_hum.value()
        self.di10_val = self.chk_di10.isChecked()
        self.di11_val = self.chk_di11.isChecked()

    def update_ui(self):
        if self.do0_val:
            self.lbl_coil0.setText("🔴")
            self.lbl_coil0.setStyleSheet("font-size: 32px; color: red;")
        else:
            self.lbl_coil0.setText("⚫")
            self.lbl_coil0.setStyleSheet("font-size: 32px; color: gray;")

        if self.do1_val:
            self.lbl_coil1.setText("🔴")
            self.lbl_coil1.setStyleSheet("font-size: 32px; color: red;")
        else:
            self.lbl_coil1.setText("⚫")
            self.lbl_coil1.setStyleSheet("font-size: 32px; color: gray;")

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
                                if fc == 4: # Read Input Registers
                                    response.append(slave_id)
                                    response.append(fc)
                                    response.append(val_count * 2) # Byte count
                                    # Emulate Float32 at address 200 and 202 (ABCD endian)
                                    b_temp = struct.pack(">f", self.temp_val)
                                    b_hum = struct.pack(">f", self.hum_val)
                                    for i in range(val_count):
                                        cur_addr = addr + i
                                        if cur_addr == 200:
                                            response.extend(b_temp[0:2])
                                        elif cur_addr == 201:
                                            response.extend(b_temp[2:4])
                                        elif cur_addr == 202:
                                            response.extend(b_hum[0:2])
                                        elif cur_addr == 203:
                                            response.extend(b_hum[2:4])
                                        else:
                                            response.extend(struct.pack(">H", 0))
                                    response.extend(calculate_crc(response))
                                    ser.write(response)

                                elif fc == 1: # Read Coils
                                    response.append(slave_id)
                                    response.append(fc)
                                    byte_count = (val_count + 7) // 8
                                    response.append(byte_count)
                                    bytes_arr = bytearray(byte_count)
                                    for i in range(val_count):
                                        cur_addr = addr + i
                                        bit_val = False
                                        if cur_addr == 0:
                                            bit_val = self.do0_val
                                        elif cur_addr == 1:
                                            bit_val = self.do1_val
                                        
                                        if bit_val:
                                            byte_idx = i // 8
                                            bit_idx = i % 8
                                            bytes_arr[byte_idx] |= (1 << bit_idx)
                                    response.extend(bytes_arr)
                                    response.extend(calculate_crc(response))
                                    ser.write(response)
                                    
                                elif fc == 2: # Read Discrete Inputs
                                    response.append(slave_id)
                                    response.append(fc)
                                    byte_count = (val_count + 7) // 8
                                    response.append(byte_count)
                                    bytes_arr = bytearray(byte_count)
                                    for i in range(val_count):
                                        cur_addr = addr + i
                                        bit_val = False
                                        if cur_addr == 10:
                                            bit_val = self.di10_val
                                        elif cur_addr == 11:
                                            bit_val = self.di11_val
                                        
                                        if bit_val:
                                            byte_idx = i // 8
                                            bit_idx = i % 8
                                            bytes_arr[byte_idx] |= (1 << bit_idx)
                                    response.extend(bytes_arr)
                                    response.extend(calculate_crc(response))
                                    ser.write(response)
                                    
                                elif fc == 5: # Write Single Coil
                                    # req[4:6] is value (FF00 = ON, 0000 = OFF)
                                    if addr == 0:
                                        self.do0_val = (val_count == 0xFF00)
                                    elif addr == 1:
                                        self.do1_val = (val_count == 0xFF00)
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
