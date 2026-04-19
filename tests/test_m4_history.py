#!/usr/bin/env python3
"""M4 Test — HistoryModel + HistoryController + SearchWorker + CSV export.

Chạy trên RPi: cd /home/pi/data-logger/app && python -W all tests/test_m4_history.py
"""

import os
import sys
import time
import warnings

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime, timedelta
from pathlib import Path

from PySide6.QtCore import QCoreApplication, Qt
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
from models.sensor import Sensor
from models.sensor_data import SensorData

init_db()
check("Import OK", True)

# Seed test data
session = get_session()
sensor = session.exec(select(Sensor)).first()
if sensor is None:
    sensor = Sensor(name="Test Sensor", unit="°C", slave_id=1, register_address=0,
                    register_type="input", data_type="int16", data_format="AB",
                    coefficient="{}", report_index=1, active=True)
    session.add(sensor)
    session.commit()
    session.refresh(sensor)

now = datetime.now()
seed_count = 0
for i in range(25):
    sd = SensorData(
        sensor_id=sensor.id,
        value=20.0 + i * 0.5,
        raw_value=200 + i * 5,
        recorded_at=now - timedelta(minutes=25 - i),
    )
    session.add(sd)
    seed_count += 1
session.commit()
session.close()
check("Seeded 25 SensorData records", seed_count == 25)

# ═══════════════════════════════════════════════════════════════
#  1. HistoryModel
# ═══════════════════════════════════════════════════════════════
section("1. HistoryModel")

from ui.controllers.history_controller import HistoryModel, HistoryController, MAX_RECORDS

hm = HistoryModel()
check("Initial rowCount == 0", hm.rowCount() == 0)

test_items = [
    {"recorded_at": "08/04/2026 10:00:00", "sensor_name": "Temp", "unit": "°C", "value": "25.5", "raw_value": "255"},
    {"recorded_at": "08/04/2026 10:01:00", "sensor_name": "Temp", "unit": "°C", "value": "26.0", "raw_value": "260"},
]
hm.set_data(test_items)
check("set_data rowCount == 2", hm.rowCount() == 2)

idx = hm.index(0, 0)
recorded_role = Qt.UserRole + 1
name_role = Qt.UserRole + 2
value_role = Qt.UserRole + 4
check("data role recordedAt", hm.data(idx, recorded_role) == "08/04/2026 10:00:00")
check("data role sensorName", hm.data(idx, name_role) == "Temp")
check("data role value", hm.data(idx, value_role) == "25.5")

check("get_all returns list", len(hm.get_all()) == 2)

hm.set_data([])
check("set_data empty → rowCount == 0", hm.rowCount() == 0)

# ═══════════════════════════════════════════════════════════════
#  2. HistoryController — search
# ═══════════════════════════════════════════════════════════════
section("2. HistoryController — search")

hm2 = HistoryModel()
hc = HistoryController(hm2)
check("isLoading initial False", hc.isLoading == False)
check("recordCount initial 0", hc.recordCount == 0)

today_str = now.strftime("%d/%m/%Y")
hc.search(today_str, today_str)
check("isLoading after search", hc.isLoading == True)

for _ in range(30):
    _qapp.processEvents()
    time.sleep(0.1)

check("isLoading after wait", hc.isLoading == False)
check("recordCount > 0", hc.recordCount > 0, f"got: {hc.recordCount}")
check("model has rows", hm2.rowCount() > 0, f"got: {hm2.rowCount()}")
check("recordCount == model.rowCount", hc.recordCount == hm2.rowCount())

if hm2.rowCount() > 0:
    idx0 = hm2.index(0, 0)
    v = hm2.data(idx0, name_role)
    check("First record has sensor name", v is not None and len(v) > 0, f"got: {v}")

# ═══════════════════════════════════════════════════════════════
#  3. Search empty range
# ═══════════════════════════════════════════════════════════════
section("3. Search empty range")

hm3 = HistoryModel()
hc2 = HistoryController(hm3)
hc2.search("01/01/2020", "02/01/2020")

for _ in range(20):
    _qapp.processEvents()
    time.sleep(0.1)

check("Empty range → recordCount == 0", hc2.recordCount == 0)
check("Empty range → model empty", hm3.rowCount() == 0)

# ═══════════════════════════════════════════════════════════════
#  4. Search validation
# ═══════════════════════════════════════════════════════════════
section("4. Search validation")

messages = []
def capture_msg(t, m):
    messages.append((t, m))

hm4 = HistoryModel()
hc3 = HistoryController(hm4)
hc3.messageSent.connect(capture_msg)

hc3.search("invalid", "date")
_qapp.processEvents()
check("Invalid date format → error message", len(messages) > 0 and "Invalid" in messages[-1][1], f"messages: {messages}")

messages.clear()
hc3.search("10/04/2026", "01/04/2026")
_qapp.processEvents()
check("From > To → error message", len(messages) > 0 and "before" in messages[-1][1], f"messages: {messages}")

# ═══════════════════════════════════════════════════════════════
#  5. CSV export
# ═══════════════════════════════════════════════════════════════
section("5. CSV export")

hm5 = HistoryModel()
hc4 = HistoryController(hm5)
hc4.search(today_str, today_str)
for _ in range(30):
    _qapp.processEvents()
    time.sleep(0.1)

csv_path = Path(__file__).resolve().parent.parent / "data" / "test_export.csv"
csv_path.parent.mkdir(parents=True, exist_ok=True)

msg5 = []
hc4.messageSent.connect(lambda t, m: msg5.append((t, m)))
hc4.export_csv(str(csv_path))
_qapp.processEvents()

check("CSV file created", csv_path.exists())

if csv_path.exists():
    with open(csv_path, "r", encoding="utf-8-sig") as f:
        content = f.read()
    lines = content.strip().split("\n")
    check("CSV has header + data", len(lines) > 1, f"lines: {len(lines)}")
    check("CSV header correct", "Time" in lines[0] and "Sensor" in lines[0])
    with open(csv_path, "rb") as bf:
        check("CSV UTF-8 BOM", bf.read(3) == b"\xef\xbb\xbf")
    csv_path.unlink()
    check("CSV cleanup done", not csv_path.exists())

# Empty export
msg6 = []
hm6 = HistoryModel()
hc5 = HistoryController(hm6)
hc5.messageSent.connect(lambda t, m: msg6.append((t, m)))
hc5.export_csv("/tmp/empty.csv")
_qapp.processEvents()
check("Export empty → info message", len(msg6) > 0 and "No data" in msg6[-1][1])

# ═══════════════════════════════════════════════════════════════
#  6. MAX_RECORDS constant
# ═══════════════════════════════════════════════════════════════
section("6. Constants")

check("MAX_RECORDS == 5000", MAX_RECORDS == 5000)

# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════
total = passed + failed
print(f"\n{'='*60}")
print(f"  KẾT QUẢ: {passed}/{total} PASSED, {deprecation_count} DeprecationWarning, {failed} lỗi")
print(f"{'='*60}")

sys.exit(0 if failed == 0 else 1)
