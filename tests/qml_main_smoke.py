#!/usr/bin/env python3
"""Smoke: ứng dụng thật tải QML thành công (main.py, offscreen, không cần pytest).

Tránh pump processEvents — dễ gây TypeError tạm từ binding QML trước khi vòng lặp sự kiện đầy đủ.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    env = os.environ.copy()
    env.setdefault("QT_QPA_PLATFORM", "offscreen")
    proc = subprocess.Popen(
        [sys.executable, str(_REPO / "main.py")],
        cwd=str(_REPO),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        out, err = proc.communicate(timeout=4)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
    combined = (out or "") + (err or "")
    if "QML loaded thành công" not in combined and "QML loaded" not in combined:
        print("FAIL: không thấy log QML loaded", file=sys.stderr)
        print(combined[:4000], file=sys.stderr)
        return 1
    if "Cannot load Main.qml" in combined or "Không thể load Main.qml" in combined:
        print("FAIL: Main.qml không load", file=sys.stderr)
        print(combined[:4000], file=sys.stderr)
        return 1
    if "file://" in err and ("TypeError" in err or "ReferenceError" in err):
        print("FAIL: lỗi QML trên stderr", file=sys.stderr)
        print(err[:4000], file=sys.stderr)
        return 1
    print("OK: main.py + QML (offscreen smoke)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
