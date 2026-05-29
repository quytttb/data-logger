#!/usr/bin/env python3
"""Test M6 — DI/DO Inventory + AnalogDigitalLink.

Tests:
  1. Database schema — analog_digital_link table, sensor columns updated
  2. Sensor model — threshold fields, SensorType enum (no parent_id/is_system_wide)
  3. AnalogDigitalLink CRUD (attach/detach)
  4. SensorListModel attach_di, attach_do, detach_link, get_analog_links, list_di/do
  5. Validation rules — address unique, DO single analog, max 5, type check
  6. ModbusWorker alarm + standalone DI status "00"
  7. MonitorModel alarm roles
  8. MonitorController alarm_changed handler
"""

import os
import sys
from pathlib import Path
from datetime import datetime
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PySide6.QtCore import QCoreApplication
_qapp = QCoreApplication.instance() or QCoreApplication(sys.argv)

from sqlmodel import select
from sqlalchemy import inspect as sa_inspect

from core.database import init_db, get_session, engine
from models.sensor import Sensor, SensorType
from models.analog_digital_link import AnalogDigitalLink
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
#  1. Database schema
# ═══════════════════════════════════════════════════════════════
section("1. Database schema verification")

inspector = sa_inspect(engine)
tables = inspector.get_table_names()
check("analog_digital_link table exists", "analog_digital_link" in tables, f"tables: {tables}")
check("sensor table exists", "sensor" in tables)

sensor_cols = {c["name"] for c in inspector.get_columns("sensor")}
check("sensor.sensor_type column exists", "sensor_type" in sensor_cols)
check("sensor.di_type column exists", "di_type" in sensor_cols)

link_cols = {c["name"] for c in inspector.get_columns("analog_digital_link")}
check("link.analog_sensor_id column exists", "analog_sensor_id" in link_cols)
check("link.digital_sensor_id column exists", "digital_sensor_id" in link_cols)
check("link.di_type column exists", "di_type" in link_cols)
check("link.trigger_on_max column exists", "trigger_on_max" in link_cols)
check("link.trigger_on_min column exists", "trigger_on_min" in link_cols)

# ═══════════════════════════════════════════════════════════════
#  2. Sensor model
# ═══════════════════════════════════════════════════════════════
section("2. Sensor model — SensorType enum, thresholds")

check("SensorType.ANALOG", SensorType.ANALOG == "ANALOG")
check("SensorType.DI", SensorType.DI == "DI")
check("SensorType.DO", SensorType.DO == "DO")

session = get_session()
try:
    analog = Sensor(
        sensor_type=SensorType.ANALOG,
        name="Alarm Test Analog", unit="mg/L",
        slave_id=1, register_address=100,
        register_type="holding", data_type="int16",
        data_format="AB", coefficient="{}",
        report_index=1, active=True,
        min_threshold=5.0, max_threshold=95.5,
    )
    session.add(analog)
    session.commit()
    session.refresh(analog)
    analog_id = analog.id

    check("ANALOG created", analog.id is not None)
    check("sensor_type = ANALOG", analog.sensor_type == SensorType.ANALOG)
    check("min_threshold stored", analog.min_threshold == 5.0)
    check("max_threshold stored", analog.max_threshold == 95.5)

    # Create top-level DI sensor
    di_sensor = Sensor(
        sensor_type=SensorType.DI,
        name="Float Switch", slave_id=3, register_address=10,
        register_type="discrete_input", data_type="int16",
        data_format="AB", active=True,
    )
    session.add(di_sensor)
    session.commit()
    session.refresh(di_sensor)
    di_sensor_id = di_sensor.id
    check("DI sensor created top-level", di_sensor.id is not None)

    # Create top-level DO sensor
    do_sensor = Sensor(
        sensor_type=SensorType.DO,
        name="Buzzer", slave_id=3, register_address=0,
        register_type="coil", data_type="int16",
        data_format="AB", active=True,
    )
    session.add(do_sensor)
    session.commit()
    session.refresh(do_sensor)
    do_sensor_id = do_sensor.id
    check("DO sensor created top-level", do_sensor.id is not None)
finally:
    session.close()

# ═══════════════════════════════════════════════════════════════
#  3. AnalogDigitalLink CRUD
# ═══════════════════════════════════════════════════════════════
section("3. AnalogDigitalLink CRUD")

