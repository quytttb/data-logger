"""Configure Qt QML import paths before importing PySide6.

Two scenarios are covered:

1. Nuitka onefile/standalone where the build bundles PySide6's QML imports
   into ``PySide6/Qt/qml`` next to the extracted executable. We point Qt at
   that directory explicitly because Qt only auto-detects it when the bundle
   layout matches its built-in expectations.
2. Plain Python or a Nuitka build that omitted QML — fall back to system
   Qt6 QML modules from Debian/Raspberry Pi OS (``qml6-module-*``) under
   ``/usr/lib/.../qt6/qml`` so the app still launches.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

_SYSTEM_QML_ROOTS = (
    "/usr/lib/aarch64-linux-gnu/qt6/qml",
    "/usr/lib/arm-linux-gnueabihf/qt6/qml",
    "/usr/lib/x86_64-linux-gnu/qt6/qml",
    "/usr/lib/qt6/qml",
)


def _is_qml_root(p: Path) -> bool:
    return p.is_dir() and (p / "QtQuick").is_dir()


def ensure_qt_qml_import_path() -> None:
    """Prepend a valid Qt6 QML root to ``QT_QML_IMPORT_PATH`` if found."""
    admin = os.environ.get("DATALOGGER_QT_QML_IMPORT_PATH", "").strip()
    if admin:
        ap = Path(admin)
        if _is_qml_root(ap):
            _prepend(admin)
            return

    # Respect QT_QML_IMPORT_PATH already set by the environment (e.g. systemd).
    # Do not prepend a bundled onefile path in front of it —
    # that would shadow a matching PySide6 wheel QML tree and break ABI.
    existing = os.environ.get("QT_QML_IMPORT_PATH", "").strip()
    if existing:
        for root in existing.split(os.pathsep):
            root = root.strip()
            if not root:
                continue
            if _is_qml_root(Path(root)):
                return

    for candidate in _bundle_candidates():
        if _is_qml_root(candidate):
            _prepend(str(candidate))
            return

    for path in _SYSTEM_QML_ROOTS:
        p = Path(path)
        if _is_qml_root(p):
            _prepend(str(p))
            return


def _bundle_candidates() -> tuple[Path, ...]:
    bases: list[Path] = []
    if getattr(sys, "frozen", False):
        bases.append(Path(sys.executable).resolve().parent)
    bases.append(Path(__file__).resolve().parent.parent)
    out: list[Path] = []
    for b in bases:
        out.append(b / "PySide6" / "Qt" / "qml")
        out.append(b / "Qt" / "qml")
    return tuple(out)


def _prepend(path: str) -> None:
    cur = os.environ.get("QT_QML_IMPORT_PATH", "")
    parts = [x for x in cur.split(os.pathsep) if x]
    if path in parts:
        return
    os.environ["QT_QML_IMPORT_PATH"] = path + (os.pathsep + cur if cur else "")
