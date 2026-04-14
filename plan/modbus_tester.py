# -*- coding: utf-8 -*-
"""
Modbus RTU Tester Pro (PySide6/PyQt5)
Industrial-grade GUI for Modbus RTU device testing.
"""
import sys
import json
from pathlib import Path
from datetime import datetime

# Qt compatibility layer - try PySide6 first, fall back to PyQt5
try:
    from PySide6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QSplitter, QGroupBox, QLabel, QLineEdit, QComboBox, QPushButton,
        QTableWidget, QTableWidgetItem, QHeaderView, QStatusBar, QMenuBar,
        QProgressBar, QTabWidget,
        QMenu, QRadioButton, QButtonGroup, QSpinBox, QMessageBox, QFileDialog
    )
    from PySide6.QtCore import Qt, QThread, Signal, QSettings
    from PySide6.QtGui import QAction, QFont
except ImportError:
    from PyQt5.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QSplitter, QGroupBox, QLabel, QLineEdit, QComboBox, QPushButton,
        QTableWidget, QTableWidgetItem, QHeaderView, QStatusBar, QMenuBar,
        QProgressBar, QAction, QTabWidget,
        QMenu, QRadioButton, QButtonGroup, QSpinBox, QMessageBox, QFileDialog
    )
    from PyQt5.QtCore import Qt, QThread, QSettings
    from PyQt5.QtCore import pyqtSignal as Signal
    from PyQt5.QtGui import QFont

import serial.tools.list_ports
import logging

from modbus import Modbus
from themes import get_theme, generate_stylesheet, get_palette_colors

ENV_FILE = Path(__file__).parent / "config" / ".env"


class ScanWorker(QThread):
    """Background worker for scanning registers."""
    progress = Signal(int, int)  # current, total
    result = Signal(int, str)  # address, value
    finished = Signal(int)  # found count
    
    def __init__(self, modbus, start_addr, end_addr, count, reg_type, data_type, slave):
        super().__init__()
        self.modbus = modbus
        self.start_addr = start_addr
        self.end_addr = end_addr
        self.count = count
        self.reg_type = reg_type
        self.data_type = data_type
        self.slave = slave
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
                    self.reg_type, addr, self.count, self.slave, self.data_type
                )
                value_str = str(value) if isinstance(value, list) else str(value)
                self.result.emit(addr, value_str)
                found += 1
            except Exception:
                pass
        
        self.finished.emit(found)
    
    def stop(self):
        self.running = False



