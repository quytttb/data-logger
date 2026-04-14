#!/usr/bin/env python3
"""M3 Test — DashboardModel + DashboardController + ModbusWorker + DatabaseWorker.

Chạy trên RPi có cảm biến Modbus RTU qua /dev/ttyUSB0.
Usage: cd /home/pi/data-logger/app && python -W all tests/test_m3_dashboard.py
"""

import os
import sys
import time
import warnings

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QCoreApplication
_qapp = QCoreApplication.instance() or QCoreApplication(sys.argv)

passed = 0
failed = 0
deprecation_count = 0

original_warn = warnings.warn

def _counting_warn(message, category=UserWarning, stacklevel=1, **kw):
    global deprecation_count
    if category is DeprecationWarning or (isinstance(message, Warning) and isinstance(message, DeprecationWarning)):
        deprecation_count += 1
    original_warn(message, category=category, stacklevel=stacklevel + 1, **kw)

warnings.warn = _counting_warn
warnings.simplefilter("always", DeprecationWarning)


def check(name: str, condition: bool, detail: str = ""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  ✅ {name}")
    else:
        failed += 1
        print(f"  ❌ {name} — {detail}")


def section(title: str):
    print(f"\n{'='*60}\n  {title}\n{'='*60}")


# ═══════════════════════════════════════════════════════════════
#  0. Foundation imports
# ═══════════════════════════════════════════════════════════════
section("0. Imports & DB setup")

from sqlmodel import select
from core.database import init_db, get_session, engine
from models.app_config import AppConfig
from models.sensor import Sensor
from models.sensor_data import SensorData

TEST_DB = Path(__file__).resolve().parent.parent / "data" / "datalogger.db"

init_db()
check("Import OK", True)

# ═══════════════════════════════════════════════════════════════
#  1. AppConfig serial fields
# ═══════════════════════════════════════════════════════════════
section("1. AppConfig serial fields")

session = get_session()
cfg = session.exec(select(AppConfig)).first()
if cfg is None:
    cfg = AppConfig(station_code="TEST", station_name="Trạm Test")
    session.add(cfg)
    session.commit()
    session.refresh(cfg)

check("serial_port default", cfg.serial_port == "/dev/ttyUSB0", f"got: {cfg.serial_port}")
check("serial_baudrate default", cfg.serial_baudrate == 9600, f"got: {cfg.serial_baudrate}")
check("serial_bytesize default", cfg.serial_bytesize == 8, f"got: {cfg.serial_bytesize}")
check("serial_parity default", cfg.serial_parity == "N", f"got: {cfg.serial_parity}")
check("serial_stopbits default", cfg.serial_stopbits == 1, f"got: {cfg.serial_stopbits}")

cfg.serial_baudrate = 19200
session.commit()
session.refresh(cfg)
check("serial_baudrate updated", cfg.serial_baudrate == 19200)
cfg.serial_baudrate = 9600
session.commit()
session.close()

# ═══════════════════════════════════════════════════════════════
#  2. SettingsController serial properties
# ═══════════════════════════════════════════════════════════════
section("2. SettingsController serial properties")

from ui.settings_controller import SettingsController

sc = SettingsController()
sc.load_config()
check("serialPort type str", isinstance(sc.serialPort, str), f"got: {type(sc.serialPort)}")
check("serialBaudrate type int", isinstance(sc.serialBaudrate, int), f"got: {type(sc.serialBaudrate)}")
check("serialBytesize type int", isinstance(sc.serialBytesize, int))
check("serialParity type str", isinstance(sc.serialParity, str))
check("serialStopbits type int", isinstance(sc.serialStopbits, int))

# Validation test
sc.serialBaudrate = 12345
errors = sc._validate()
has_baud_err = any("Baudrate" in e for e in errors)
check("Validation rejects bad baudrate", has_baud_err, f"errors: {errors}")
sc.serialBaudrate = 9600

sc.serialParity = "X"
errors = sc._validate()
has_parity_err = any("Parity" in e for e in errors)
check("Validation rejects bad parity", has_parity_err, f"errors: {errors}")
sc.serialParity = "N"

# ═══════════════════════════════════════════════════════════════
#  3. DashboardModel
# ═══════════════════════════════════════════════════════════════
section("3. DashboardModel")

from ui.dashboard_controller import DashboardModel, DashboardController

dm = DashboardModel()
check("DashboardModel initial empty", dm.rowCount() == 0)

session = get_session()
sensors = list(session.exec(select(Sensor).where(Sensor.active == True)).all())
session.expunge_all()
session.close()

if not sensors:
    print("  ⚠️  Không có sensor active trong DB — tạo sensor test tạm...")
    session = get_session()
    s = Sensor(name="Test Sensor", unit="°C", slave_id=1, register_address=0,
               register_type="input", data_type="int16", data_format="AB",
               coefficient="{}", report_index=1, active=True)
    session.add(s)
    session.commit()
    session.refresh(s)
    sensors = [s]
    session.expunge_all()
    session.close()

dm.load_sensors(sensors)
check("load_sensors count", dm.rowCount() == len(sensors), f"expected {len(sensors)}, got {dm.rowCount()}")

sid = sensors[0].id
dm.update_value(sid, 25.1234, 2512, datetime.now().isoformat())
from PySide6.QtCore import Qt
val_role = Qt.UserRole + 4
status_role = Qt.UserRole + 6
idx = dm.index(0, 0)
check("update_value → value", dm.data(idx, val_role) == "25.1234")
check("update_value → status OK", dm.data(idx, status_role) == "OK")

dm.set_all_status("ERR")
check("set_all_status ERR", dm.data(idx, status_role) == "ERR")

dm.set_all_status("---")
check("set_all_status ---", dm.data(idx, status_role) == "---")

# ═══════════════════════════════════════════════════════════════
#  4. DashboardController — start/stop lifecycle
# ═══════════════════════════════════════════════════════════════
section("4. DashboardController lifecycle")

dm2 = DashboardModel()
dc = DashboardController(dm2)
check("isPolling initial False", dc.isPolling == False)
check("statusText initial", dc.statusText == "SẴN SÀNG")

# Ensure config and sensors exist
session = get_session()
cfg = session.exec(select(AppConfig)).first()
if cfg is None:
    cfg = AppConfig(station_code="TEST", station_name="Trạm Test")
    session.add(cfg)
    session.commit()
session.close()

dc.start_polling()
check("isPolling after start", dc.isPolling == True, f"got: {dc.isPolling}")
check("statusText after start", "THU THẬP" in dc.statusText, f"got: {dc.statusText}")
check("DashboardModel has sensors", dm2.rowCount() > 0, f"count: {dm2.rowCount()}")

# Process events to receive cross-thread signals
for _ in range(40):
    _qapp.processEvents()
    time.sleep(0.1)

idx = dm2.index(0, 0)
status_val = dm2.data(idx, status_role)
check("After 4s: status changed from WAIT", status_val != "WAIT", f"status: {status_val}")

dc.stop_polling()
for _ in range(10):
    _qapp.processEvents()
    time.sleep(0.1)
check("isPolling after stop", dc.isPolling == False)
check("statusText after stop", "DỪNG" in dc.statusText, f"got: {dc.statusText}")

# ═══════════════════════════════════════════════════════════════
#  5. ModbusWorker — reconnect backoff
# ═══════════════════════════════════════════════════════════════
section("5. ModbusWorker backoff constants")

from workers.modbus_worker import ModbusWorker, _BACKOFF_INITIAL, _BACKOFF_MAX, _BACKOFF_FACTOR

check("BACKOFF_INITIAL == 1.0", _BACKOFF_INITIAL == 1.0)
check("BACKOFF_MAX == 30.0", _BACKOFF_MAX == 30.0)
check("BACKOFF_FACTOR == 2.0", _BACKOFF_FACTOR == 2.0)

mw = ModbusWorker(port="/dev/ttyUSB0", baudrate=9600, poll_interval=3)
check("ModbusWorker poll_interval stored", mw._poll_interval == 3)
check("ModbusWorker has connection_changed signal", hasattr(mw, "connection_changed"))

# ═══════════════════════════════════════════════════════════════
#  6. DatabaseWorker — verify records saved
# ═══════════════════════════════════════════════════════════════
section("6. DatabaseWorker records")

session = get_session()
recent = session.exec(
    select(SensorData).order_by(SensorData.id.desc()).limit(5)
).all()
session.close()

if recent:
    check("SensorData has records from polling", True, f"latest {len(recent)} records")
    r = recent[0]
    check("Record has sensor_id", r.sensor_id is not None)
    check("Record has value", r.value is not None)
    check("Record has recorded_at", r.recorded_at is not None)
else:
    print("  ⚠️  Chưa có SensorData — có thể polling quá ngắn hoặc sensor timeout.")
    check("SensorData has records", False, "no records found — may be sensor timeout (acceptable if no sensor connected)")

# ═══════════════════════════════════════════════════════════════
#  7. Integration: full start → poll → DB write → stop
# ═══════════════════════════════════════════════════════════════
section("7. Integration: poll → DB write → stop")

dm3 = DashboardModel()
dc2 = DashboardController(dm3)

session = get_session()
count_before = len(session.exec(select(SensorData)).all())
session.close()

dc2.start_polling()
for _ in range(60):
    _qapp.processEvents()
    time.sleep(0.1)
dc2.stop_polling()
for _ in range(20):
    _qapp.processEvents()
    time.sleep(0.1)

session = get_session()
count_after = len(session.exec(select(SensorData)).all())
session.close()

new_records = count_after - count_before
check("New SensorData records created during 5s poll", new_records > 0, f"before={count_before}, after={count_after}, new={new_records}")

# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════
total = passed + failed
print(f"\n{'='*60}")
print(f"  KẾT QUẢ: {passed}/{total} PASSED, {deprecation_count} DeprecationWarning, {failed} lỗi")
print(f"{'='*60}")

sys.exit(0 if failed == 0 else 1)
