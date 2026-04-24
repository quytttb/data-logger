#!/usr/bin/env python3
"""Test M6 — Phase 1: Digital I/O, Alarm Thresholds, ModbusWorker Alarm Logic.

Tests:
  1. DigitalIO model CRUD
  2. Sensor min_threshold / max_threshold persistence
  3. SensorListModel DI/DO methods (add, get, remove, limit 5)
  4. SensorListModel threshold parsing
  5. ModbusWorker alarm state machine
  6. ModbusWorker _drive_do_relays / _read_di_states (unit-level)
  7. MonitorModel alarm role exposure
  8. MonitorController alarm_changed handler
  9. Database migration (columns exist)
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime
from unittest.mock import MagicMock, patch, PropertyMock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PySide6.QtCore import QCoreApplication
_qapp = QCoreApplication.instance() or QCoreApplication(sys.argv)

from sqlmodel import select
from sqlalchemy import inspect as sa_inspect

from core.database import init_db, get_session, engine
from models.sensor import Sensor
from models.digital_io import DigitalIO
from models.sensor_data import SensorData

init_db()

passed = 0
failed = 0


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
#  1. Database schema — new columns & table exist
# ═══════════════════════════════════════════════════════════════
section("1. Database schema verification")

inspector = sa_inspect(engine)
tables = inspector.get_table_names()
check("digital_io table exists", "digital_io" in tables, f"tables: {tables}")

sensor_cols = {c["name"] for c in inspector.get_columns("sensor")}
check("sensor.min_threshold column exists", "min_threshold" in sensor_cols, str(sensor_cols))
check("sensor.max_threshold column exists", "max_threshold" in sensor_cols, str(sensor_cols))

dio_cols = {c["name"] for c in inspector.get_columns("digital_io")}
expected_dio_cols = {"id", "sensor_id", "io_type", "label", "slave_id", "address",
                     "trigger_on_max", "trigger_on_min", "active", "created_at"}
check("digital_io has all expected columns",
      expected_dio_cols.issubset(dio_cols),
      f"missing: {expected_dio_cols - dio_cols}")

# ═══════════════════════════════════════════════════════════════
#  2. Sensor model — threshold fields
# ═══════════════════════════════════════════════════════════════
section("2. Sensor model threshold fields")

session = get_session()
try:
    s = Sensor(
        name="Alarm Test Sensor", unit="mg/L",
        slave_id=1, register_address=100,
        register_type="holding", data_type="int16",
        data_format="AB", coefficient="{}",
        report_index=1, active=True,
        min_threshold=5.0, max_threshold=95.5,
    )
    session.add(s)
    session.commit()
    session.refresh(s)
    test_sensor_id = s.id

    check("Sensor created with thresholds", s.id is not None)
    check("min_threshold stored", s.min_threshold == 5.0, f"got: {s.min_threshold}")
    check("max_threshold stored", s.max_threshold == 95.5, f"got: {s.max_threshold}")

    # Test None thresholds (disabled)
    s2 = Sensor(
        name="No Threshold Sensor", unit="°C",
        slave_id=2, register_address=200,
        register_type="input", data_type="int16",
        data_format="AB", report_index=2, active=True,
    )
    session.add(s2)
    session.commit()
    session.refresh(s2)
    check("Sensor with None thresholds", s2.min_threshold is None and s2.max_threshold is None)
    session.delete(s2)
    session.commit()
finally:
    session.close()

# ═══════════════════════════════════════════════════════════════
#  3. DigitalIO model CRUD
# ═══════════════════════════════════════════════════════════════
section("3. DigitalIO model CRUD")

session = get_session()
try:
    # Create DI
    di = DigitalIO(
        sensor_id=test_sensor_id, io_type="DI",
        label="Float Switch", slave_id=3, address=10,
        trigger_on_max=True, trigger_on_min=True, active=True,
    )
    session.add(di)
    session.commit()
    session.refresh(di)
    check("DI created", di.id is not None)
    check("DI io_type", di.io_type == "DI", f"got: {di.io_type}")
    check("DI label", di.label == "Float Switch")
    check("DI slave_id", di.slave_id == 3)
    check("DI address", di.address == 10)
    di_id = di.id

    # Create DO
    do = DigitalIO(
        sensor_id=test_sensor_id, io_type="DO",
        label="Buzzer", slave_id=3, address=0,
        trigger_on_max=True, trigger_on_min=False, active=True,
    )
    session.add(do)
    session.commit()
    session.refresh(do)
    check("DO created", do.id is not None)
    check("DO trigger_on_max", do.trigger_on_max == True)
    check("DO trigger_on_min", do.trigger_on_min == False)
    do_id = do.id

    # Query by sensor_id
    ios = list(session.exec(
        select(DigitalIO).where(DigitalIO.sensor_id == test_sensor_id)
    ).all())
    check("Query DI/DO by sensor_id", len(ios) == 2, f"got {len(ios)}")

    # Delete
    session.delete(di)
    session.delete(do)
    session.commit()
    remaining = list(session.exec(
        select(DigitalIO).where(DigitalIO.sensor_id == test_sensor_id)
    ).all())
    check("Delete DI/DO", len(remaining) == 0)
finally:
    session.close()

# ═══════════════════════════════════════════════════════════════
#  4. SensorListModel — threshold parsing & DI/DO CRUD
# ═══════════════════════════════════════════════════════════════
section("4. SensorListModel — threshold & DI/DO")

from ui.models.sensor_list_model import SensorListModel

sm = SensorListModel()

# _parse_threshold tests
check("parse '' → None", sm._parse_threshold("") is None)
check("parse '  ' → None", sm._parse_threshold("  ") is None)
check("parse '10.5' → 10.5", sm._parse_threshold("10.5") == 10.5)
check("parse '10,5' → 10.5 (comma)", sm._parse_threshold("10,5") == 10.5)
check("parse 'abc' → None", sm._parse_threshold("abc") is None)
check("parse '-3.14' → -3.14", sm._parse_threshold("-3.14") == -3.14)
check("parse '0' → 0.0", sm._parse_threshold("0") == 0.0)

# Test add_sensor with thresholds
sm.refresh()
initial = sm.rowCount()
sm.add_sensor(
    "Threshold Test", "mg/L", 1, 300, "holding", "int16", "AB", "{}",
    3, 0, True, "5.0", "95.5"
)
sm.refresh()
check("add_sensor with thresholds", sm.rowCount() == initial + 1)

# Find the sensor we just added
s_data = sm.get_sensor(sm.rowCount() - 1)
check("get_sensor minThreshold", s_data.get("minThreshold") == 5.0, f"got: {s_data.get('minThreshold')}")
check("get_sensor maxThreshold", s_data.get("maxThreshold") == 95.5, f"got: {s_data.get('maxThreshold')}")
threshold_sensor_id = s_data.get("sensorId")

# Update with new thresholds
sm.update_sensor(
    threshold_sensor_id, "Threshold Test v2", "mg/L", 1, 300,
    "holding", "int16", "AB", "{}", 3, 0, True, "10", "80"
)
sm.refresh()
for i in range(sm.rowCount()):
    t = sm.get_sensor(i)
    if t.get("sensorId") == threshold_sensor_id:
        check("update_sensor minThreshold", t.get("minThreshold") == 10.0, f"got: {t.get('minThreshold')}")
        check("update_sensor maxThreshold", t.get("maxThreshold") == 80.0, f"got: {t.get('maxThreshold')}")
        break

# Update with empty thresholds (disable)
sm.update_sensor(
    threshold_sensor_id, "Threshold Test v3", "mg/L", 1, 300,
    "holding", "int16", "AB", "{}", 3, 0, True, "", ""
)
sm.refresh()
for i in range(sm.rowCount()):
    t = sm.get_sensor(i)
    if t.get("sensorId") == threshold_sensor_id:
        check("empty threshold → disabled (min)", t.get("minThreshold") == "")
        check("empty threshold → disabled (max)", t.get("maxThreshold") == "")
        break

# DI/DO CRUD via SensorListModel
section("4b. SensorListModel — DI/DO CRUD")

# Get (should be empty initially)
ios = sm.get_digital_ios(threshold_sensor_id)
check("get_digital_ios initially empty", len(ios) == 0, f"got: {len(ios)}")

# Add DI
sm.add_digital_io(threshold_sensor_id, "DI", "Float Switch", 3, 10, True, True, True)
ios = sm.get_digital_ios(threshold_sensor_id)
check("add DI → count 1", len(ios) == 1, f"got: {len(ios)}")
check("DI ioType", ios[0]["ioType"] == "DI")
check("DI label", ios[0]["label"] == "Float Switch")

# Add DO
sm.add_digital_io(threshold_sensor_id, "DO", "Buzzer", 3, 0, True, False, True)
ios = sm.get_digital_ios(threshold_sensor_id)
check("add DO → count 2", len(ios) == 2, f"got: {len(ios)}")
do_entry = [io for io in ios if io["ioType"] == "DO"][0]
check("DO triggerOnMax", do_entry["triggerOnMax"] == True)
check("DO triggerOnMin", do_entry["triggerOnMin"] == False)

# Test 5-limit
for i in range(4):
    sm.add_digital_io(threshold_sensor_id, "DI", f"DI-{i+2}", 3, 11 + i, True, True, True)
ios = sm.get_digital_ios(threshold_sensor_id)
di_count = len([io for io in ios if io["ioType"] == "DI"])
check("5 DI limit reached", di_count == 5, f"got: {di_count}")

# Try adding 6th DI — should be rejected
sm.add_digital_io(threshold_sensor_id, "DI", "DI-overflow", 3, 99, True, True, True)
ios = sm.get_digital_ios(threshold_sensor_id)
di_count = len([io for io in ios if io["ioType"] == "DI"])
check("6th DI rejected (still 5)", di_count == 5, f"got: {di_count}")

# Remove one
first_di_id = [io for io in ios if io["ioType"] == "DI"][0]["id"]
sm.remove_digital_io(first_di_id)
ios = sm.get_digital_ios(threshold_sensor_id)
di_count = len([io for io in ios if io["ioType"] == "DI"])
check("remove DI → count 4", di_count == 4, f"got: {di_count}")

# Remove all DI/DO for cleanup
for io in sm.get_digital_ios(threshold_sensor_id):
    sm.remove_digital_io(io["id"])
ios = sm.get_digital_ios(threshold_sensor_id)
check("cleanup all DI/DO", len(ios) == 0)

# ═══════════════════════════════════════════════════════════════
#  5. ModbusWorker — alarm threshold logic (unit test)
# ═══════════════════════════════════════════════════════════════
section("5. ModbusWorker alarm logic")

from workers.modbus_worker import ModbusWorker

mw = ModbusWorker(port="/dev/ttyUSB0", baudrate=9600, poll_interval=3)

# Test alarm state tracking
check("alarm_states initially empty", len(mw._alarm_states) == 0)
check("digital_ios initially empty", len(mw._digital_ios) == 0)

# set_digital_ios
test_ios = {
    1: [
        {"id": 10, "io_type": "DI", "label": "Float", "slave_id": 3, "address": 0, "active": True,
         "trigger_on_max": True, "trigger_on_min": True},
        {"id": 11, "io_type": "DO", "label": "Buzzer", "slave_id": 3, "address": 1, "active": True,
         "trigger_on_max": True, "trigger_on_min": False},
    ],
}
mw.set_digital_ios(test_ios)
check("set_digital_ios stored", len(mw._digital_ios) == 1)
check("set_digital_ios channels", len(mw._digital_ios[1]) == 2)

# Test _read_di_states with no client
di_states = mw._read_di_states(1)
check("_read_di_states no client → empty", len(di_states) == 0)

# Test _drive_do_relays with no client (should not crash)
try:
    mw._drive_do_relays(1, True, "max")
    check("_drive_do_relays no client → no crash", True)
except Exception as e:
    check("_drive_do_relays no client → no crash", False, str(e))

# Test alarm_changed signal
check("alarm_changed signal exists", hasattr(mw, "alarm_changed"))

# ═══════════════════════════════════════════════════════════════
#  6. ModbusWorker — _poll_single alarm detection (mocked)
# ═══════════════════════════════════════════════════════════════
section("6. ModbusWorker _poll_single alarm (mocked)")

alarm_emissions = []
data_emissions = []

def capture_alarm(info):
    alarm_emissions.append(info)

def capture_data(payload):
    data_emissions.append(payload)

mw2 = ModbusWorker(port="/dev/null", baudrate=9600, poll_interval=3)
mw2.alarm_changed.connect(capture_alarm)
mw2.data_ready.connect(capture_data)

# Mock _read_register to return controlled values
# Mock _read_di_states to return empty (no actual DI to read)
sensor_cfg = {
    "id": 42,
    "slave_id": 1,
    "register_address": 0,
    "register_type": "holding",
    "data_type": "int16",
    "data_format": "AB",
    "coefficient": "{}",
    "min_threshold": 10.0,
    "max_threshold": 90.0,
}

# Test 1: Normal value (no alarm)
with patch.object(mw2, "_read_register", return_value=50):
    mw2._poll_single(sensor_cfg)

check("Normal value → no alarm signal", len(alarm_emissions) == 0)
check("Normal value → data emitted", len(data_emissions) == 1)
check("Normal value → is_alarm=False", data_emissions[-1]["is_alarm"] == False)
check("Normal value → alarm_type empty", data_emissions[-1]["alarm_type"] == "")

# Test 2: Value crosses max_threshold → alarm ON
with patch.object(mw2, "_read_register", return_value=95):
    mw2._poll_single(sensor_cfg)

check("Max alarm → alarm_changed emitted", len(alarm_emissions) == 1)
check("Max alarm → is_alarm=True", alarm_emissions[-1]["is_alarm"] == True)
check("Max alarm → alarm_type=max", alarm_emissions[-1]["alarm_type"] == "max")
check("Max alarm → data is_alarm=True", data_emissions[-1]["is_alarm"] == True)

# Test 3: Still alarming (no re-emission)
with patch.object(mw2, "_read_register", return_value=96):
    mw2._poll_single(sensor_cfg)

check("Sustained alarm → no extra alarm_changed", len(alarm_emissions) == 1,
      f"got {len(alarm_emissions)}")

# Test 4: Value returns to normal → alarm OFF
with patch.object(mw2, "_read_register", return_value=50):
    mw2._poll_single(sensor_cfg)

check("Alarm cleared → alarm_changed emitted again", len(alarm_emissions) == 2)
check("Alarm cleared → is_alarm=False", alarm_emissions[-1]["is_alarm"] == False)

# Test 5: Min threshold alarm
with patch.object(mw2, "_read_register", return_value=5):
    mw2._poll_single(sensor_cfg)

check("Min alarm → alarm_changed emitted", len(alarm_emissions) == 3)
check("Min alarm → alarm_type=min", alarm_emissions[-1]["alarm_type"] == "min")

# Test 6: Both thresholds (value at exact boundary)
mw2._alarm_states.clear()  # reset state
sensor_cfg_tight = {**sensor_cfg, "min_threshold": 50.0, "max_threshold": 50.0}
with patch.object(mw2, "_read_register", return_value=50):
    mw2._poll_single(sensor_cfg_tight)

last_data = data_emissions[-1]
check("Both thresholds → alarm_type=min+max", last_data["alarm_type"] == "min+max",
      f"got: {last_data['alarm_type']}")

# Test 7: No thresholds set → no alarm
mw2._alarm_states.clear()
sensor_cfg_no_th = {**sensor_cfg, "min_threshold": None, "max_threshold": None}
prev_alarm_count = len(alarm_emissions)
with patch.object(mw2, "_read_register", return_value=999):
    mw2._poll_single(sensor_cfg_no_th)

check("No thresholds → no alarm", len(alarm_emissions) == prev_alarm_count)
check("No thresholds → is_alarm=False", data_emissions[-1]["is_alarm"] == False)

# ═══════════════════════════════════════════════════════════════
#  7. MonitorModel — alarm role exposure
# ═══════════════════════════════════════════════════════════════
section("7. MonitorModel alarm roles")

from ui.controllers.monitor_controller import MonitorModel
from PySide6.QtCore import Qt

dm = MonitorModel()

# Create a test sensor for the model
session = get_session()
s_test = session.get(Sensor, test_sensor_id)
session.expunge(s_test)
session.close()

dm.load_sensors([s_test])
check("MonitorModel loaded 1 sensor", dm.rowCount() == 1)

idx = dm.index(0, 0)
is_alarm_role = Qt.UserRole + 8
alarm_type_role = Qt.UserRole + 9

# Initial state
check("Initial isAlarm = False", dm.data(idx, is_alarm_role) == False)
check("Initial alarmType = ''", dm.data(idx, alarm_type_role) == "")

# Update with alarm
dm.update_value(test_sensor_id, 99.0, 9900, datetime.now().isoformat(), True, "max")
check("After alarm: isAlarm = True", dm.data(idx, is_alarm_role) == True)
check("After alarm: alarmType = 'max'", dm.data(idx, alarm_type_role) == "max")
status_role = Qt.UserRole + 6
check("After alarm: status = 'ALARM'", dm.data(idx, status_role) == "ALARM")

# Clear alarm
dm.update_value(test_sensor_id, 50.0, 5000, datetime.now().isoformat(), False, "")
check("After clear: isAlarm = False", dm.data(idx, is_alarm_role) == False)
check("After clear: status = 'OK'", dm.data(idx, status_role) == "OK")

# ═══════════════════════════════════════════════════════════════
#  8. MonitorController — _on_alarm_changed handler
# ═══════════════════════════════════════════════════════════════
section("8. MonitorController alarm handler")

from ui.controllers.monitor_controller import MonitorController

dm2 = MonitorModel()
mc = MonitorController(dm2)

# Test that _on_alarm_changed doesn't crash
try:
    mc._on_alarm_changed({"sensor_id": 1, "is_alarm": True, "alarm_type": "max"})
    check("_on_alarm_changed (alarm ON) no crash", True)
except Exception as e:
    check("_on_alarm_changed (alarm ON) no crash", False, str(e))

try:
    mc._on_alarm_changed({"sensor_id": 1, "is_alarm": False, "alarm_type": ""})
    check("_on_alarm_changed (alarm OFF) no crash", True)
except Exception as e:
    check("_on_alarm_changed (alarm OFF) no crash", False, str(e))

# ═══════════════════════════════════════════════════════════════
#  9. Cleanup test data
# ═══════════════════════════════════════════════════════════════
section("9. Cleanup")

session = get_session()
try:
    # Remove test sensor
    ts = session.get(Sensor, test_sensor_id)
    if ts:
        session.delete(ts)
    # Remove threshold test sensor
    ts2 = session.get(Sensor, threshold_sensor_id)
    if ts2:
        session.delete(ts2)
    # Remove any orphaned DigitalIO
    orphans = list(session.exec(
        select(DigitalIO).where(
            DigitalIO.sensor_id.in_([test_sensor_id, threshold_sensor_id])
        )
    ).all())
    for o in orphans:
        session.delete(o)
    session.commit()
    check("Test data cleaned up", True)
except Exception as e:
    session.rollback()
    check("Test data cleaned up", False, str(e))
finally:
    session.close()

# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════
total = passed + failed
print(f"\n{'='*60}")
print(f"  M6 Phase 1 RESULTS: {passed}/{total} PASSED, {failed} FAILED")
if failed == 0:
    print("  ALL M6 TESTS PASSED ✓")
else:
    print(f"  ⚠  {failed} test(s) FAILED")
print(f"{'='*60}")

sys.exit(0 if failed == 0 else 1)
