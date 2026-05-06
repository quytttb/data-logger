#!/usr/bin/env python3
"""M5 Test — TxtGenerator + ReportLog + FtpWorker + ReportController.

Chạy trên RPi: cd /home/pi/data-logger/app && python -W all tests/test_m5_report.py
"""

import os
import sys
import time
import warnings

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime, timedelta
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
#  0. Foundation
# ═══════════════════════════════════════════════════════════════
section("0. Imports & DB setup")

from sqlmodel import select
from core.database import init_db, get_session
from models.app_config import AppConfig
from models.sensor import Sensor
from models.sensor_data import SensorData
from models.report_log import ReportLog

init_db()
check("Import OK", True)

# Seed config
session = get_session()
cfg = session.exec(select(AppConfig)).first()
if cfg is None:
    cfg = AppConfig(station_code="TEST-001", station_name="Tram Test",
                    ftp_address="127.0.0.1", ftp_port=2222,
                    ftp_username="user", ftp_password="", ftp_remote_path="/data")
    session.add(cfg)
    session.commit()
    session.refresh(cfg)
else:
    cfg.station_code = "TEST-001"
    cfg.ftp_address = "127.0.0.1"
    cfg.ftp_port = 2222
    session.commit()

# Seed sensor
sensor = session.exec(select(Sensor)).first()
if sensor is None:
    sensor = Sensor(name="Nhiet do", unit="°C", slave_id=1, register_address=0,
                    register_type="input", data_type="int16", data_format="AB",
                    coefficient="{}", report_index=1, active=True)
    session.add(sensor)
    session.commit()
    session.refresh(sensor)
elif sensor.report_index == 0:
    sensor.report_index = 1
    session.commit()
    session.refresh(sensor)

sensor2 = Sensor(name="pH", unit="pH", slave_id=2, register_address=1,
                 register_type="input", data_type="int16", data_format="AB",
                 coefficient="{}", report_index=2, active=True)
session.add(sensor2)
session.commit()
session.refresh(sensor2)

sensor_id_1 = sensor.id
sensor_id_2 = sensor2.id

# Seed data
now = datetime.now()
for i in range(10):
    session.add(SensorData(sensor_id=sensor_id_1, value=25.0 + i * 0.1,
                           raw_value=250 + i, recorded_at=now - timedelta(minutes=4 - i)))
    session.add(SensorData(sensor_id=sensor_id_2, value=7.0 + i * 0.01,
                           raw_value=700 + i, recorded_at=now - timedelta(minutes=4 - i)))
session.commit()
session.close()
check("Seeded config + 2 sensors + 20 data records", True)

# ═══════════════════════════════════════════════════════════════
#  1. TxtGenerator — 5-field format
# ═══════════════════════════════════════════════════════════════
section("1. TxtGenerator")

from core.txt_generator import generate_report, REPORT_DIR

records = [
    {"sensor_id": sensor_id_1, "value": 25.5, "recorded_at": datetime(2026, 4, 8, 10, 0, 0)},
    {"sensor_id": sensor_id_2, "value": 7.2, "recorded_at": datetime(2026, 4, 8, 10, 0, 0)},
    {"sensor_id": sensor_id_1, "value": 26.0, "recorded_at": datetime(2026, 4, 8, 10, 5, 0)},
]

sensor_order = [
    {"id": sensor_id_1, "name": "Nhiet do", "unit": "°C", "report_index": 1},
    {"id": sensor_id_2, "name": "pH", "unit": "pH", "report_index": 2},
]

filepath = generate_report(
    records=records,
    sensor_order=sensor_order,
    station_code="TEST-001",
    report_time=datetime(2026, 4, 8, 10, 5, 0),
)

check("File created", Path(filepath).exists(), f"path: {filepath}")
check("REPORT_DIR exists", REPORT_DIR.exists())

content = Path(filepath).read_text(encoding="utf-8")
lines = content.strip().split("\n")
check("Has 3 data lines", len(lines) == 3, f"lines: {len(lines)}")

first_line = lines[0]
fields = first_line.split("\t")
check("5 fields per line", len(fields) == 5, f"fields: {len(fields)} — {first_line}")

check("Field 1: sensor name", fields[0] == "Nhiet do", f"got: {fields[0]}")
check("Field 2: value", fields[1] == "25.5000", f"got: {fields[1]}")
check("Field 3: unit", fields[2] == "°C", f"got: {fields[2]}")
check("Field 4: timestamp", "20260408" in fields[3], f"got: {fields[3]}")
check("Field 5: status", fields[4] == "00", f"got: {fields[4]}")

# Verify second sensor also present
ph_lines = [l for l in lines if l.startswith("pH")]
check("pH sensor lines present", len(ph_lines) == 1, f"pH lines: {len(ph_lines)}")

# Cleanup test file
Path(filepath).unlink(missing_ok=True)

