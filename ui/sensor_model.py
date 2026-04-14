"""M2 — SensorListModel: QAbstractListModel cho CRUD Sensor.

Cung cấp model cho QML ListView hiển thị danh sách cảm biến.
Hỗ trợ add / update / remove qua @Slot gọi từ QML.
"""

import json
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

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
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

    @Slot(str, str, int, int, str, str, str, str, int, int, bool)
    def add_sensor(self, name: str, unit: str, slave_id: int,
                   register_address: int, register_type: str,
                   data_type: str, data_format: str, coefficient: str,
                   poll_interval: int, report_index: int, active: bool):
        errors = self._validate_fields(name, unit, slave_id, register_address)
        if errors:
            self.messageSent.emit(
                self.tr("Validation error"),
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
            )
            session.add(sensor)
            session.commit()
            self.refresh()
            self.messageSent.emit(
                self.tr("Success"),
                self.tr("Added sensor '{0}'.").format(name),
            )
            logger.info("Sensor added: %s", name)
        except Exception as e:
            session.rollback()
            logger.error("add_sensor error: %s", e)
            self.messageSent.emit(
                self.tr("Error"),
                self.tr("Failed to add sensor: {0}").format(e),
            )
        finally:
            session.close()

    @Slot(int, str, str, int, int, str, str, str, str, int, int, bool)
    def update_sensor(self, sensor_id: int, name: str, unit: str,
                      slave_id: int, register_address: int,
                      register_type: str, data_type: str,
                      data_format: str, coefficient: str,
                      poll_interval: int, report_index: int, active: bool):
        errors = self._validate_fields(name, unit, slave_id, register_address)
        if errors:
            self.messageSent.emit(
                self.tr("Validation error"),
                "\n".join(errors),
            )
            return

        session = get_session()
        try:
            sensor = session.get(Sensor, sensor_id)
            if not sensor:
                self.messageSent.emit(self.tr("Error"), self.tr("Sensor not found."))
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
            session.commit()
            self.refresh()
            self.messageSent.emit(
                self.tr("Success"),
                self.tr("Updated sensor '{0}'.").format(name),
            )
        except Exception as e:
            session.rollback()
            logger.error("update_sensor error: %s", e)
            self.messageSent.emit(
                self.tr("Error"),
                self.tr("Update failed: {0}").format(e),
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
                self.refresh()
                self.messageSent.emit(
                    self.tr("Success"),
                    self.tr("Removed sensor '{0}'.").format(sensor.name),
                )
            else:
                self.messageSent.emit(
                    self.tr("Error"),
                    self.tr("No sensor found to remove."),
                )
        except Exception as e:
            session.rollback()
            logger.error("remove_sensor error: %s", e)
            self.messageSent.emit(
                self.tr("Error"),
                self.tr("Failed to remove sensor: {0}").format(e),
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
            }
        return {}

    def _validate_fields(self, name, unit, slave_id, register_address) -> list[str]:
        errors: list[str] = []
        if not name.strip():
            errors.append(self.tr("Sensor name cannot be empty."))
        if not unit.strip():
            errors.append(self.tr("Unit cannot be empty."))
        if slave_id < 1 or slave_id > 247:
            errors.append(self.tr("Slave ID must be between 1 and 247."))
        if register_address < 0 or register_address > 65535:
            errors.append(self.tr("Register address must be between 0 and 65535."))
        return errors
