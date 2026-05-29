"""M2 — SensorListModel: QAbstractListModel cho CRUD Sensor.

Cung cấp model cho QML ListView hiển thị danh sách cảm biến.
Hỗ trợ add / update / remove qua @Slot gọi từ QML.
DI/DO gắn analog được quản lý qua AnalogDigitalLink (attach / detach).
"""

import logging
from typing import Any

from PySide6.QtCore import (
    QAbstractListModel,
    QByteArray,
    QModelIndex,
    Qt,
    Signal,
    Slot,
)
from sqlmodel import select

from core.database import get_session
from core.sensor_kind import (
    validate_attach_di,
    validate_attach_do,
    validate_digital_address_unique,
)
from models.analog_digital_link import AnalogDigitalLink
from models.sensor import Sensor

logger = logging.getLogger(__name__)

_ROLE_NAMES = {
    Qt.UserRole + 1: b"sensorId",
    Qt.UserRole + 2: b"name",
    Qt.UserRole + 3: b"unit",
    Qt.UserRole + 4: b"slaveId",
    Qt.UserRole + 5: b"registerAddress",
    Qt.UserRole + 6: b"registerType",
    Qt.UserRole + 7: b"dataType",
    Qt.UserRole + 8: b"dataFormat",
    Qt.UserRole + 9: b"coefficient",
    Qt.UserRole + 10: b"reportIndex",
    Qt.UserRole + 11: b"active",
    Qt.UserRole + 12: b"pollInterval",
    Qt.UserRole + 13: b"minThreshold",
    Qt.UserRole + 14: b"maxThreshold",
    Qt.UserRole + 15: b"sensorType",
}

_FIELD_MAP = {
    b"sensorId": "id",
    b"name": "name",
    b"unit": "unit",
    b"slaveId": "slave_id",
    b"registerAddress": "register_address",
    b"registerType": "register_type",
    b"dataType": "data_type",
    b"dataFormat": "data_format",
    b"coefficient": "coefficient",
    b"reportIndex": "report_index",
    b"active": "active",
    b"pollInterval": "poll_interval",
    b"minThreshold": "min_threshold",
    b"maxThreshold": "max_threshold",
    b"sensorType": "sensor_type",
}


def _sensor_type_from_register(register_type: str) -> str:
    """Infer ANALOG / DI / DO from Modbus register type (QML combo text or DB value)."""
    rt = (register_type or "").strip().lower()
    if rt in ("discrete_input", "discrete inputs", "discrete input"):
        return "DI"
    if rt in ("coil", "coils"):
        return "DO"
    return "ANALOG"


def _normalize_register_type(sensor_type: str, register_type: str) -> str:
    if sensor_type == "DI":
        return "discrete_input"
    if sensor_type == "DO":
        return "coil"
    return register_type