# ═══════════════════════════════════════════════════════════════
#  2. ReportLog model
# ═══════════════════════════════════════════════════════════════
section("2. ReportLog CRUD")

session = get_session()
rl = ReportLog(filename="test_report.txt", status="pending")
session.add(rl)
session.commit()
session.refresh(rl)
check("ReportLog created", rl.id is not None)
check("Status default pending", rl.status == "pending")
check("Retry count default 0", rl.retry_count == 0)

rl.status = "sent"
rl.sent_at = datetime.now()
session.commit()
session.refresh(rl)
check("Status updated to sent", rl.status == "sent")
check("sent_at set", rl.sent_at is not None)

rl2 = ReportLog(filename="failed_report.txt", status="failed", retry_count=2, error_message="Timeout")
session.add(rl2)
session.commit()
session.refresh(rl2)
check("Failed ReportLog", rl2.status == "failed" and rl2.retry_count == 2)

pending = session.exec(
    select(ReportLog).where(ReportLog.status.in_(["pending", "failed"]))
).all()
check("Pending/failed query", len(pending) >= 1, f"count: {len(pending)}")
session.close()

# ═══════════════════════════════════════════════════════════════
#  3. FtpWorker — generate_and_send (no real FTP)
# ═══════════════════════════════════════════════════════════════
section("3. FtpWorker — file generation")

from workers.ftp_worker import FtpWorker, MAX_RETRY

check("MAX_RETRY == 5", MAX_RETRY == 5)

fw = FtpWorker(interval_minutes=5)
check("FtpWorker interval", fw._interval == 5)
check("has ftp_status signal", hasattr(fw, "ftp_status"))
check("has worker_stopped signal", hasattr(fw, "worker_stopped"))

# ═══════════════════════════════════════════════════════════════
#  4. ReportController — lifecycle
# ═══════════════════════════════════════════════════════════════
section("4. ReportController")

from ui.controllers.report_controller import ReportController

rc = ReportController()
check("isRunning initial False", rc.isRunning == False)
check("lastStatus initial empty", rc.lastStatus == "")
check("pendingCount type int", isinstance(rc.pendingCount, int))

# Test start — FtpWorker will attempt generate_and_send (upload fails fast to localhost)
rc.start_reporting()
check("isRunning after start", rc.isRunning == True)
check("lastStatus set after start", "chạy" in rc.lastStatus.lower() or "running" in rc.lastStatus.lower(), f"got: '{rc.lastStatus}'")

# Give worker time to attempt first cycle then stop
for _ in range(30):
    _qapp.processEvents()
    time.sleep(0.1)

rc.stop_reporting()
for _ in range(50):
    _qapp.processEvents()
    time.sleep(0.1)
check("isRunning after stop", rc.isRunning == False)

# ═══════════════════════════════════════════════════════════════
#  5. FtpWorker._generate_and_send — verify file creation
# ═══════════════════════════════════════════════════════════════
section("5. Verify report file creation")

report_files = list(REPORT_DIR.glob("TEST-001_*.txt"))
check("Report files generated", len(report_files) > 0, f"files: {[f.name for f in report_files]}")

if report_files:
    latest = sorted(report_files, key=lambda f: f.stat().st_mtime)[-1]
    content = latest.read_text(encoding="utf-8")
    lines = content.strip().split("\n")
    check("Report has data lines", len(lines) > 0, f"lines: {len(lines)}")
    if lines:
        fields = lines[0].split("\t")
        check("Report 5 fields", len(fields) == 5, f"fields: {len(fields)} — {lines[0]}")

# ═══════════════════════════════════════════════════════════════
#  6. ReportLog — verify generate_and_send created log
# ═══════════════════════════════════════════════════════════════
section("6. ReportLog entries from generate_and_send")

session = get_session()
logs = session.exec(select(ReportLog).order_by(ReportLog.id.desc()).limit(5)).all()
session.close()

check("ReportLog entries exist", len(logs) > 0, f"count: {len(logs)}")
if logs:
    latest_log = logs[0]
    check("Latest log has filename", latest_log.filename.endswith(".txt"), f"filename: {latest_log.filename}")
    check("Latest log status", latest_log.status in ("pending", "sent", "failed"), f"status: {latest_log.status}")

# ═══════════════════════════════════════════════════════════════
#  7. Crypto — decrypt FTP password
# ═══════════════════════════════════════════════════════════════
section("7. Crypto decrypt")

from core.crypto import encrypt, decrypt

enc = encrypt("TestPass123")
dec = decrypt(enc)
check("Encrypt → Decrypt roundtrip", dec == "TestPass123")
check("Encrypted != plaintext", enc != "TestPass123")

# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════
total = passed + failed
print(f"\n{'='*60}")
print(f"  KẾT QUẢ: {passed}/{total} PASSED, {deprecation_count} DeprecationWarning, {failed} lỗi")
print(f"{'='*60}")

sys.exit(0 if failed == 0 else 1)
