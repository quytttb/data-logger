"""Test M0 — Foundation: DB, Models, Crypto, Formula."""

import json
import sys
from pathlib import Path

# Thêm app vào sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.database import init_db, get_session, engine
from core.crypto import encrypt, decrypt
from core.formula import apply_formula
from models.sensor import Sensor
from models.sensor_data import SensorData
from models.app_config import AppConfig
from models.report_log import ReportLog

from sqlalchemy import inspect, text


def test_m0_1_pragma():
    """M0.1 — PRAGMA WAL, synchronous, temp_store, cache_size."""
    print("=== M0.1: PRAGMA ===")
    init_db()

    session = get_session()
    result = session.execute(text("PRAGMA journal_mode;")).scalar()
    assert result == "wal", f"Expected WAL, got {result}"
    print(f"  journal_mode = {result} ✓")

    result = session.execute(text("PRAGMA synchronous;")).scalar()
    assert result == 1, f"Expected NORMAL(1), got {result}"
    print(f"  synchronous = {result} (NORMAL) ✓")

    result = session.execute(text("PRAGMA temp_store;")).scalar()
    assert result == 2, f"Expected MEMORY(2), got {result}"
    print(f"  temp_store = {result} (MEMORY) ✓")

    result = session.execute(text("PRAGMA cache_size;")).scalar()
    assert result == -8000, f"Expected -8000, got {result}"
    print(f"  cache_size = {result} ✓")

    session.close()
    print("  M0.1 PASSED ✓\n")


def test_m0_2_models():
    """M0.2 — 4 bảng SQLModel tạo đúng, INSERT/SELECT hoạt động."""
    print("=== M0.2: Models ===")
    init_db()

    inspector = inspect(engine)
    tables = inspector.get_table_names()
    expected = {"sensor", "sensor_data", "app_config", "report_log", "digital_io"}
    assert expected.issubset(set(tables)), f"Missing tables: {expected - set(tables)}"
    print(f"  Tables: {tables} ✓")

    session = get_session()
    try:
        # Test Sensor INSERT/SELECT
        sensor = Sensor(
            name="Test Sensor", unit="mg/L",
            slave_id=1, register_address=0,
            register_type="holding", data_type="int16",
            data_format="AB", report_index=1, active=True,
        )
        session.add(sensor)
        session.commit()
        session.refresh(sensor)
        assert sensor.id is not None
        print(f"  Sensor INSERT id={sensor.id} ✓")

        # Test SensorData INSERT/SELECT
        from datetime import datetime
        sd = SensorData(
            sensor_id=sensor.id, raw_value=1234, value=12.34,
            recorded_at=datetime.now(),
        )
        session.add(sd)
        session.commit()
        session.refresh(sd)
        assert sd.id is not None
        print(f"  SensorData INSERT id={sd.id} ✓")

        # Test AppConfig INSERT/SELECT
        config = AppConfig(
            station_code="TEST001", station_name="Trạm Test",
            ftp_address="ftp.example.com", ftp_port=22,
            poll_interval=3,
        )
        session.add(config)
        session.commit()
        session.refresh(config)
        assert config.id is not None
        print(f"  AppConfig INSERT id={config.id} ✓")

        # Test ReportLog INSERT/SELECT
        log = ReportLog(filename="2026-04-07_16-30.txt", status="pending")
        session.add(log)
        session.commit()
        session.refresh(log)
        assert log.id is not None
        print(f"  ReportLog INSERT id={log.id} ✓")

        # Cleanup test data
        session.delete(sd)
        session.delete(sensor)
        session.delete(config)
        session.delete(log)
        session.commit()
        print("  Cleanup ✓")
    finally:
        session.close()

    print("  M0.2 PASSED ✓\n")


def test_m0_3_crypto():
    """M0.3 — Encrypt/Decrypt Fernet."""
    print("=== M0.3: Crypto ===")
    plaintext = "MySecretFTPPassword!@#123"
    token = encrypt(plaintext)
    assert token != plaintext, "Token should differ from plaintext"
    print(f"  Encrypted: {token[:40]}... ✓")

    decrypted = decrypt(token)
    assert decrypted == plaintext, f"Expected '{plaintext}', got '{decrypted}'"
    print(f"  Decrypted matches original ✓")

    # Test empty string
    token2 = encrypt("")
    assert decrypt(token2) == ""
    print("  Empty string encrypt/decrypt ✓")

    print("  M0.3 PASSED ✓\n")


def test_m0_4_formula():
    """M0.4 — Formula linear & polynomial."""
    print("=== M0.4: Formula ===")

    # Linear: y = 0.1 * 100 + (-5) = 5.0
    result = apply_formula(100, json.dumps({"a": 0.1, "b": -5}))
    assert abs(result - 5.0) < 1e-9, f"Expected 5.0, got {result}"
    print(f"  Linear: 0.1*100 + (-5) = {result} ✓")

    # Polynomial: y = 0 + 0.1*100 + 0.001*100^2 = 0 + 10 + 10 = 20
    result = apply_formula(100, json.dumps({"coeffs": [0, 0.1, 0.001]}))
    assert abs(result - 20.0) < 1e-9, f"Expected 20.0, got {result}"
    print(f"  Polynomial: [0, 0.1, 0.001] @ 100 = {result} ✓")

    # Empty/null → raw value
    result = apply_formula(42, "{}")
    assert result == 42.0
    print(f"  Empty coeff → raw = {result} ✓")

    result = apply_formula(42, "")
    assert result == 42.0
    print(f"  Blank string → raw = {result} ✓")

    # Invalid JSON → raw value
    result = apply_formula(42, "not-json")
    assert result == 42.0
    print(f"  Invalid JSON → raw = {result} ✓")

    print("  M0.4 PASSED ✓\n")


if __name__ == "__main__":
    print("=" * 60)
    print("M0 Foundation Tests")
    print("=" * 60 + "\n")

    test_m0_1_pragma()
    test_m0_2_models()
    test_m0_3_crypto()
    test_m0_4_formula()

    print("=" * 60)
    print("ALL M0 TESTS PASSED ✓")
    print("=" * 60)
