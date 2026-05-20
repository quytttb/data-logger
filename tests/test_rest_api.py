"""Smoke tests cho REST API v1 (FastAPI TestClient, DB SQLite tạm thời).

Chạy độc lập — không cần Qt/Modbus. Sử dụng tempdir cho `DATALOGGER_DATA_DIR`
để tránh đụng vào datalogger.db production.
"""

from __future__ import annotations

import os
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

_TMP = Path(tempfile.mkdtemp(prefix="datalogger-rest-test-"))
os.environ["DATALOGGER_DATA_DIR"] = str(_TMP)

from fastapi.testclient import TestClient  # noqa: E402

from core.database import init_db  # noqa: E402
from core.rest_api import create_app  # noqa: E402

TOKEN = "test-bearer-token-xyz"
HDR = {"Authorization": f"Bearer {TOKEN}"}


def _sample_readings() -> dict:
    return {
        "ok": True,
        "polling": True,
        "rtu_connected": True,
        "sensors": [
            {
                "sensor_id": 1,
                "sensor_type": "ANALOG",
                "value": 25.5,
                "status": "OK",
                "is_alarm": False,
                "alarm_type": "",
                "valid": True,
                "recorded_at": "2026-05-19T10:00:00",
            },
            {
                "sensor_id": 3,
                "sensor_type": "DI",
                "value": 1.0,
                "status": "ON",
                "is_alarm": False,
                "alarm_type": "",
                "valid": True,
                "recorded_at": "2026-05-19T10:00:00",
            },
        ],
    }


def _client(readings_provider=None) -> TestClient:
    init_db()
    return TestClient(
        create_app(
            token_provider=lambda: TOKEN,
            readings_provider=readings_provider,
        )
    )


def test_health_no_auth():
    c = _client()
    r = c.get("/api/v1/health")
    assert r.status_code == 200
    body = r.json()
    assert body["ok"] is True
    assert body["api_version"] == 1
    assert isinstance(body["revision"], int)
    print("  GET /health OK ✓")


def test_get_config_requires_auth():
    c = _client()
    r = c.get("/api/v1/config")
    assert r.status_code == 401
    r = c.get("/api/v1/config", headers=HDR)
    assert r.status_code == 200
    snap = r.json()
    assert snap["api_version"] == 1
    assert "config" in snap and "sensors" in snap
    print("  GET /config auth + snapshot OK ✓")


def test_post_config_revision_conflict():
    c = _client()
    cur = c.get("/api/v1/health").json()["revision"]
    body = {
        "api_version": 1,
        "request_id": str(uuid.uuid4()),
        "expected_revision": cur + 99,
        "config": {"poll_interval": 5},
    }
    r = c.post("/api/v1/config", headers=HDR, json=body)
    assert r.status_code == 409
    assert r.json()["ok"] is False
    print("  POST /config 409 conflict OK ✓")


def test_post_config_apply_increments_revision():
    c = _client()
    cur = c.get("/api/v1/health").json()["revision"]
    body = {
        "api_version": 1,
        "request_id": str(uuid.uuid4()),
        "expected_revision": cur,
        "config": {
            "poll_interval": 7,
            "modbus_tcp_enabled": True,
            "modbus_tcp_port": 5021,
        },
    }
    r = c.post("/api/v1/config", headers=HDR, json=body)
    assert r.status_code == 200, r.text
    resp = r.json()
    assert resp["ok"] is True
    assert resp["applied_revision"] == cur + 1
    after = c.get("/api/v1/config", headers=HDR).json()
    assert after["revision"] == cur + 1
    assert after["config"]["poll_interval"] == 7
    assert after["config"]["modbus_tcp_port"] == 5021
    print("  POST /config apply + revision bump OK ✓")


def test_post_config_validation_400():
    c = _client()
    cur = c.get("/api/v1/health").json()["revision"]
    body = {
        "api_version": 1,
        "request_id": str(uuid.uuid4()),
        "expected_revision": cur,
        "config": {"modbus_tcp_bind": "   "},  # blank → business validation
    }
    r = c.post("/api/v1/config", headers=HDR, json=body)
    assert r.status_code == 400
    assert any("modbus_tcp_bind" in e["field"] for e in r.json()["errors"])
    print("  POST /config 400 validation OK ✓")


def test_post_config_sensors_replace():
    c = _client()
    cur = c.get("/api/v1/health").json()["revision"]
    body = {
        "api_version": 1,
        "request_id": str(uuid.uuid4()),
        "expected_revision": cur,
        "config": {
            "sensors": [
                {
                    "sensor_type": "ANALOG",
                    "name": "pH",
                    "unit": "pH",
                    "slave_id": 1,
                    "register_address": 0,
                    "data_type": "float32",
                    "data_format": "ABCD",
                },
                {
                    "sensor_type": "DI",
                    "name": "Float switch",
                    "slave_id": 1,
                    "register_address": 100,
                },
            ],
        },
    }
    r = c.post("/api/v1/config", headers=HDR, json=body)
    assert r.status_code == 200, r.text
    after = c.get("/api/v1/config", headers=HDR).json()
    names = sorted(s["name"] for s in after["sensors"])
    assert names == ["Float switch", "pH"]
    print("  POST /config sensors[] replace OK ✓")


def test_get_readings_from_provider():
    c = _client(readings_provider=_sample_readings)
    r = c.get("/api/v1/readings", headers=HDR)
    assert r.status_code == 200
    body = r.json()
    assert body["polling"] is True
    assert len(body["sensors"]) == 2
    assert body["sensors"][1]["status"] == "ON"
    print("  GET /readings OK ✓")


def test_get_readings_empty_without_provider():
    c = _client()
    r = c.get("/api/v1/readings", headers=HDR)
    assert r.status_code == 200
    assert r.json()["sensors"] == []
    print("  GET /readings empty provider OK ✓")


def test_get_latest_report_404_when_missing():
    c = _client()
    r = c.get("/api/v1/reports/latest", headers=HDR)
    assert r.status_code == 404
    print("  GET /reports/latest 404 OK ✓")


def test_get_latest_report_download():
    from core.txt_generator import REPORT_DIR

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / "TEST_STATION_20260519120000.txt"
    path.write_text("line1\nline2\n", encoding="utf-8")
    c = _client()
    r = c.get("/api/v1/reports/latest", headers=HDR)
    assert r.status_code == 200
    assert b"line1" in r.content
    assert "attachment" in r.headers.get("content-disposition", "").lower()
    print("  GET /reports/latest download OK ✓")


def test_post_config_wrong_api_version():
    c = _client()
    cur = c.get("/api/v1/health").json()["revision"]
    body = {
        "api_version": 99,
        "request_id": str(uuid.uuid4()),
        "expected_revision": cur,
        "config": {},
    }
    r = c.post("/api/v1/config", headers=HDR, json=body)
    assert r.status_code == 400
    print("  POST /config wrong api_version OK ✓")


if __name__ == "__main__":
    print("=== REST API v1 smoke tests ===")
    test_health_no_auth()
    test_get_config_requires_auth()
    test_post_config_revision_conflict()
    test_post_config_apply_increments_revision()
    test_post_config_validation_400()
    test_post_config_sensors_replace()
    test_get_readings_from_provider()
    test_get_readings_empty_without_provider()
    test_get_latest_report_404_when_missing()
    test_get_latest_report_download()
    test_post_config_wrong_api_version()
    print("All REST API tests passed ✓")