class SensorListModel(QAbstractListModel):
    messageSent = Signal(str, str)
    countChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._sensors: list[Sensor] = []

    # ── QAbstractListModel overrides ───────────────────────────────────────

    def rowCount(self, parent=QModelIndex()):
        return len(self._sensors)

    def data(self, index: QModelIndex, role: int = Qt.ItemDataRole.DisplayRole) -> Any:
        if not index.isValid() or index.row() >= len(self._sensors):
            return None
        sensor = self._sensors[index.row()]
        role_name = _ROLE_NAMES.get(role)
        if role_name is None:
            return None
        field = _FIELD_MAP.get(role_name)
        if field is None:
            return None
        val = getattr(sensor, field)
        return val.value if hasattr(val, "value") else val

    def roleNames(self):
        return {k: QByteArray(v) for k, v in _ROLE_NAMES.items()}

    # ── Slots ──────────────────────────────────────────────────────────────

    @Slot()
    def refresh(self):
        session = get_session()
        try:
            self.beginResetModel()
            self._sensors = list(session.exec(
                select(Sensor).order_by(Sensor.id)
            ).all())
            session.expunge_all()
            self.endResetModel()
            self.countChanged.emit()
            logger.info("SensorListModel refreshed: %d sensors", len(self._sensors))
        except Exception as e:
            logger.error("refresh error: %s", e)
        finally:
            session.close()

    @Slot(str, str, int, int, str, str, str, str, int, int, bool, str, str)
    def add_sensor(self, name: str, unit: str, slave_id: int,
                   register_address: int, register_type: str,
                   data_type: str, data_format: str, coefficient: str,
                   poll_interval: int, report_index: int, active: bool,
                   min_threshold_str: str, max_threshold_str: str):
        errors = self._validate_fields(name, slave_id, register_address)
        if errors:
            self.messageSent.emit("Validation error", "\n".join(errors))
            return

        resolved_type = _sensor_type_from_register(register_type)
        register_type = _normalize_register_type(resolved_type, register_type)

        session = get_session()
        try:
            addr_err = validate_digital_address_unique(
                session, resolved_type, slave_id, register_address
            )
            if addr_err:
                self.messageSent.emit("Validation error", addr_err)
                return

            sensor = Sensor(
                sensor_type=resolved_type,
                name=name.strip(), unit=unit.strip() if resolved_type == "ANALOG" else "",
                slave_id=slave_id,
                register_address=register_address, register_type=register_type,
                data_type=data_type if resolved_type == "ANALOG" else "int16",
                data_format=data_format if resolved_type == "ANALOG" else "AB",
                coefficient=coefficient.strip() or "{}",
                poll_interval=max(1, poll_interval),
                report_index=report_index if resolved_type == "ANALOG" else 0,
                active=active,
                min_threshold=self._parse_threshold(min_threshold_str) if resolved_type == "ANALOG" else None,
                max_threshold=self._parse_threshold(max_threshold_str) if resolved_type == "ANALOG" else None,
            )
            session.add(sensor)
            session.commit()
            session.refresh(sensor)
            session.expunge(sensor)
            self.beginInsertRows(QModelIndex(), len(self._sensors), len(self._sensors))
            self._sensors.append(sensor)
            self.endInsertRows()
            self.countChanged.emit()
            self.messageSent.emit("Success", f"Added sensor '{name}'.")
            logger.info("Sensor added: %s (type=%s)", name, resolved_type)
        except Exception as e:
            session.rollback()
            logger.error("add_sensor error: %s", e)
            self.messageSent.emit("Error", f"Failed to add sensor: {e}")
        finally:
            session.close()

    @Slot(int, str, str, int, int, str, str, str, str, int, int, bool, str, str)
    def update_sensor(self, sensor_id: int, name: str, unit: str,
                      slave_id: int, register_address: int,
                      register_type: str, data_type: str,
                      data_format: str, coefficient: str,
                      poll_interval: int, report_index: int, active: bool,
                      min_threshold_str: str, max_threshold_str: str):
        errors = self._validate_fields(name, slave_id, register_address)
        if errors:
            self.messageSent.emit("Validation error", "\n".join(errors))
            return

        resolved_type = _sensor_type_from_register(register_type)
        register_type = _normalize_register_type(resolved_type, register_type)

        session = get_session()
        try:
            addr_err = validate_digital_address_unique(
                session, resolved_type, slave_id, register_address, exclude_id=sensor_id
            )
            if addr_err:
                self.messageSent.emit("Validation error", addr_err)
                return

            sensor = session.get(Sensor, sensor_id)
            if not sensor:
                self.messageSent.emit("Error", "Sensor not found.")
                return
            sensor.sensor_type = resolved_type
            sensor.name = name.strip()
            sensor.unit = unit.strip() if resolved_type == "ANALOG" else ""
            sensor.slave_id = slave_id
            sensor.register_address = register_address
            sensor.register_type = register_type
            sensor.data_type = data_type if resolved_type == "ANALOG" else "int16"
            sensor.data_format = data_format if resolved_type == "ANALOG" else "AB"
            sensor.coefficient = coefficient.strip() or "{}"
            sensor.poll_interval = max(1, poll_interval)
            sensor.report_index = report_index if resolved_type == "ANALOG" else 0
            sensor.active = active
            sensor.min_threshold = self._parse_threshold(min_threshold_str) if resolved_type == "ANALOG" else None
            sensor.max_threshold = self._parse_threshold(max_threshold_str) if resolved_type == "ANALOG" else None
            session.commit()

            session.refresh(sensor)
            session.expunge(sensor)
            for idx, s in enumerate(self._sensors):
                if s.id == sensor_id:
                    self._sensors[idx] = sensor
                    m_idx = self.index(idx, 0)
                    self.dataChanged.emit(m_idx, m_idx, [])
                    break

            self.messageSent.emit("Success", f"Updated sensor '{name}'.")
        except Exception as e:
            session.rollback()
            logger.error("update_sensor error: %s", e)
            self.messageSent.emit("Error", f"Update failed: {e}")
        finally:
            session.close()

    @Slot(int)
    def remove_sensor(self, sensor_id: int):
        session = get_session()
        try:
            sensor = session.get(Sensor, sensor_id)
            if sensor:
                # Remove all links involving this sensor
                links = list(session.exec(
                    select(AnalogDigitalLink).where(
                        (AnalogDigitalLink.analog_sensor_id == sensor_id) |
                        (AnalogDigitalLink.digital_sensor_id == sensor_id)
                    )
                ).all())
                for link in links:
                    session.delete(link)

                session.delete(sensor)
                session.commit()
                for idx, s in enumerate(self._sensors):
                    if s.id == sensor_id:
                        self.beginRemoveRows(QModelIndex(), idx, idx)
                        self._sensors.pop(idx)
                        self.endRemoveRows()
                        self.countChanged.emit()
                        break
                self.messageSent.emit("Success", f"Removed sensor '{sensor.name}'.")
            else:
                self.messageSent.emit("Error", "No sensor found to remove.")
        except Exception as e:
            session.rollback()
            logger.error("remove_sensor error: %s", e)
            self.messageSent.emit("Error", f"Failed to remove sensor: {e}")
        finally:
            session.close()

    @Slot(int, result="QVariant")
    def get_sensor(self, index: int):
        if 0 <= index < len(self._sensors):
            s = self._sensors[index]
            return {
                "sensorId": s.id, "name": s.name, "unit": s.unit,
                "slaveId": s.slave_id, "registerAddress": s.register_address,
                "registerType": s.register_type, "dataType": s.data_type,
                "dataFormat": s.data_format, "coefficient": s.coefficient or "{}",
                "pollInterval": s.poll_interval,
                "reportIndex": s.report_index, "active": s.active,
                "minThreshold": s.min_threshold if s.min_threshold is not None else "",
                "maxThreshold": s.max_threshold if s.max_threshold is not None else "",
                "sensorType": s.sensor_type.value if hasattr(s.sensor_type, "value") else s.sensor_type,
            }
        return {}

    def _validate_fields(self, name: str, slave_id: int, register_address: int) -> list[str]:
        errors: list[str] = []
        if not name.strip():
            errors.append("Sensor name cannot be empty.")
        if slave_id < 1 or slave_id > 247:
            errors.append("Slave ID must be between 1 and 247.")
        if register_address < 0 or register_address > 65535:
            errors.append("Register address must be between 0 and 65535.")
        return errors

    @staticmethod
    def _parse_threshold(s: str) -> float | None:
        t = (s or "").strip().replace(",", ".")
        if not t:
            return None
        try:
            return float(t)
        except ValueError:
            return None

    # ── Digital I/O Link API ───────────────────────────────────────────────

    @Slot(result="QVariant")
    def list_di_sensors(self):
        """Return all active DI sensors (for attach dropdown)."""
        session = get_session()
        try:
            sensors = list(session.exec(
                select(Sensor)
                .where(Sensor.sensor_type == "DI")
                .where(Sensor.active)
                .order_by(Sensor.name)
            ).all())
            return [
                {
                    "id": s.id,
                    "name": s.name,
                    "slaveId": s.slave_id,
                    "address": s.register_address,
                }
                for s in sensors
            ]
        except Exception as e:
            logger.error("list_di_sensors error: %s", e)
            return []
        finally:
            session.close()

    @Slot(int, result="QVariant")
    def list_do_sensors(self, analog_id: int):
        """Return DO sensors that are either unlinked or already linked to analog_id."""
        session = get_session()
        try:
            all_do = list(session.exec(
                select(Sensor)
                .where(Sensor.sensor_type == "DO")
                .where(Sensor.active)
                .order_by(Sensor.name)
            ).all())

            # Find DO sensor IDs already linked to other analogs
            linked_to_other: set[int] = set()
            if all_do:
                do_ids = [s.id for s in all_do]
                all_links = list(session.exec(
                    select(AnalogDigitalLink)
                    .where(AnalogDigitalLink.digital_sensor_id.in_(do_ids))
                ).all())
                for link in all_links:
                    if link.analog_sensor_id != analog_id:
                        linked_to_other.add(link.digital_sensor_id)

            return [
                {
                    "id": s.id,
                    "name": s.name,
                    "slaveId": s.slave_id,
                    "address": s.register_address,
                }
                for s in all_do
                if s.id not in linked_to_other
            ]
        except Exception as e:
            logger.error("list_do_sensors error: %s", e)
            return []
        finally:
            session.close()

    @Slot(int, result="QVariant")
    def get_analog_links(self, analog_id: int):
        """Return link dicts for a given analog sensor."""
        session = get_session()
        try:
            links = list(session.exec(
                select(AnalogDigitalLink)
                .where(AnalogDigitalLink.analog_sensor_id == analog_id)
                .order_by(AnalogDigitalLink.id)
            ).all())
            result = []
            for link in links:
                ds = session.get(Sensor, link.digital_sensor_id)
                if not ds:
                    continue
                st = ds.sensor_type.value if hasattr(ds.sensor_type, "value") else ds.sensor_type
                result.append({
                    "id": link.id,
                    "ioType": st,
                    "label": ds.name,
                    "diType": link.di_type or "",
                    "slaveId": ds.slave_id,
                    "address": ds.register_address,
                    "triggerOnMax": link.trigger_on_max,
                    "triggerOnMin": link.trigger_on_min,
                    "active": ds.active,
                })
            return result
        except Exception as e:
            logger.error("get_analog_links error: %s", e)
            return []
        finally:
            session.close()

    @Slot(int, int, str)
    def attach_di(self, analog_id: int, di_sensor_id: int, di_type: str):
        """Create a link between an ANALOG and a DI sensor."""
        session = get_session()
        try:
            err = validate_attach_di(session, analog_id, di_sensor_id)
            if err:
                self.messageSent.emit("Error", err)
                return

            link = AnalogDigitalLink(
                analog_sensor_id=analog_id,
                digital_sensor_id=di_sensor_id,
                di_type=di_type.strip() or None,
            )
            session.add(link)
            session.commit()
            di = session.get(Sensor, di_sensor_id)
            self.messageSent.emit("Success", f"Attached DI '{di.name if di else di_sensor_id}'.")
            logger.info("DI attached: analog=%d di=%d di_type=%s", analog_id, di_sensor_id, di_type)
        except Exception as e:
            session.rollback()
            logger.error("attach_di error: %s", e)
            self.messageSent.emit("Error", f"Failed to attach DI: {e}")
        finally:
            session.close()

    @Slot(int, int, bool, bool)
    def attach_do(self, analog_id: int, do_sensor_id: int,
                  trigger_on_max: bool, trigger_on_min: bool):
        """Create a link between an ANALOG and a DO sensor."""
        session = get_session()
        try:
            err = validate_attach_do(session, analog_id, do_sensor_id)
            if err:
                self.messageSent.emit("Error", err)
                return

            link = AnalogDigitalLink(
                analog_sensor_id=analog_id,
                digital_sensor_id=do_sensor_id,
                trigger_on_max=trigger_on_max,
                trigger_on_min=trigger_on_min,
            )
            session.add(link)
            session.commit()
            do = session.get(Sensor, do_sensor_id)
            self.messageSent.emit("Success", f"Attached DO '{do.name if do else do_sensor_id}'.")
            logger.info("DO attached: analog=%d do=%d", analog_id, do_sensor_id)
        except Exception as e:
            session.rollback()
            logger.error("attach_do error: %s", e)
            self.messageSent.emit("Error", f"Failed to attach DO: {e}")
        finally:
            session.close()

    @Slot(int)
    def detach_link(self, link_id: int):
        """Remove an AnalogDigitalLink by its id."""
        session = get_session()
        try:
            link = session.get(AnalogDigitalLink, link_id)
            if link:
                ds = session.get(Sensor, link.digital_sensor_id)
                name = ds.name if ds else str(link.digital_sensor_id)
                session.delete(link)
                session.commit()
                self.messageSent.emit("Success", f"Detached '{name}'.")
                logger.info("Link detached: link_id=%d", link_id)
            else:
                self.messageSent.emit("Error", "Link not found.")
        except Exception as e:
            session.rollback()
            logger.error("detach_link error: %s", e)
            self.messageSent.emit("Error", f"Failed to detach: {e}")
        finally:
            session.close()

    @Slot(int, str)
    def update_link_di_type(self, link_id: int, di_type: str):
        """Update the di_type on an existing DI link."""
        session = get_session()
        try:
            link = session.get(AnalogDigitalLink, link_id)
            if not link:
                self.messageSent.emit("Error", "Link not found.")
                return
            link.di_type = di_type.strip() or None
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error("update_link_di_type error: %s", e)
            self.messageSent.emit("Error", f"Failed to update: {e}")
        finally:
            session.close()

    @Slot(int, bool, bool)
    def update_link_do_triggers(self, link_id: int, trigger_on_max: bool, trigger_on_min: bool):
        """Update trigger conditions on an existing DO link."""
        session = get_session()
        try:
            link = session.get(AnalogDigitalLink, link_id)
            if not link:
                self.messageSent.emit("Error", "Link not found.")
                return
            link.trigger_on_max = trigger_on_max
            link.trigger_on_min = trigger_on_min
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error("update_link_do_triggers error: %s", e)
            self.messageSent.emit("Error", f"Failed to update: {e}")
        finally:
            session.close()
