"""M2 — SensorListModel: QAbstractListModel cho CRUD Sensor.

Cung cấp model cho QML ListView hiển thị danh sách cảm biến.
Hỗ trợ add / update / remove qua @Slot gọi từ QML.
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
from models.digital_io import DigitalIO
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
}


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
        field = _FIELD_MAP[role_name]
        return getattr(sensor, field)

    def roleNames(self):
        return {k: QByteArray(v) for k, v in _ROLE_NAMES.items()}

    # ── Slots ──────────────────────────────────────────────────────────────

    @Slot()
    def refresh(self):
        session = get_session()
        try:
            self.beginResetModel()
            self._sensors = list(session.exec(select(Sensor).order_by(Sensor.id)).all())
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
        errors = self._validate_fields(name, unit, slave_id, register_address)
        if errors:
            self.messageSent.emit(
                "Validation error",
                "\n".join(errors),
            )
            return

        session = get_session()
        try:
            sensor = Sensor(
                name=name.strip(), unit=unit.strip(), slave_id=slave_id,
                register_address=register_address, register_type=register_type,
                data_type=data_type, data_format=data_format,
                coefficient=coefficient.strip() or "{}",
                poll_interval=max(1, poll_interval),
                report_index=report_index, active=active,
                min_threshold=self._parse_threshold(min_threshold_str),
                max_threshold=self._parse_threshold(max_threshold_str),
            )
            session.add(sensor)
            session.commit()
            session.refresh(sensor)
            session.expunge(sensor)
            self.beginInsertRows(QModelIndex(), len(self._sensors), len(self._sensors))
            self._sensors.append(sensor)
            self.endInsertRows()
            self.countChanged.emit()
            self.messageSent.emit(
                "Success",
                "Added sensor '{0}'.".format(name),
            )
            logger.info("Sensor added: %s", name)
        except Exception as e:
            session.rollback()
            logger.error("add_sensor error: %s", e)
            self.messageSent.emit(
                "Error",
                "Failed to add sensor: {0}".format(e),
            )
        finally:
            session.close()

    @Slot(int, str, str, int, int, str, str, str, str, int, int, bool, str, str)
    def update_sensor(self, sensor_id: int, name: str, unit: str,
                      slave_id: int, register_address: int,
                      register_type: str, data_type: str,
                      data_format: str, coefficient: str,
                      poll_interval: int, report_index: int, active: bool,
                      min_threshold_str: str, max_threshold_str: str):
        errors = self._validate_fields(name, unit, slave_id, register_address)
        if errors:
            self.messageSent.emit(
                "Validation error",
                "\n".join(errors),
            )
            return

        session = get_session()
        try:
            sensor = session.get(Sensor, sensor_id)
            if not sensor:
                self.messageSent.emit("Error", "Sensor not found.")
                return
            sensor.name = name.strip()
            sensor.unit = unit.strip()
            sensor.slave_id = slave_id
            sensor.register_address = register_address
            sensor.register_type = register_type
            sensor.data_type = data_type
            sensor.data_format = data_format
            sensor.coefficient = coefficient.strip() or "{}"
            sensor.poll_interval = max(1, poll_interval)
            sensor.report_index = report_index
            sensor.active = active
            sensor.min_threshold = self._parse_threshold(min_threshold_str)
            sensor.max_threshold = self._parse_threshold(max_threshold_str)
            session.commit()
            
            session.refresh(sensor)
            session.expunge(sensor)
            for idx, s in enumerate(self._sensors):
                if s.id == sensor_id:
                    self._sensors[idx] = sensor
                    m_idx = self.index(idx, 0)
                    self.dataChanged.emit(m_idx, m_idx, [])
                    break

            self.messageSent.emit(
                "Success",
                "Updated sensor '{0}'.".format(name),
            )
        except Exception as e:
            session.rollback()
            logger.error("update_sensor error: %s", e)
            self.messageSent.emit(
                "Error",
                "Update failed: {0}".format(e),
            )
        finally:
            session.close()

    @Slot(int)
    def remove_sensor(self, sensor_id: int):
        session = get_session()
        try:
            sensor = session.get(Sensor, sensor_id)
            if sensor:
                session.delete(sensor)
                session.commit()
                for idx, s in enumerate(self._sensors):
                    if s.id == sensor_id:
                        self.beginRemoveRows(QModelIndex(), idx, idx)
                        self._sensors.pop(idx)
                        self.endRemoveRows()
                        self.countChanged.emit()
                        break
                self.messageSent.emit(
                    "Success",
                    "Removed sensor '{0}'.".format(sensor.name),
                )
            else:
                self.messageSent.emit(
                    "Error",
                    "No sensor found to remove.",
                )
        except Exception as e:
            session.rollback()
            logger.error("remove_sensor error: %s", e)
            self.messageSent.emit(
                "Error",
                "Failed to remove sensor: {0}".format(e),
            )
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
            }
        return {}

    def _validate_fields(self, name, unit, slave_id, register_address) -> list[str]:
        errors: list[str] = []
        if not name.strip():
            errors.append("Sensor name cannot be empty.")
        if not unit.strip():
            errors.append("Unit cannot be empty.")
        if slave_id < 1 or slave_id > 247:
            errors.append("Slave ID must be between 1 and 247.")
        if register_address < 0 or register_address > 65535:
            errors.append("Register address must be between 0 and 65535.")
        return errors

    @staticmethod
    def _parse_threshold(s: str) -> float | None:
        """Parse threshold string from QML. Empty string = None (disabled)."""
        t = (s or "").strip().replace(",", ".")
        if not t:
            return None
        try:
            return float(t)
        except ValueError:
            return None

    # ── Digital I/O CRUD ───────────────────────────────────────────────────

    @Slot(int, result="QVariant")
    def get_digital_ios(self, sensor_id: int):
        """Return list of DI/DO dicts for a sensor."""
        session = get_session()
        try:
            ios = list(session.exec(
                select(DigitalIO)
                .where(DigitalIO.sensor_id == sensor_id)
                .order_by(DigitalIO.id)
            ).all())
            return [
                {
                    "id": io.id,
                    "ioType": io.io_type,
                    "label": io.label,
                    "diType": io.di_type or "",
                    "slaveId": io.slave_id,
                    "address": io.address,
                    "triggerOnMax": io.trigger_on_max,
                    "triggerOnMin": io.trigger_on_min,
                    "active": io.active,
                }
                for io in ios
            ]
        except Exception as e:
            logger.error("get_digital_ios error: %s", e)
            return []
        finally:
            session.close()

    @Slot(int, str, str, str, int, int, bool, bool, bool)
    def add_digital_io(self, sensor_id: int, io_type: str, label: str, di_type: str,
                       slave_id: int, address: int,
                       trigger_on_max: bool, trigger_on_min: bool,
                       active: bool):
        """Add a new DI/DO channel to a sensor."""
        session = get_session()
        try:
            # Check limit: max 5 DI and 5 DO per sensor
            existing = list(session.exec(
                select(DigitalIO)
                .where(DigitalIO.sensor_id == sensor_id)
                .where(DigitalIO.io_type == io_type)
            ).all())
            if len(existing) >= 5:
                self.messageSent.emit(
                    "Error",
                    f"Maximum 5 {io_type} channels per sensor.",
                )
                return

            dio = DigitalIO(
                sensor_id=sensor_id,
                io_type=io_type,
                label=label.strip() or f"{io_type} {len(existing) + 1}",
                di_type=di_type.strip() if di_type and io_type == "DI" else None,
                slave_id=slave_id,
                address=address,
                trigger_on_max=trigger_on_max,
                trigger_on_min=trigger_on_min,
                active=active,
            )
            session.add(dio)
            session.commit()
            self.messageSent.emit(
                "Success",
                f"Added {io_type} '{dio.label}'.",
            )
            logger.info("DigitalIO added: %s for sensor %d", dio.label, sensor_id)
        except Exception as e:
            session.rollback()
            logger.error("add_digital_io error: %s", e)
            self.messageSent.emit("Error", f"Failed to add {io_type}: {e}")
        finally:
            session.close()

    @Slot(int)
    def remove_digital_io(self, dio_id: int):
        """Remove a DI/DO channel by its ID."""
        session = get_session()
        try:
            dio = session.get(DigitalIO, dio_id)
            if dio:
                session.delete(dio)
                session.commit()
                self.messageSent.emit(
                    "Success",
                    f"Removed {dio.io_type} '{dio.label}'.",
                )
            else:
                self.messageSent.emit("Error", "Digital I/O not found.")
        except Exception as e:
            session.rollback()
            logger.error("remove_digital_io error: %s", e)
            self.messageSent.emit("Error", f"Failed to remove: {e}")
        finally:
            session.close()