session = get_session()
try:
    # Attach DI to analog
    link_di = AnalogDigitalLink(
        analog_sensor_id=analog_id,
        digital_sensor_id=di_sensor_id,
        di_type="02",
    )
    session.add(link_di)
    session.commit()
    session.refresh(link_di)
    link_di_id = link_di.id
    check("DI link created", link_di.id is not None)
    check("DI link analog_sensor_id", link_di.analog_sensor_id == analog_id)
    check("DI link digital_sensor_id", link_di.digital_sensor_id == di_sensor_id)
    check("DI link di_type", link_di.di_type == "02")

    # Attach DO to analog
    link_do = AnalogDigitalLink(
        analog_sensor_id=analog_id,
        digital_sensor_id=do_sensor_id,
        trigger_on_max=True,
        trigger_on_min=False,
    )
    session.add(link_do)
    session.commit()
    session.refresh(link_do)
    link_do_id = link_do.id
    check("DO link created", link_do.id is not None)
    check("DO link trigger_on_max", link_do.trigger_on_max == True)
    check("DO link trigger_on_min", link_do.trigger_on_min == False)

    # Query links for analog
    links = list(session.exec(
        select(AnalogDigitalLink).where(AnalogDigitalLink.analog_sensor_id == analog_id)
    ).all())
    check("Query links by analog_id = 2", len(links) == 2, f"got {len(links)}")

    # DI can link to a SECOND analog
    analog2 = Sensor(
        sensor_type=SensorType.ANALOG, name="Analog 2", unit="°C",
        slave_id=2, register_address=200, register_type="holding",
        data_type="int16", data_format="AB", active=True,
    )
    session.add(analog2)
    session.commit()
    session.refresh(analog2)
    analog2_id = analog2.id

    link_di_2 = AnalogDigitalLink(
        analog_sensor_id=analog2_id,
        digital_sensor_id=di_sensor_id,
        di_type="01",
    )
    session.add(link_di_2)
    session.commit()
    check("DI linked to second analog", True)

    di_links = list(session.exec(
        select(AnalogDigitalLink).where(AnalogDigitalLink.digital_sensor_id == di_sensor_id)
    ).all())
    check("DI has 2 links (to 2 analogs)", len(di_links) == 2, f"got {len(di_links)}")
    di_types = {lnk.analog_sensor_id: lnk.di_type for lnk in di_links}
    check("DI di_type per analog is different", di_types[analog_id] == "02" and di_types[analog2_id] == "01",
          f"got {di_types}")

    # Detach
    session.delete(link_di_2)
    session.commit()
    remaining = list(session.exec(
        select(AnalogDigitalLink).where(AnalogDigitalLink.digital_sensor_id == di_sensor_id)
    ).all())
    check("Detach 2nd link → 1 remains", len(remaining) == 1, f"got {len(remaining)}")

    # Cleanup analog2
    session.delete(analog2)
    session.commit()
finally:
    session.close()

# ═══════════════════════════════════════════════════════════════
#  4. SensorListModel — attach/detach/list API
# ═══════════════════════════════════════════════════════════════
section("4. SensorListModel — attach/detach/list")

from ui.models.sensor_list_model import SensorListModel

sm = SensorListModel()
sm.refresh()

# _parse_threshold tests
check("parse '' → None", sm._parse_threshold("") is None)
check("parse '  ' → None", sm._parse_threshold("  ") is None)
check("parse '10.5' → 10.5", sm._parse_threshold("10.5") == 10.5)
check("parse '10,5' → 10.5 (comma)", sm._parse_threshold("10,5") == 10.5)
check("parse 'abc' → None", sm._parse_threshold("abc") is None)
check("parse '-3.14' → -3.14", sm._parse_threshold("-3.14") == -3.14)

# add_sensor with explicit sensor_type
initial = sm.rowCount()
sm.add_sensor("Threshold Sensor", "mg/L", 1, 300,
              "Holding Registers", "int16", "AB", "{}", 3, 0, True, "5.0", "95.5")
sm.refresh()
check("add_sensor ANALOG", sm.rowCount() == initial + 1)

# Find the sensor we just added
s_data = None
for i in range(sm.rowCount()):
    td = sm.get_sensor(i)
    if td.get("name") == "Threshold Sensor":
        s_data = td
        break
check("get_sensor found", s_data is not None)
if s_data:
    check("sensorType = ANALOG", s_data.get("sensorType") == "ANALOG", f"got: {s_data.get('sensorType')}")
    check("minThreshold stored", s_data.get("minThreshold") == 5.0, f"got: {s_data.get('minThreshold')}")
    check("maxThreshold stored", s_data.get("maxThreshold") == 95.5, f"got: {s_data.get('maxThreshold')}")
    threshold_sensor_id = s_data.get("sensorId")
