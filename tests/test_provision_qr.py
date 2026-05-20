"""Unit tests for provisioning QR payload and PNG round-trip."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.lan_ip import resolve_lan_host
from core.provision_qr import (
    PROVISION_SCHEMA,
    build_provision_json,
    build_provision_payload,
    render_qr_png_bytes,
)
from models.app_config import AppConfig

SAMPLE_TOKEN = "test-provision-token-urlsafe-abc123"


def _cfg(**kwargs) -> AppConfig:
    base = dict(
        rest_api_token=SAMPLE_TOKEN,
        rest_api_port=8080,
        rest_api_bind="0.0.0.0",
        modbus_tcp_port=5020,
        modbus_tcp_unit_id=1,
        station_code="TRAM-TEST",
        station_name="Trạm thử",
    )
    base.update(kwargs)
    return AppConfig(**base)


def test_build_provision_payload_schema_and_fields():
    cfg = _cfg()
    host = "192.168.10.42"
    payload = build_provision_payload(cfg, host)
    assert payload["schema"] == PROVISION_SCHEMA
    assert payload["api_token"] == SAMPLE_TOKEN
    assert payload["host"] == host
    assert payload["api_port"] == 8080
    assert payload["modbus_port"] == 5020
    assert payload["modbus_unit_id"] == 1
    assert payload["station_code"] == "TRAM-TEST"
    assert payload["station_name"] == "Trạm thử"


def test_build_provision_json_compact_one_line():
    cfg = _cfg()
    raw = build_provision_json(cfg, "10.0.0.5")
    assert "\n" not in raw
    parsed = json.loads(raw)
    assert parsed["schema"] == PROVISION_SCHEMA
    assert parsed["api_token"] == SAMPLE_TOKEN


def test_resolve_lan_host():
    assert resolve_lan_host("0.0.0.0", "192.168.1.10") == "192.168.1.10"
    assert resolve_lan_host("192.168.1.5", "192.168.1.10") == "192.168.1.5"
    assert resolve_lan_host("127.0.0.1", "192.168.1.10") == "192.168.1.10"


def test_regenerate_changes_json():
    cfg1 = _cfg(rest_api_token="token-a")
    cfg2 = _cfg(rest_api_token="token-b")
    host = "192.168.0.1"
    assert build_provision_json(cfg1, host) != build_provision_json(cfg2, host)


def test_qr_round_trip_decode():
    try:
        from PIL import Image
        from pyzbar.pyzbar import decode as zbar_decode
    except ImportError as exc:
        pytest.skip(f"pyzbar/Pillow/zbar not available: {exc}")

    cfg = _cfg()
    payload_json = build_provision_json(cfg, "192.168.0.99")
    png = render_qr_png_bytes(payload_json)
    assert png[:8] == b"\x89PNG\r\n\x1a\n"

    img = Image.open(io.BytesIO(png)).convert("L")
    decoded = zbar_decode(img)
    assert len(decoded) >= 1
    text = decoded[0].data.decode("utf-8")
    parsed = json.loads(text)
    assert parsed["schema"] == PROVISION_SCHEMA
    assert parsed["api_token"] == SAMPLE_TOKEN
    assert parsed["host"] == "192.168.0.99"
