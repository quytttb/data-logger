"""RestServerService — chạy Uvicorn(FastAPI) trong background thread + Qt signals.

Pattern bám sát ModbusTcpServerService:
  - `start(bind, port, token)` khởi tạo asyncio loop trong thread riêng và serve
    FastAPI app qua Uvicorn (idempotent).
  - `stop()` lên lịch shutdown asyncio-safe và join thread.
  - Emit `configApplied(int revision)` mỗi khi POST /api/v1/config thành công;
    QObject nhận signal trên Qt main thread (queued connection mặc định khi
    emit từ thread khác).
"""

from __future__ import annotations

import asyncio
import logging
import threading
from collections.abc import Callable
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot

from core.lan_ip import get_primary_lan_ip
from core.rest_api import create_app

logger = logging.getLogger("datalogger.rest_server")


class RestServerService(QObject):
    """Vòng đời REST API + token provider + lastError exposed cho QML."""

    STATE_STOPPED = "stopped"
    STATE_STARTING = "starting"
    STATE_LISTENING = "listening"
    STATE_ERROR = "error"

    stateChanged = Signal()
    lastErrorChanged = Signal()
    configApplied = Signal(int)  # revision

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._lock = threading.RLock()
        self._bind = "0.0.0.0"
        self._port = 8080
        self._token = ""

        self._thread: threading.Thread | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._uvicorn_server = None  # uvicorn.Server
        self._state = self.STATE_STOPPED
        self._last_error = ""
        self._readings_provider: Callable[[], dict[str, Any]] | None = None

    def set_readings_provider(self, provider: Callable[[], dict[str, Any]] | None) -> None:
        """MonitorController.readings_snapshot — callable từ REST worker thread."""
        with self._lock:
            self._readings_provider = provider

    # ── Qt properties ─────────────────────────────────────────────────────

    @Property(str, notify=stateChanged)
    def state(self) -> str:
        return self._state

    @Property(bool, notify=stateChanged)
    def isListening(self) -> bool:
        return self._state == self.STATE_LISTENING

    @Property(str, notify=lastErrorChanged)
    def lastError(self) -> str:
        return self._last_error

    @Property(str, notify=stateChanged)
    def listeningEndpoint(self) -> str:
        if self._state != self.STATE_LISTENING:
            return ""
        return f"{self._bind}:{self._port}"

    @Slot(result=str)
    def primaryIp(self) -> str:
        """IP LAN gần đúng (best-effort) — hiển thị URL trên QML."""
        return get_primary_lan_ip()

    # ── Token provider (đọc tại request time để hỗ trợ xoay token) ────────

    def _current_token(self) -> str:
        with self._lock:
            return self._token

    def update_token(self, token: str) -> None:
        """Đổi token đang dùng mà không cần restart server (so sánh constant-time
        diễn ra tại từng request qua callable)."""
        with self._lock:
            self._token = token or ""

    # ── Lifecycle ─────────────────────────────────────────────────────────

    def start(self, bind: str, port: int, token: str) -> None:
        """Idempotent: cấu hình giống nhau thì bỏ qua, khác thì stop + start lại."""
        new_bind = bind or "0.0.0.0"
        new_port = int(port)
        new_token = token or ""
        if self._state in (self.STATE_LISTENING, self.STATE_STARTING):
            if self._bind == new_bind and self._port == new_port:
                self.update_token(new_token)
                return
            self.stop()

        self._bind = new_bind
        self._port = new_port
        self.update_token(new_token)
        self._set_state(self.STATE_STARTING, "")

        self._thread = threading.Thread(
            target=self._run_loop,
            name="RestApiServer",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        srv = self._uvicorn_server
        loop = self._loop
        if srv is not None and loop is not None and loop.is_running():
            try:
                srv.should_exit = True
                loop.call_soon_threadsafe(lambda: None)
            except Exception as e:
                logger.warning("rest stop schedule error: %s", e)
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=3.0)
        self._loop = None
        self._thread = None
        self._uvicorn_server = None
        self._set_state(self.STATE_STOPPED, "")

    def _run_loop(self) -> None:
        loop = asyncio.new_event_loop()
        self._loop = loop
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(self._serve())
        except Exception as e:
            logger.error("REST API server crashed: %s", e, exc_info=True)
            self._set_state(self.STATE_ERROR, str(e))
        finally:
            try:
                loop.close()
            except Exception:
                pass

    async def _serve(self) -> None:
        import uvicorn

        with self._lock:
            readings_provider = self._readings_provider
        app = create_app(
            token_provider=self._current_token,
            on_applied=lambda rev: self.configApplied.emit(int(rev)),
            readings_provider=readings_provider,
        )
        config = uvicorn.Config(
            app=app,
            host=self._bind,
            port=self._port,
            log_level="info",
            access_log=False,
            lifespan="off",
        )
        server = uvicorn.Server(config)
        self._uvicorn_server = server
        try:
            self._set_state(self.STATE_LISTENING, "")
            logger.info("REST API listening on %s:%d", self._bind, self._port)
            await server.serve()
        except OSError as e:
            logger.error("REST API bind failed: %s", e)
            self._set_state(self.STATE_ERROR, f"Bind failed: {e}")
        except Exception as e:
            logger.error("REST API server error: %s", e, exc_info=True)
            self._set_state(self.STATE_ERROR, str(e))
        finally:
            self._uvicorn_server = None
            if self._state == self.STATE_LISTENING:
                self._set_state(self.STATE_STOPPED, "")

    # ── Internal ──────────────────────────────────────────────────────────

    def _set_state(self, state: str, err: str) -> None:
        changed_state = state != self._state
        changed_err = err != self._last_error
        self._state = state
        self._last_error = err
        if changed_state:
            self.stateChanged.emit()
        if changed_err:
            self.lastErrorChanged.emit()