else:
    threshold_sensor_id = None

# add_sensor DI/DO
sm.add_sensor("Test DI Sensor", "", 5, 20, "Discrete Inputs", "int16", "AB", "{}", 3, 0, True, "", "")
sm.add_sensor("Test DO Sensor", "", 5, 30, "Coils", "int16", "AB", "{}", 3, 0, True, "", "")
sm.refresh()

di_found = any(sm.get_sensor(i).get("sensorType") == "DI" and sm.get_sensor(i).get("name") == "Test DI Sensor"
               for i in range(sm.rowCount()))
do_found = any(sm.get_sensor(i).get("sensorType") == "DO" and sm.get_sensor(i).get("name") == "Test DO Sensor"
               for i in range(sm.rowCount()))
check("add_sensor DI", di_found)
check("add_sensor DO", do_found)

# list_di_sensors, list_do_sensors
di_list = sm.list_di_sensors()
check("list_di_sensors returns DI sensors", any(d["name"] == "Test DI Sensor" for d in di_list),
      f"got names: {[d['name'] for d in di_list]}")

test_di_id = next((d["id"] for d in di_list if d["name"] == "Test DI Sensor"), None)
test_do_id = None
session = get_session()
try:
    do_row = session.exec(select(Sensor).where(Sensor.name == "Test DO Sensor")).first()
    if do_row:
        test_do_id = do_row.id
    thresh_id = session.exec(select(Sensor).where(Sensor.name == "Threshold Sensor")).first()
    if thresh_id:
        threshold_sensor_id = thresh_id.id
finally:
    session.close()

# attach_di
messages = []
sm.messageSent.connect(lambda t, m: messages.append((t, m)))

if threshold_sensor_id and test_di_id:
    sm.attach_di(threshold_sensor_id, test_di_id, "02")
    links = sm.get_analog_links(threshold_sensor_id)
    check("attach_di → 1 link", len(links) == 1, f"got {len(links)}")
    check("link.ioType = DI", links[0]["ioType"] == "DI", f"got {links[0]}")
    check("link.diType = 02", links[0]["diType"] == "02", f"got {links[0]}")
    link_di_id = links[0]["id"]

    # attach_do
    if test_do_id:
        sm.attach_do(threshold_sensor_id, test_do_id, True, False)
        links = sm.get_analog_links(threshold_sensor_id)
        check("attach_do → 2 links", len(links) == 2, f"got {len(links)}")
        do_links = [l for l in links if l["ioType"] == "DO"]
        check("DO link triggerOnMax", do_links[0]["triggerOnMax"] == True)
        check("DO link triggerOnMin", do_links[0]["triggerOnMin"] == False)
        link_do_id = do_links[0]["id"]

    # update_link_di_type
    sm.update_link_di_type(link_di_id, "03")
    links = sm.get_analog_links(threshold_sensor_id)
    di_links = [l for l in links if l["ioType"] == "DI"]
    check("update_link_di_type → 03", di_links[0]["diType"] == "03", f"got {di_links[0]}")

    # detach_link
    sm.detach_link(link_di_id)
    links = sm.get_analog_links(threshold_sensor_id)
    check("detach_link → 1 link remains", len(links) == 1, f"got {len(links)}")

# ═══════════════════════════════════════════════════════════════
#  5. Validation rules
# ═══════════════════════════════════════════════════════════════
section("5. Validation rules")

from core.sensor_kind import (
    validate_digital_address_unique, validate_attach_di, validate_attach_do
)

