"""Dump OpenAPI spec của REST API v1 ra `openapi-v1.yaml` + `openapi-v1.json`.

Chạy local sau khi thay đổi schema để Central App regenerate client.

    python tools/dump_openapi.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.rest_api import create_app  # noqa: E402


def _to_yaml(obj, indent: int = 0) -> str:
    """Minimal JSON-compatible YAML emitter (đủ cho OpenAPI dict/list/scalar).

    Tránh phụ thuộc PyYAML; YAML hợp lệ vì JSON ⊂ YAML.
    """
    sp = "  " * indent
    if isinstance(obj, dict):
        if not obj:
            return "{}"
        out = []
        for k, v in obj.items():
            key = json.dumps(str(k)) if not _safe_key(str(k)) else str(k)
            if isinstance(v, (dict, list)) and v:
                out.append(f"{sp}{key}:")
                out.append(_to_yaml(v, indent + 1))
            else:
                out.append(f"{sp}{key}: {_to_yaml(v, indent + 1).lstrip()}")
        return "\n".join(out)
    if isinstance(obj, list):
        if not obj:
            return "[]"
        out = []
        for item in obj:
            if isinstance(item, (dict, list)) and item:
                out.append(f"{sp}-")
                out.append(_to_yaml(item, indent + 1))
            else:
                out.append(f"{sp}- {_to_yaml(item, indent + 1).lstrip()}")
        return "\n".join(out)
    return json.dumps(obj, ensure_ascii=False)


def _safe_key(k: str) -> bool:
    if not k:
        return False
    if any(c in k for c in ': #-{}[],&*!|>\'"%@`'):
        return False
    return True


def main() -> None:
    app = create_app(token_provider=lambda: "dummy", on_applied=None)
    spec = app.openapi()
    json_path = ROOT / "openapi-v1.json"
    yaml_path = ROOT / "openapi-v1.yaml"
    json_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding="utf-8")
    yaml_path.write_text(_to_yaml(spec) + "\n", encoding="utf-8")
    print(f"Wrote {json_path.relative_to(ROOT)} ({json_path.stat().st_size} bytes)")
    print(f"Wrote {yaml_path.relative_to(ROOT)} ({yaml_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
