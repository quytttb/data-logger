"""Sensor domain helpers — predicates and invariant validators.

Single source of truth for sensor type checks and business rules.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from sqlmodel import Session


# ── Predicates ────────────────────────────────────────────────────────────

def _stype(s) -> str:
    """Return the string value of sensor_type regardless of enum vs str."""
    v = s.sensor_type if isinstance(s, dict) else getattr(s, "sensor_type", "ANALOG")
    return v.value if hasattr(v, "value") else str(v)


def is_analog(s) -> bool:
    return _stype(s) == "ANALOG"


def is_di(s) -> bool:
    return _stype(s) == "DI"


def is_do(s) -> bool:
    return _stype(s) == "DO"


def is_digital(s) -> bool:
    return _stype(s) in ("DI", "DO")


# ── Validators ────────────────────────────────────────────────────────────

def validate_digital_address_unique(
    session: "Session",
    sensor_type: str,
    slave_id: int,
    register_address: int,
    exclude_id: int | None = None,
) -> str | None:
    """Return an error message if (slave_id, register_address) is already used by another
    sensor of the same type (DI or DO), else None.

    Checks across ALL sensors of that type to prevent Modbus TCP bit collision.
    """
    if sensor_type not in ("DI", "DO"):
        return None

    from sqlmodel import select
    from models.sensor import Sensor

    stmt = (
        select(Sensor)
        .where(Sensor.sensor_type == sensor_type)
        .where(Sensor.slave_id == slave_id)
        .where(Sensor.register_address == register_address)
        .where(Sensor.active)
    )
    if exclude_id is not None:
        stmt = stmt.where(Sensor.id != exclude_id)

    conflict = session.exec(stmt).first()
    if conflict:
        return (
            f"{sensor_type} slave {slave_id} address {register_address} "
            f"already used by '{conflict.name}' (id={conflict.id})"
        )
    return None


def validate_attach_di(
    session: "Session",
    analog_id: int,
    di_sensor_id: int,
) -> str | None:
    """Validate that a DI can be attached to this analog. Returns error message or None."""
    from sqlmodel import select, func
    from models.sensor import Sensor
    from models.analog_digital_link import AnalogDigitalLink

    analog = session.get(Sensor, analog_id)
    if not analog or _stype(analog) != "ANALOG":
        return f"Sensor id={analog_id} is not an ANALOG sensor"

    di = session.get(Sensor, di_sensor_id)
    if not di or _stype(di) != "DI":
        return f"Sensor id={di_sensor_id} is not a DI sensor"

    # Duplicate link check
    dup = session.exec(
        select(AnalogDigitalLink)
        .where(AnalogDigitalLink.analog_sensor_id == analog_id)
        .where(AnalogDigitalLink.digital_sensor_id == di_sensor_id)
    ).first()
    if dup:
        return f"DI '{di.name}' is already attached to this analog sensor"

    # Max 5 DI per analog
    count = session.exec(
        select(func.count(AnalogDigitalLink.id))
        .where(AnalogDigitalLink.analog_sensor_id == analog_id)
        .join(Sensor, AnalogDigitalLink.digital_sensor_id == Sensor.id)
        .where(Sensor.sensor_type == "DI")
    ).one()
    if count >= 5:
        return "Maximum 5 DI channels per analog sensor"

    return None


def validate_attach_do(
    session: "Session",
    analog_id: int,
    do_sensor_id: int,
) -> str | None:
    """Validate that a DO can be attached to this analog. Returns error message or None."""
    from sqlmodel import select, func
    from models.sensor import Sensor
    from models.analog_digital_link import AnalogDigitalLink

    analog = session.get(Sensor, analog_id)
    if not analog or _stype(analog) != "ANALOG":
        return f"Sensor id={analog_id} is not an ANALOG sensor"

    do = session.get(Sensor, do_sensor_id)
    if not do or _stype(do) != "DO":
        return f"Sensor id={do_sensor_id} is not a DO sensor"

    # DO can only attach to ONE analog (globally unique)
    existing_link = session.exec(
        select(AnalogDigitalLink)
        .where(AnalogDigitalLink.digital_sensor_id == do_sensor_id)
    ).first()
    if existing_link and existing_link.analog_sensor_id != analog_id:
        owner = session.get(Sensor, existing_link.analog_sensor_id)
        owner_name = owner.name if owner else f"id={existing_link.analog_sensor_id}"
        return f"DO '{do.name}' is already attached to analog '{owner_name}'"

    # Duplicate link check (DO re-attached to same analog is idempotent, handled upstream)
    dup = session.exec(
        select(AnalogDigitalLink)
        .where(AnalogDigitalLink.analog_sensor_id == analog_id)
        .where(AnalogDigitalLink.digital_sensor_id == do_sensor_id)
    ).first()
    if dup:
        return f"DO '{do.name}' is already attached to this analog sensor"

    # Max 5 DO per analog
    count = session.exec(
        select(func.count(AnalogDigitalLink.id))
        .where(AnalogDigitalLink.analog_sensor_id == analog_id)
        .join(Sensor, AnalogDigitalLink.digital_sensor_id == Sensor.id)
        .where(Sensor.sensor_type == "DO")
    ).one()
    if count >= 5:
        return "Maximum 5 DO channels per analog sensor"

    return None