session = get_session()
try:
    # Address uniqueness: DI sensor (slave 5, addr 20) is already in DB
    if test_di_id:
        di_row = session.get(Sensor, test_di_id)
        if di_row:
            err = validate_digital_address_unique(
                session, "DI", di_row.slave_id, di_row.register_address
            )
            check("DI duplicate address rejected", err is not None, "expected error")
            err_excl = validate_digital_address_unique(
                session, "DI", di_row.slave_id, di_row.register_address, exclude_id=test_di_id
            )
            check("DI address OK when self excluded", err_excl is None, f"got: {err_excl}")

    # DO: max one analog
    if test_do_id and threshold_sensor_id and analog_id:
        # test_do is already linked to threshold_sensor_id
        do_links = list(session.exec(
            select(AnalogDigitalLink).where(AnalogDigitalLink.digital_sensor_id == test_do_id)
        ).all())
        if do_links:
            err = validate_attach_do(session, analog_id, test_do_id)
            check("DO already linked to other analog → rejected", err is not None, f"got: {err}")

    # Max 5 DI per analog
    if threshold_sensor_id:
        # Add 5 DI sensors and check max enforcement
        added_di_ids = []
        for i in range(5):
            ds = Sensor(
                sensor_type=SensorType.DI, name=f"MaxDI-{i}", slave_id=9, register_address=50+i,
                register_type="discrete_input", data_type="int16", data_format="AB", active=True
            )
            session.add(ds)
            session.commit()
            session.refresh(ds)
            added_di_ids.append(ds.id)
            link = AnalogDigitalLink(
                analog_sensor_id=threshold_sensor_id,
                digital_sensor_id=ds.id,
            )
            session.add(link)
            session.commit()

        di_count = session.exec(
            select(AnalogDigitalLink)
            .where(AnalogDigitalLink.analog_sensor_id == threshold_sensor_id)
        ).all()
        # Try adding 6th DI  
        extra_di = Sensor(
            sensor_type=SensorType.DI, name="ExtraDI", slave_id=9, register_address=99,
            register_type="discrete_input", data_type="int16", data_format="AB", active=True
        )
        session.add(extra_di)
        session.commit()
        session.refresh(extra_di)
        err = validate_attach_di(session, threshold_sensor_id, extra_di.id)
        check("6th DI rejected (max 5)", err is not None, f"got: {err}")

        # Cleanup extra sensors and links
        for did in added_di_ids:
            lnks = list(session.exec(
                select(AnalogDigitalLink).where(AnalogDigitalLink.digital_sensor_id == did)
            ).all())
            for l in lnks:
                session.delete(l)
            session.delete(session.get(Sensor, did))
        session.delete(extra_di)
        session.commit()
finally:
    session.close()

# ═══════════════════════════════════════════════════════════════
#  6. ModbusWorker — standalone DI emits status "00"
# ═══════════════════════════════════════════════════════════════
section("6. ModbusWorker standalone DI status '00'")

from workers.modbus_worker import ModbusWorker

data_emissions = []
mw = ModbusWorker(port="/dev/null", baudrate=9600, poll_interval=3)
mw.data_ready.connect(lambda p: data_emissions.append(p))

# Standalone DI config (no link context)
sensor_cfg_di = {
    "id": 100, "slave_id": 5, "register_address": 20,
    "register_type": "discrete_input", "data_type": "int16",
    "data_format": "AB", "coefficient": "{}", "sensor_type": "DI",
}

mock_resp = MagicMock()
mock_resp.isError.return_value = False
mock_resp.bits = [True]  # DI is ON

mw._client = MagicMock()
mw._client.connected = True
mw._client.read_discrete_inputs.return_value = mock_resp
mw._poll_standalone_di(sensor_cfg_di)
check("Standalone DI ON → status '00' (no di_type context)", 
      len(data_emissions) == 1 and data_emissions[-1]["status"] == "00",
      f"got: {data_emissions[-1] if data_emissions else 'no data'}")

# Alarm logic
alarm_emissions = []
mw2 = ModbusWorker(port="/dev/null", baudrate=9600, poll_interval=3)
mw2.alarm_changed.connect(lambda p: alarm_emissions.append(p))
mw2.data_ready.connect(lambda p: data_emissions.append(p))

sensor_cfg_analog = {
    "id": 42, "slave_id": 1, "register_address": 0,
    "register_type": "holding", "data_type": "int16", "data_format": "AB",
    "coefficient": "{}", "min_threshold": 10.0, "max_threshold": 90.0,
    "sensor_type": "ANALOG",
}

with patch.object(mw2, "_read_register", return_value=95):
    mw2._poll_single(sensor_cfg_analog)
check("ANALOG max alarm emitted", len(alarm_emissions) == 1 and alarm_emissions[-1]["alarm_type"] == "max")

with patch.object(mw2, "_read_register", return_value=50):
    mw2._poll_single(sensor_cfg_analog)
check("ANALOG alarm cleared", len(alarm_emissions) == 2 and alarm_emissions[-1]["is_alarm"] == False)

# ═══════════════════════════════════════════════════════════════
#  7. MonitorModel alarm roles
# ═══════════════════════════════════════════════════════════════
section("7. MonitorModel alarm roles")