class ModbusTesterQt(QMainWindow):
    """Main application window."""
    
    def __init__(self):
        super().__init__()
        self.modbus = Modbus()
        self.scan_worker = None
        self.sys_process = None
        self.settings = QSettings("DataLogger", "ModbusTester")
        
        self._setup_logging()
        self._setup_ui()
        self._load_settings()
    
    def _setup_logging(self):
        """Setup file logging."""
        log_dir = Path.home() / ".modbus-tester" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / f"modbus_{datetime.now():%Y%m%d}.log"
        
        logging.basicConfig(
            filename=str(log_file),
            level=logging.INFO,
            format="%(asctime)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        self.logger = logging.getLogger(__name__)
        self.logger.info("=== Modbus Tester Qt Started ===")
    
    def _setup_ui(self):
        """Setup the main user interface."""
        self.setWindowTitle("Modbus RTU Tester Pro")
        self.setMinimumSize(800, 520)
        self.resize(1000, 550)
        
        # Default to dark mode
        self.dark_mode = True
        self._apply_theme()
        
        # Set central widget directly as tester_tab without QTabWidget
        self.tester_tab = QWidget()
        self.setCentralWidget(self.tester_tab)
        

        # Main layout for Tab 1
        main_layout = QVBoxLayout(self.tester_tab)
        main_layout.setContentsMargins(10, 10, 10, 10)
        
        # Create splitter
        splitter = QSplitter(Qt.Horizontal)
        main_layout.addWidget(splitter)
        
        # Left panel (Connection + Operations)
        left_panel = self._create_left_panel()
        splitter.addWidget(left_panel)
        
        # Right panel (Data Table)
        right_panel = self._create_right_panel()
        splitter.addWidget(right_panel)
        
        # Set splitter proportions (wider left panel)
        splitter.setSizes([320, 600])
        left_panel.setMinimumWidth(300)
        
        # Menu bar
        self._create_menu()
        
        # Status bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Ready")
        
        # Connection indicator in status bar
        self.conn_indicator = QLabel("🔴 Disconnected")
        self.status_bar.addPermanentWidget(self.conn_indicator)
    
    def _create_left_panel(self):
        """Create left panel with connection and operations."""
        tab_widget = QTabWidget()
        
        # Connection Tab
        conn_tab = QWidget()
        conn_layout = QVBoxLayout(conn_tab)
        
        # Port
        port_layout = QHBoxLayout()
        port_layout.addWidget(QLabel("Port:"))
        self.port_combo = QComboBox()
        self._refresh_ports()
        self.port_combo.setMinimumWidth(150)
        port_layout.addWidget(self.port_combo)
        conn_layout.addLayout(port_layout)
        
        # Baudrate
        baud_layout = QHBoxLayout()
        baud_layout.addWidget(QLabel("Baudrate:"))
        self.baudrate_edit = QLineEdit("9600")
        self.baudrate_edit.setMaximumWidth(80)
        baud_layout.addWidget(self.baudrate_edit)
        baud_layout.addStretch()
        conn_layout.addLayout(baud_layout)
        
        # Slave ID
        slave_layout = QHBoxLayout()
        slave_layout.addWidget(QLabel("Slave ID:"))
        self.slave_spin = QSpinBox()
        self.slave_spin.setRange(1, 247)
        self.slave_spin.setValue(1)
        slave_layout.addWidget(self.slave_spin)
        slave_layout.addStretch()
        conn_layout.addLayout(slave_layout)
        
        # Parity
        parity_layout = QHBoxLayout()
        parity_layout.addWidget(QLabel("Parity:"))
        self.parity_combo = QComboBox()
        self.parity_combo.addItems(["N", "E", "O"])
        parity_layout.addWidget(self.parity_combo)
        parity_layout.addStretch()
        conn_layout.addLayout(parity_layout)
        
        # Data bits
        databits_layout = QHBoxLayout()
        databits_layout.addWidget(QLabel("Data bits:"))
        self.databits_edit = QLineEdit("8")
        self.databits_edit.setMaximumWidth(50)
        databits_layout.addWidget(self.databits_edit)
        databits_layout.addStretch()
        conn_layout.addLayout(databits_layout)
        
        # Stop bits
        stopbits_layout = QHBoxLayout()
        stopbits_layout.addWidget(QLabel("Stop bits:"))
        self.stopbits_combo = QComboBox()
        self.stopbits_combo.addItems(["1", "2"])
        stopbits_layout.addWidget(self.stopbits_combo)
        stopbits_layout.addStretch()
        conn_layout.addLayout(stopbits_layout)
        
        # Buttons
        btn_layout = QHBoxLayout()
        self.btn_refresh = QPushButton("🔄 Refresh")
        self.btn_refresh.clicked.connect(self._refresh_ports)
        btn_layout.addWidget(self.btn_refresh)
        
        self.btn_connect = QPushButton("🔌 Connect")
        self.btn_connect.clicked.connect(self._toggle_connection)
        btn_layout.addWidget(self.btn_connect)
        conn_layout.addLayout(btn_layout)
        
        conn_layout.addStretch()
        tab_widget.addTab(conn_tab, "⚙️ Connection")
        
        # Operations Tab
        ops_tab = QWidget()
        ops_layout = QVBoxLayout(ops_tab)
        
        # Register Type
        reg_layout = QHBoxLayout()
        reg_layout.addWidget(QLabel("Register:"))
        self.reg_type_combo = QComboBox()
        self.reg_type_combo.addItems([
            "Holding Register", "Input Register", "Coil", "Discrete Input"
        ])
        self.reg_type_combo.setCurrentIndex(1)
        reg_layout.addWidget(self.reg_type_combo)
        ops_layout.addLayout(reg_layout)
        
        # Data Type
        dtype_layout = QHBoxLayout()
        dtype_layout.addWidget(QLabel("Data Type:"))
        self.data_type_combo = QComboBox()
        self.data_type_combo.addItems(["Decimal", "Float", "Swapped Float"])
        dtype_layout.addWidget(self.data_type_combo)
        ops_layout.addLayout(dtype_layout)
        
        # Mode toggle
        mode_layout = QHBoxLayout()
        mode_layout.addWidget(QLabel("Mode:"))
        self.mode_single = QRadioButton("Single")
        self.mode_range = QRadioButton("Range")
        self.mode_single.setChecked(True)
        
        self.mode_group = QButtonGroup()
        self.mode_group.addButton(self.mode_single)
        self.mode_group.addButton(self.mode_range)
        self.mode_group.buttonClicked.connect(self._on_mode_changed)
        
        mode_layout.addWidget(self.mode_single)
        mode_layout.addWidget(self.mode_range)
        ops_layout.addLayout(mode_layout)
        
        # Address / Count
        addr_layout = QHBoxLayout()
        addr_layout.addWidget(QLabel("Address:"))
        self.addr_spin = QSpinBox()
        self.addr_spin.setRange(0, 65535)
        addr_layout.addWidget(self.addr_spin)
        ops_layout.addLayout(addr_layout)
        
        count_layout = QHBoxLayout()
        count_layout.addWidget(QLabel("Count:"))
        self.count_spin = QSpinBox()
        self.count_spin.setRange(1, 125)
        self.count_spin.setValue(8)
        count_layout.addWidget(self.count_spin)
        ops_layout.addLayout(count_layout)
        
        # Range fields (hidden initially)
        self.range_widget = QWidget()
        range_layout = QHBoxLayout(self.range_widget)
        range_layout.setContentsMargins(0, 0, 0, 0)
        range_layout.addWidget(QLabel("Start:"))
        self.start_spin = QSpinBox()
        self.start_spin.setRange(0, 65535)
        range_layout.addWidget(self.start_spin)
        range_layout.addWidget(QLabel("End:"))
        self.end_spin = QSpinBox()
        self.end_spin.setRange(0, 65535)
        self.end_spin.setValue(100)
        range_layout.addWidget(self.end_spin)
        self.range_widget.hide()
        ops_layout.addWidget(self.range_widget)
        
        # Write Value
        write_layout = QHBoxLayout()
        write_layout.addWidget(QLabel("Write Value:"))
        self.write_edit = QLineEdit("0")
        write_layout.addWidget(self.write_edit)
        ops_layout.addLayout(write_layout)
        
        # Operation buttons
        op_btn_layout = QHBoxLayout()
        self.btn_read = QPushButton("📖 Read")
        self.btn_read.clicked.connect(self._read_data)
        op_btn_layout.addWidget(self.btn_read)
        
        self.btn_write = QPushButton("✏️ Write")
        self.btn_write.clicked.connect(self._write_data)
        op_btn_layout.addWidget(self.btn_write)
        ops_layout.addLayout(op_btn_layout)
        
        scan_btn_layout = QHBoxLayout()
        self.btn_scan = QPushButton("🔍 Scan")
        self.btn_scan.clicked.connect(self._start_scan)
        self.btn_scan.setEnabled(False)
        scan_btn_layout.addWidget(self.btn_scan)
        
        self.btn_stop = QPushButton("⏹ Stop")
        self.btn_stop.clicked.connect(self._stop_scan)
        self.btn_stop.setEnabled(False)
        scan_btn_layout.addWidget(self.btn_stop)
        ops_layout.addLayout(scan_btn_layout)
        
        self.btn_clear = QPushButton("🗑️ Clear Table")
        self.btn_clear.clicked.connect(self._clear_table)
        ops_layout.addWidget(self.btn_clear)
        
        ops_layout.addStretch()
        tab_widget.addTab(ops_tab, "📚 Operations")
        
        return tab_widget
    
    def _create_right_panel(self):
        """Create right panel with data table."""
        group = QGroupBox("📊 Register Data")
        layout = QVBoxLayout()
        
        self.table = QTableWidget()
        self.table.setColumnCount(2)
        self.table.setHorizontalHeaderLabels(["Address", "Value"])
        
        # Configure table
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.Fixed)
        header.setSectionResizeMode(1, QHeaderView.Stretch)
        self.table.setColumnWidth(0, 80)
        
        # Enable sorting
        self.table.setSortingEnabled(True)
        
        # Double-click to read
        self.table.cellDoubleClicked.connect(self._on_table_double_click)
        
        layout.addWidget(self.table)
        group.setLayout(layout)
        return group

    def _create_menu(self):
        """Create menu bar."""
        try:
            from PySide6.QtGui import QKeySequence
        except ImportError:
            from PyQt5.QtGui import QKeySequence
        
        menubar = self.menuBar()
        
        # File menu
        file_menu = menubar.addMenu("File")
        
        export_action = QAction("📁 Export CSV", self)
        export_action.setShortcut(QKeySequence("Ctrl+E"))
        export_action.triggered.connect(self._export_csv)
        file_menu.addAction(export_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction("Exit", self)
        exit_action.setShortcut(QKeySequence("Ctrl+Q"))
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)
        
        # View menu
        view_menu = menubar.addMenu("View")
        
        self.theme_action = QAction("☀️ Light Mode", self)
        self.theme_action.setShortcut(QKeySequence("Ctrl+T"))
        self.theme_action.triggered.connect(self._toggle_theme)
        view_menu.addAction(self.theme_action)
        
        view_menu.addSeparator()
        
        clear_action = QAction("🗑️ Clear Table", self)
        clear_action.setShortcut(QKeySequence("Ctrl+L"))
        clear_action.triggered.connect(self._clear_table)
        view_menu.addAction(clear_action)
        
        # Operations menu (new)
        ops_menu = menubar.addMenu("Operations")
        
        read_action = QAction("📖 Read", self)
        read_action.setShortcut(QKeySequence("Ctrl+R"))
        read_action.triggered.connect(self._read_data)
        ops_menu.addAction(read_action)
        
        write_action = QAction("✏️ Write", self)
        write_action.setShortcut(QKeySequence("Ctrl+W"))
        write_action.triggered.connect(self._write_data)
        ops_menu.addAction(write_action)
        
        ops_menu.addSeparator()
        
        connect_action = QAction("🔌 Toggle Connection", self)
        connect_action.setShortcut(QKeySequence("Ctrl+Return"))
        connect_action.triggered.connect(self._toggle_connection)
        ops_menu.addAction(connect_action)
        
        refresh_action = QAction("🔄 Refresh Ports", self)
        refresh_action.setShortcut(QKeySequence("F5"))
        refresh_action.triggered.connect(self._refresh_ports)
        ops_menu.addAction(refresh_action)
        
        ops_menu.addSeparator()
        
        # Help menu
        help_menu = menubar.addMenu("Help")
        
        shortcuts_action = QAction("⌨️ Keyboard Shortcuts", self)
        shortcuts_action.setShortcut(QKeySequence("F1"))
        shortcuts_action.triggered.connect(self._show_shortcuts)
        help_menu.addAction(shortcuts_action)
        
        about_action = QAction("About", self)
        about_action.triggered.connect(self._show_about)
        help_menu.addAction(about_action)
    
    # ==================== Actions ====================
    
    def _refresh_ports(self):
        """Refresh COM ports list."""
        self.port_combo.clear()
        ports = serial.tools.list_ports.comports()
        for port in ports:
            self.port_combo.addItem(f"{port.device} - {port.description}", port.device)
        
        if not ports:
            self.port_combo.addItem("(No ports found)", "")
        
        if hasattr(self, 'status_bar'):
            self.status_bar.showMessage("🔄 Ports refreshed")
    
    def _toggle_connection(self):
        """Connect or disconnect."""
        if self.modbus.is_connected():
            self.modbus.disconnect()
            self.btn_connect.setText("🔌 Connect")
            self.conn_indicator.setText("🔴 Disconnected")
            self.status_bar.showMessage("🔴 Disconnected")
        else:
            port = self.port_combo.currentData()
            if not port:
                QMessageBox.warning(self, "Error", "No port selected!")
                return
            
            # Check if port is locked by another process
            try:
                from services.port_checker import check_port_available
                available, blocking_info = check_port_available(port)
                if not available:
                    QMessageBox.warning(
                        self, "Port In Use",
                        f"Port {port} is currently in use by:\n\n"
                        f"{blocking_info}\n\n"
                        f"Please pause the Data Logger on the Web UI\n"
                        f"or close the application using the port before connecting."
                    )
                    return
            except ImportError:
                pass  # port_checker not available, skip check
            
            baudrate = self.baudrate_edit.text()
            bytesize = self.databits_edit.text()
            parity = self.parity_combo.currentText()
            stopbits = self.stopbits_combo.currentText()
            
            client = self.modbus.connect(port, baudrate, bytesize, parity, stopbits)
            
            if self.modbus.is_connected():
                self.btn_connect.setText("❌ Disconnect")
                self.conn_indicator.setText("🟢 Connected")
                self.status_bar.showMessage(f"✅ Connected to {port}")
                self._save_settings()
            else:
                QMessageBox.critical(self, "Error", "Cannot connect to device!")
    
    def _on_mode_changed(self):
        """Handle mode toggle."""
        if self.mode_single.isChecked():
            self.range_widget.hide()
            self.btn_read.setEnabled(True)
            self.btn_write.setEnabled(True)
            self.btn_scan.setEnabled(False)
        else:
            self.range_widget.show()
            self.btn_read.setEnabled(False)
            self.btn_write.setEnabled(False)
            self.btn_scan.setEnabled(True)
    
    def _read_data(self):
        """Read register data."""
        if not self.modbus.is_connected():
            QMessageBox.warning(self, "Error", "Not connected!")
            return
        
        try:
            addr = self.addr_spin.value()
            count = self.count_spin.value()
            slave = self.slave_spin.value()
            reg_type = self.reg_type_combo.currentText()
            data_type = self.data_type_combo.currentText()
            
            value = self.modbus.read(reg_type, addr, count, slave, data_type)
            value_str = str(value) if isinstance(value, list) else str(value)
            
            self._add_table_row(addr, value_str)
            self.status_bar.showMessage("✅ Read complete")
            self.logger.info(f"Read {reg_type} [{addr}] count={count} → {value}")
            
        except Exception as e:
            err_msg = str(e)
            self.status_bar.showMessage(f"⚠️ Read error: {err_msg}")
            self.logger.error(f"Read error: {err_msg}")
            QMessageBox.critical(self, "Read Error", f"Cannot read data:\n{err_msg}")
    
    def _write_data(self):
        """Write register data."""
        if not self.modbus.is_connected():
            QMessageBox.warning(self, "Error", "Not connected!")
            return
        
        try:
            addr = self.addr_spin.value()
            slave = self.slave_spin.value()
            value = self.write_edit.text()
            reg_type = self.reg_type_combo.currentText()
            data_type = self.data_type_combo.currentText()
            
            self.modbus.write(reg_type, addr, value, slave, data_type)
            self.status_bar.showMessage("✅ Write complete")
            self.logger.info(f"Write {reg_type} [{addr}] = {value}")
            
        except Exception as e:
            err_msg = str(e)
            self.status_bar.showMessage(f"⚠️ Write error: {err_msg}")
            self.logger.error(f"Write error: {err_msg}")
            QMessageBox.critical(self, "Write Error", f"Cannot write data:\n{err_msg}")
    
    def _start_scan(self):
        """Start range scan."""
        if not self.modbus.is_connected():
            QMessageBox.warning(self, "Error", "Not connected!")
            return
        
        start = self.start_spin.value()
        end = self.end_spin.value()
        
        if start > end:
            QMessageBox.warning(self, "Error", "Start must be less than End!")
            return
        
        self._clear_table()
        
        self.btn_scan.setEnabled(False)
        self.btn_stop.setEnabled(True)
        
        self.scan_worker = ScanWorker(
            self.modbus,
            start, end,
            self.count_spin.value(),
            self.reg_type_combo.currentText(),
            self.data_type_combo.currentText(),
            self.slave_spin.value()
        )
        self.scan_worker.progress.connect(self._on_scan_progress)
        self.scan_worker.result.connect(self._add_table_row)
        self.scan_worker.finished.connect(self._on_scan_finished)
        self.scan_worker.start()
    
    def _stop_scan(self):
        """Stop scanning."""
        if self.scan_worker:
            self.scan_worker.stop()
            self.status_bar.showMessage("⏹ Scan stopped")
    
    def _on_scan_progress(self, current, total):
        """Update scan progress."""
        percent = int((current / total) * 100)
        self.status_bar.showMessage(f"🔍 Scanning {current}/{total} ({percent}%)...")
    
    def _on_scan_finished(self, found):
        """Handle scan completion."""
        self.btn_scan.setEnabled(True)
        self.btn_stop.setEnabled(False)
        self.status_bar.showMessage(f"✅ Scan complete! Found {found} registers")
    
    def _add_table_row(self, address, value):
        """Add a row to the table."""
        row = self.table.rowCount()
        self.table.insertRow(row)
        self.table.setItem(row, 0, QTableWidgetItem(str(address)))
        self.table.setItem(row, 1, QTableWidgetItem(value))
    
    def _clear_table(self):
        """Clear the table."""
        self.table.setRowCount(0)
        self.status_bar.showMessage("🗑️ Table cleared")
    
    def _on_table_double_click(self, row, col):
        """Handle table double-click."""
        addr_item = self.table.item(row, 0)
        if addr_item:
            self.addr_spin.setValue(int(addr_item.text()))
            self.mode_single.setChecked(True)
            self._on_mode_changed()
            self._read_data()
    
    def _export_csv(self):
        """Export table to CSV."""
        path, _ = QFileDialog.getSaveFileName(
            self, "Export CSV", "", "CSV Files (*.csv)"
        )
        if path:
            with open(path, 'w') as f:
                f.write("Address,Value\n")
                for row in range(self.table.rowCount()):
                    addr = self.table.item(row, 0).text()
                    val = self.table.item(row, 1).text()
                    f.write(f"{addr},{val}\n")
            self.status_bar.showMessage(f"✅ Exported to {path}")
    
    def _show_about(self):
        """Show about dialog."""
        QMessageBox.about(
            self, "About",
            "Modbus RTU Tester Pro\n\n"
            "Industrial-grade Modbus testing tool.\n\n"
            "Built with PySide6.\n\n"
            "© 2026 Data Logger Team"
        )
        
    def _show_shortcuts(self):
        """Show keyboard shortcuts dialog."""
        shortcuts = """
<b>Keyboard Shortcuts</b><br><br>
<b>Operations:</b><br>
Ctrl+R - Read registers<br>
Ctrl+W - Write value<br>
Ctrl+Enter - Connect/Disconnect<br>
F5 - Refresh ports<br>
<br>
<b>View:</b><br>
Ctrl+T - Toggle theme<br>
Ctrl+L - Clear table<br>
<br>
<b>File:</b><br>
Ctrl+E - Export CSV<br>
Ctrl+Q - Exit<br>
<br>
<b>Help:</b><br>
F1 - Show shortcuts
"""
        QMessageBox.information(self, "Keyboard Shortcuts", shortcuts)
    
    def _apply_theme(self):
        """Apply dark or light theme using centralized theme definitions."""
        try:
            from PySide6.QtGui import QPalette, QColor
        except ImportError:
            from PyQt5.QtGui import QPalette, QColor
        
        # Get theme from centralized module
        theme = get_theme(self.dark_mode)
        palette_colors = get_palette_colors(self.dark_mode)
        
        # Apply palette
        palette = QPalette()
        palette.setColor(QPalette.Window, QColor(*palette_colors["window"]))
        palette.setColor(QPalette.WindowText, QColor(*palette_colors["window_text"]))
        palette.setColor(QPalette.Base, QColor(*palette_colors["base"]))
        palette.setColor(QPalette.AlternateBase, QColor(*palette_colors["alternate_base"]))
        palette.setColor(QPalette.ToolTipBase, QColor(*palette_colors["tooltip_base"]))
        palette.setColor(QPalette.ToolTipText, QColor(*palette_colors["tooltip_text"]))
        palette.setColor(QPalette.Text, QColor(*palette_colors["text"]))
        palette.setColor(QPalette.Button, QColor(*palette_colors["button"]))
        palette.setColor(QPalette.ButtonText, QColor(*palette_colors["button_text"]))
        palette.setColor(QPalette.BrightText, QColor(*palette_colors["bright_text"]))
        palette.setColor(QPalette.Link, QColor(*palette_colors["link"]))
        palette.setColor(QPalette.Highlight, QColor(*palette_colors["highlight"]))
        palette.setColor(QPalette.HighlightedText, QColor(*palette_colors["highlighted_text"]))
        
        QApplication.instance().setPalette(palette)
        
        # Apply stylesheet from centralized theme globally to the entire application
        QApplication.instance().setStyleSheet(generate_stylesheet(theme))
    
    def _toggle_theme(self):
        """Toggle between dark and light mode."""
        self.dark_mode = not self.dark_mode
        self._apply_theme()
        
        if self.dark_mode:
            self.theme_action.setText("☀️ Light Mode")
            self.status_bar.showMessage("🌙 Dark mode enabled")
        else:
            self.theme_action.setText("🌙 Dark Mode")
            self.status_bar.showMessage("☀️ Light mode enabled")
        
        # Save preference
        self.settings.setValue("dark_mode", self.dark_mode)
    
    # ==================== Settings ====================
    
    def _save_settings(self):
        """Save settings to QSettings."""
        self.settings.setValue("port", self.port_combo.currentData())
        self.settings.setValue("baudrate", self.baudrate_edit.text())
        self.settings.setValue("slave_id", self.slave_spin.value())
        self.settings.setValue("parity", self.parity_combo.currentText())
        self.settings.setValue("databits", self.databits_edit.text())
        self.settings.setValue("stopbits", self.stopbits_combo.currentText())
        self.settings.setValue("reg_type", self.reg_type_combo.currentIndex())
        self.settings.setValue("data_type", self.data_type_combo.currentIndex())
        self.logger.info("Settings saved")
    
    def _load_settings(self):
        """Load settings from QSettings."""
        port = self.settings.value("port", "")
        if port:
            index = self.port_combo.findData(port)
            if index >= 0:
                self.port_combo.setCurrentIndex(index)
        
        baudrate = self.settings.value("baudrate", "9600")
        self.baudrate_edit.setText(baudrate)
        
        slave_id = self.settings.value("slave_id", 1, type=int)
        self.slave_spin.setValue(slave_id)
        
        parity = self.settings.value("parity", "N")
        index = self.parity_combo.findText(parity)
        if index >= 0:
            self.parity_combo.setCurrentIndex(index)
        
        databits = self.settings.value("databits", "8")
        self.databits_edit.setText(databits)
        
        stopbits = self.settings.value("stopbits", "1")
        index = self.stopbits_combo.findText(stopbits)
        if index >= 0:
            self.stopbits_combo.setCurrentIndex(index)
        
        reg_type = self.settings.value("reg_type", 1, type=int)
        self.reg_type_combo.setCurrentIndex(reg_type)
        
        data_type = self.settings.value("data_type", 0, type=int)
        self.data_type_combo.setCurrentIndex(data_type)
        
        # Load theme preference
        self.dark_mode = self.settings.value("dark_mode", True, type=bool)
        self._apply_theme()
        if self.dark_mode:
            self.theme_action.setText("☀️ Light Mode")
        else:
            self.theme_action.setText("🌙 Dark Mode")
        
        self.logger.info("Settings loaded")
    
    def closeEvent(self, event):
        """Handle window close."""
        if self.sys_process is not None and self.sys_process.state() != 0:
            self.sys_process.write(b"quit\n")
            self.sys_process.waitForFinished(1000)
            
        self._save_settings()
        if self.modbus.is_connected():
            self.modbus.disconnect()
        event.accept()


def main():
    """Entry point."""
    import os
    # Vô hiệu hóa scaling tự động, giữ kích thước gốc của pixel trên Wayland/X11 với màn hình độ phân giải thấp
    os.environ["QT_AUTO_SCREEN_SCALE_FACTOR"] = "0"
    os.environ["QT_SCALE_FACTOR"] = "1"
    os.environ["QT_SCREEN_SCALE_FACTORS"] = "1"
    
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle("Fusion")
    
    window = ModbusTesterQt()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
