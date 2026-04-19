"""Test M2 — Cấu hình Trạm & Cảm biến.

Tiêu chí Done M2:
  1. Form đầy đủ ở View Cấu hình (kiểm tra controller/model tồn tại)
  2. Load / Save AppConfig vào ra DB chính xác (mật khẩu FTP encrypt)
  3. Thêm, sửa, xóa cảm biến ổn định
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PySide6.QtCore import QCoreApplication

app = QCoreApplication.instance()
if app is None:
    app = QCoreApplication(sys.argv)

from sqlmodel import select

from core.database import init_db, get_session
from core.crypto import encrypt, decrypt
from models.app_config import AppConfig
from models.sensor import Sensor

init_db()

passed = 0
failed = 0


def check(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  [PASS] {name}" + (f" — {detail}" if detail else ""))
    else:
        failed += 1
        print(f"  [FAIL] {name}" + (f" — {detail}" if detail else ""))


# ─── M2.1: SettingsController ────────────────────────────────────────────────
print("\n=== M2.1: SettingsController — Load/Save AppConfig ===")

from ui.controllers.settings_controller import SettingsController

sc = SettingsController()
check("SettingsController instantiates", sc is not None)

# Load (creates default if empty)
sc.load_config()
check("load_config() creates default row", sc.stationCode is not None)

# Set values
sc.stationCode = "TEST-001"
sc.stationName = "Trạm Thử Nghiệm"
sc.ftpAddress = "ftp.example.com"
sc.ftpPort = 22
sc.ftpUsername = "admin"
sc.ftpPassword = "MySecret123"
sc.ftpRemotePath = "/data/reports"
sc.pollInterval = 5

# Save
sc.save_config()

# Reload to verify persistence
sc2 = SettingsController()
sc2.load_config()
check("station_code persisted", sc2.stationCode == "TEST-001", f"got '{sc2.stationCode}'")
check("station_name persisted", sc2.stationName == "Trạm Thử Nghiệm", f"got '{sc2.stationName}'")
check("ftp_address persisted", sc2.ftpAddress == "ftp.example.com")
check("ftp_port persisted", sc2.ftpPort == 22)
check("ftp_username persisted", sc2.ftpUsername == "admin")
check("poll_interval persisted", sc2.pollInterval == 5)
check("ftp_remote_path persisted", sc2.ftpRemotePath == "/data/reports")

# FTP password encryption
check("ftpPassword decrypted matches", sc2.ftpPassword == "MySecret123",
      f"got '{sc2.ftpPassword}'")

# Verify raw DB has encrypted value (not plaintext)
session = get_session()
cfg_row = session.exec(select(AppConfig)).first()
raw_pw = cfg_row.ftp_password
session.close()
check("DB stores encrypted password (not plaintext)", raw_pw != "MySecret123" and len(raw_pw) > 20,
      f"raw length={len(raw_pw)}")
check("Decrypt raw matches original", decrypt(raw_pw) == "MySecret123")

# ─── M2.5: Validation ────────────────────────────────────────────────────────
print("\n=== M2.5: Validation ===")
sc3 = SettingsController()
sc3.load_config()
sc3.stationCode = ""
sc3.stationName = ""
errors = sc3._validate()
check("Empty station_code triggers error", any("Mã trạm" in e for e in errors), str(errors))
check("Empty station_name triggers error", any("Tên trạm" in e for e in errors))

sc3.pollInterval = 0
errors2 = sc3._validate()
check("poll_interval < 1 triggers error", any("polling" in e for e in errors2))

# ─── M2.2: SensorListModel CRUD ──────────────────────────────────────────────
print("\n=== M2.2: SensorListModel — CRUD ===")

from ui.models.sensor_list_model import SensorListModel

sm = SensorListModel()
sm.refresh()
initial_count = sm.rowCount()

# Add
sm.add_sensor("Nhiệt Độ", "°C", 1, 100, "input", "int16", "AB", '{"a":0.1,"b":0}', 1, True)
sm.refresh()
check("add_sensor increases count", sm.rowCount() == initial_count + 1, f"count={sm.rowCount()}")

# Get
s = sm.get_sensor(sm.rowCount() - 1)
check("get_sensor returns correct name", s.get("name") == "Nhiệt Độ", str(s.get("name")))
check("get_sensor returns correct slaveId", s.get("slaveId") == 1)
check("get_sensor returns correct registerAddress", s.get("registerAddress") == 100)
sensor_id = s.get("sensorId")

# Update
sm.update_sensor(sensor_id, "Nhiệt Độ v2", "K", 2, 200, "holding", "float32", "ABCD", '{"a":1,"b":-273}', 2, False)
sm.refresh()
s2 = None
for i in range(sm.rowCount()):
    t = sm.get_sensor(i)
    if t.get("sensorId") == sensor_id:
        s2 = t
        break
check("update_sensor changes name", s2 and s2.get("name") == "Nhiệt Độ v2")
check("update_sensor changes slaveId", s2 and s2.get("slaveId") == 2)
check("update_sensor changes active=False", s2 and s2.get("active") == False)

# Remove
sm.remove_sensor(sensor_id)
sm.refresh()
check("remove_sensor decreases count", sm.rowCount() == initial_count, f"count={sm.rowCount()}")

# Validation
print("\n=== M2.2: Sensor Validation ===")
errors_before = sm.rowCount()
sm.add_sensor("", "°C", 0, 0, "input", "int16", "AB", "{}", 0, True)
sm.refresh()
check("Empty name rejected (count unchanged)", sm.rowCount() == errors_before)

# ─── M2.4: Load config state ─────────────────────────────────────────────────
print("\n=== M2.4: Load config state for QML ===")
sc4 = SettingsController()
sc4.load_config()
check("Reloaded config has Properties", hasattr(sc4, 'stationCode') and hasattr(sc4, 'ftpPassword'))
check("Properties have correct types", isinstance(sc4.stationCode, str) and isinstance(sc4.ftpPort, int))

# ─── Summary ─────────────────────────────────────────────────────────────────
print("\n" + "=" * 60)
print(f"M2 TEST RESULTS:  {passed} passed, {failed} failed")
if failed == 0:
    print("ALL M2 TESTS PASSED ✓")
else:
    print(f"⚠  {failed} test(s) FAILED")
print("=" * 60)