from ui.controllers.monitor_controller import MonitorModel
from PySide6.QtCore import Qt

dm = MonitorModel()
session = get_session()
s_test = session.get(Sensor, analog_id)
session.expunge(s_test)
session.close()

dm.load_sensors([s_test])
check("MonitorModel loaded", dm.rowCount() == 1)

idx = dm.index(0, 0)
is_alarm_role = Qt.UserRole + 8
alarm_type_role = Qt.UserRole + 9
status_role = Qt.UserRole + 6

check("Initial isAlarm = False", dm.data(idx, is_alarm_role) == False)
dm.update_value(analog_id, 99.0, 9900, datetime.now().isoformat(), True, "max")
check("After alarm: isAlarm = True", dm.data(idx, is_alarm_role) == True)
check("After alarm: alarmType = 'max'", dm.data(idx, alarm_type_role) == "max")
check("After alarm: status = 'ALARM'", dm.data(idx, status_role) == "ALARM")
dm.update_value(analog_id, 50.0, 5000, datetime.now().isoformat(), False, "")
check("After clear: isAlarm = False", dm.data(idx, is_alarm_role) == False)

# ═══════════════════════════════════════════════════════════════
#  8. MonitorController alarm_changed handler
# ═══════════════════════════════════════════════════════════════
section("8. MonitorController alarm handler")

from ui.controllers.monitor_controller import MonitorController

mc = MonitorController(MonitorModel())
try:
    mc._on_alarm_changed({"sensor_id": 1, "is_alarm": True, "alarm_type": "max"})
    check("_on_alarm_changed alarm ON no crash", True)
except Exception as e:
    check("_on_alarm_changed alarm ON no crash", False, str(e))

try:
    mc._on_alarm_changed({"sensor_id": 1, "is_alarm": False, "alarm_type": ""})
    check("_on_alarm_changed alarm OFF no crash", True)
except Exception as e:
    check("_on_alarm_changed alarm OFF no crash", False, str(e))

# ═══════════════════════════════════════════════════════════════
#  9. MonitorController DI Legend mapping
# ═══════════════════════════════════════════════════════════════
section("9. MonitorController DI Legend mapping")

from ui.controllers.monitor_controller import _DI_TYPE_NAMES

check("_DI_TYPE_NAMES calibrating", _DI_TYPE_NAMES.get("01") == "Calibrating")
check("_DI_TYPE_NAMES error", _DI_TYPE_NAMES.get("02") == "Error")

dummy_sensor = Sensor(id=99, name="Test Sensor Name", sensor_type="DI", active=True)
dummy_link = AnalogDigitalLink(analog_sensor_id=1, digital_sensor_id=99, di_type="01")
mc._build_di_legend([dummy_sensor], [dummy_link])

check("diLegend has Calibrating", any(item["label"] == "Calibrating" for item in mc.diLegend), f"got: {mc.diLegend}")
check("di_label_to_color maps Calibrating", "Calibrating" in mc._di_label_to_color)

# ═══════════════════════════════════════════════════════════════
#  10. Cleanup
# ═══════════════════════════════════════════════════════════════
section("10. Cleanup")

session = get_session()
try:
    for sid in [analog_id, di_sensor_id, do_sensor_id]:
        links = list(session.exec(
            select(AnalogDigitalLink).where(
                (AnalogDigitalLink.analog_sensor_id == sid) |
                (AnalogDigitalLink.digital_sensor_id == sid)
            )
        ).all())
        for l in links:
            session.delete(l)

    # Cleanup test sensors added by SensorListModel
    for name in ["Threshold Sensor", "Test DI Sensor", "Test DO Sensor"]:
        row = session.exec(select(Sensor).where(Sensor.name == name)).first()
        if row:
            ls = list(session.exec(
                select(AnalogDigitalLink).where(
                    (AnalogDigitalLink.analog_sensor_id == row.id) |
                    (AnalogDigitalLink.digital_sensor_id == row.id)
                )
            ).all())
            for l in ls:
                session.delete(l)
            session.delete(row)

    for sid in [analog_id, di_sensor_id, do_sensor_id]:
        row = session.get(Sensor, sid)
        if row:
            session.delete(row)

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
print(f"  M6 RESULTS: {passed}/{total} PASSED, {failed} FAILED")
if failed == 0:
    print("  ALL M6 TESTS PASSED ✓")
else:
    print(f"  ⚠  {failed} test(s) FAILED")
print(f"{'='*60}")

sys.exit(0 if failed == 0 else 1)
