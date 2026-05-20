"""Best-effort LAN IPv4 discovery (shared by REST/Modbus services and provisioning QR)."""

from __future__ import annotations

import socket

_LOOPBACK = frozenset({"127.0.0.1", "::1", "localhost"})


def get_primary_lan_ip() -> str:
    """UDP route trick, then hostname fallback; empty string if unknown."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.2)
        try:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
        finally:
            s.close()
    except OSError:
        try:
            return socket.gethostbyname(socket.gethostname())
        except OSError:
            return ""


def resolve_lan_host(bind: str, primary_ip: str) -> str:
    """Pick host for Central to connect: concrete bind IP, else primary LAN IP."""
    b = (bind or "").strip()
    if b and b not in ("0.0.0.0", "::") and b.lower() not in _LOOPBACK:
        return b
    p = (primary_ip or "").strip()
    if p and p.lower() not in _LOOPBACK:
        return p
    return p
