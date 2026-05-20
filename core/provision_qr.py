"""Provisioning QR payload + PNG for Central App pairing (LAN)."""

from __future__ import annotations

import base64
import io
import json
from typing import TYPE_CHECKING

import segno

from core.lan_ip import get_primary_lan_ip, resolve_lan_host

if TYPE_CHECKING:
    from models.app_config import AppConfig

PROVISION_SCHEMA = "central-logger-provision/v1"


def build_provision_payload(cfg: AppConfig, host: str) -> dict:
    """Build dict matching central-logger-provision/v1 (stable key order)."""
    payload: dict = {
        "schema": PROVISION_SCHEMA,
        "api_token": cfg.rest_api_token,
        "host": host,
        "api_port": cfg.rest_api_port,
        "modbus_port": cfg.modbus_tcp_port,
        "modbus_unit_id": cfg.modbus_tcp_unit_id,
    }
    code = (cfg.station_code or "").strip()
    name = (cfg.station_name or "").strip()
    if code:
        payload["station_code"] = code
    if name:
        payload["station_name"] = name
    return payload


def build_provision_json(cfg: AppConfig, host: str | None = None) -> str:
    """Compact one-line UTF-8 JSON for QR encoding."""
    if host is None:
        host = resolve_lan_host(cfg.rest_api_bind, get_primary_lan_ip())
    return json.dumps(
        build_provision_payload(cfg, host),
        ensure_ascii=False,
        separators=(",", ":"),
    )


def render_qr_png_bytes(data: str) -> bytes:
    """Encode *data* as PNG QR (high ECC for ~200–400 byte payloads)."""
    qr = segno.make(data, error="q")
    buf = io.BytesIO()
    qr.save(buf, kind="png", scale=6, border=2)
    return buf.getvalue()


def render_qr_base64(data: str) -> str:
    """Base64 PNG without data-URL prefix (for QML ``data:image/png;base64,``)."""
    return base64.standard_b64encode(render_qr_png_bytes(data)).decode("ascii")


def provision_qr_png_for_config(cfg: AppConfig) -> tuple[str, bytes]:
    """Return (json_payload, png_bytes) for current config."""
    host = resolve_lan_host(cfg.rest_api_bind, get_primary_lan_ip())
    payload_json = build_provision_json(cfg, host)
    return payload_json, render_qr_png_bytes(payload_json)
