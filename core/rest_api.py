"""REST API v1 — Central App có thể đọc/ghi cấu hình logger qua HTTP/JSON trên LAN.

Contract:
  - Mọi giao tiếp Central ↔ Data Logger chỉ trong mạng nội bộ nhà máy.
  - Auth: header `Authorization: Bearer <token>` (so sánh constant-time).
  - Endpoints:
      GET  /api/v1/health   — liveness + revision (auth-free, dùng để Central ping)
      GET  /api/v1/config   — đọc full snapshot cấu hình (auth bắt buộc)
      POST /api/v1/config   — apply cấu hình (auth + optimistic concurrency)
      GET  /api/v1/readings — snapshot giá trị live (auth, top-level sensors)
      GET  /api/v1/reports/latest — tải file báo cáo TXT mới nhất (auth)
  - HTTP status (REST chuẩn):
      200 OK            — apply / đọc thành công
      400 Bad Request   — payload không hợp lệ (Pydantic / business validation)
      401 Unauthorized  — thiếu / sai bearer token
      409 Conflict      — expected_revision không khớp với DB
      413/422           — body quá lớn / FastAPI Pydantic
      500               — lỗi server (atomic apply rollback)
  - Atomic apply: validate toàn bộ payload trước khi ghi DB; lỗi giữa chừng →
    rollback và **không** tăng `config_revision`.
  - Sensors[]: replace full (Central gửi mảng mới nhất, edge xóa cũ thêm mới).
  - Root config: partial update (chỉ key có trong payload được áp dụng).

Module này thuần Python (FastAPI), không phụ thuộc Qt — `RestServerService`
trong `core/rest_server_service.py` mới là lớp tích hợp Uvicorn + Qt signals.
"""

from __future__ import annotations

import hmac
import logging
import secrets
from pathlib import Path
from typing import Any, Callable, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlmodel import select

from core.database import get_session
from models.app_config import AppConfig
from models.sensor import Sensor, SensorType

logger = logging.getLogger("datalogger.rest_api")

API_VERSION = 1
MAX_BODY_BYTES = 1 * 1024 * 1024  # 1 MB — tránh payload khổng lồ trên edge


# ── Pydantic schema (tự sinh OpenAPI) ────────────────────────────────────


class SensorPayload(BaseModel):
    """Cấu hình 1 cảm biến (Analog/DI/DO) gửi từ Central."""

    model_config = ConfigDict(extra="forbid")

    sensor_type: str = Field(description="ANALOG | DI | DO")
    name: str
    unit: str = ""
    slave_id: int = Field(ge=1, le=247)
    register_address: int = Field(ge=0, le=65535)
    register_type: str = Field(default="holding", description="holding | input")
    data_type: str = Field(default="int16")
    data_format: str = Field(default="AB")
    coefficient: Optional[str] = Field(default="{}")
    min_threshold: Optional[float] = None
    max_threshold: Optional[float] = None
    poll_interval: int = Field(default=3, ge=1, le=3600)
    report_index: int = Field(default=0, ge=0)
    parent_id: Optional[int] = None
    is_system_wide: bool = False
    di_type: Optional[str] = None
    trigger_on_max: bool = True
    trigger_on_min: bool = True
    active: bool = True

    @field_validator("sensor_type")
    @classmethod
    def _check_type(cls, v: str) -> str:
        if v not in (SensorType.ANALOG.value, SensorType.DI.value, SensorType.DO.value):
            raise ValueError("sensor_type must be one of ANALOG | DI | DO")
        return v


class ConfigBody(BaseModel):
    """Object `config` trong request — partial root, sensors[] replace full."""

    model_config = ConfigDict(extra="forbid")

    station_code: Optional[str] = None
    station_name: Optional[str] = None
    poll_interval: Optional[int] = Field(default=None, ge=1, le=3600)
    serial_port: Optional[str] = None
    serial_baudrate: Optional[int] = Field(default=None, ge=1200, le=921600)
    serial_bytesize: Optional[int] = Field(default=None, ge=5, le=8)
    serial_parity: Optional[str] = None
    serial_stopbits: Optional[int] = Field(default=None, ge=1, le=2)
    modbus_tcp_enabled: Optional[bool] = None
    modbus_tcp_port: Optional[int] = Field(default=None, ge=1, le=65535)
    modbus_tcp_bind: Optional[str] = None
    modbus_tcp_unit_id: Optional[int] = Field(default=None, ge=1, le=247)
    sensors: Optional[list[SensorPayload]] = Field(
        default=None,
        description="Nếu có, REPLACE toàn bộ bảng sensor (atomic).",
        max_length=512,
    )

    @field_validator("serial_parity")
    @classmethod
    def _check_parity(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if v not in ("N", "E", "O"):
            raise ValueError("serial_parity must be N | E | O")
        return v


class ConfigRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    api_version: int = Field(description="Phải khớp API_VERSION hiện tại (=1)")
    request_id: str = Field(min_length=1, max_length=128, description="UUID/string trace từ Central")
    expected_revision: int = Field(ge=0, description="Revision Central kỳ vọng — phải khớp DB hiện tại")
    config: ConfigBody


class FieldError(BaseModel):
    field: str
    message: str


class ConfigResponse(BaseModel):
    ok: bool
    request_id: str
    applied_revision: int
    errors: list[FieldError] = Field(default_factory=list)
    message: Optional[str] = None


class HealthResponse(BaseModel):
    ok: bool
    api_version: int
    revision: int


class ConfigSnapshot(BaseModel):
    """Trả về từ GET /config — full snapshot read-only."""

    api_version: int
    revision: int
    config: dict[str, Any]
    sensors: list[dict[str, Any]]


class ReadingItem(BaseModel):
    sensor_id: int
    sensor_type: str
    value: Optional[float] = None
    status: str = "WAIT"
    is_alarm: bool = False
    alarm_type: str = ""
    valid: bool = False
    recorded_at: str = ""


class ReadingsSnapshot(BaseModel):
    ok: bool = True
    polling: bool = False
    rtu_connected: bool = False
    sensors: list[ReadingItem] = Field(default_factory=list)


# ── Helpers ──────────────────────────────────────────────────────────────


def _find_latest_report_path() -> Path | None:
    """Newest TXT in REPORT_DIR (mtime), else newest ReportLog row."""
    from core.txt_generator import REPORT_DIR
    from models.report_log import ReportLog

    if REPORT_DIR.is_dir():
        files = list(REPORT_DIR.glob("*.txt"))
        if files:
            return max(files, key=lambda p: p.stat().st_mtime)

    session = get_session()
    try:
        row = session.exec(
            select(ReportLog).order_by(ReportLog.created_at.desc())  # type: ignore[arg-type]
        ).first()
        if row:
            path = REPORT_DIR / row.filename
            if path.is_file():
                return path
    finally:
        session.close()
    return None


def _read_app_config(session) -> AppConfig:
    cfg = session.exec(select(AppConfig)).first()
    if cfg is None:
        cfg = AppConfig()
        session.add(cfg)
        session.commit()
        session.refresh(cfg)
    return cfg


def _serialize_sensor(s: Sensor) -> dict[str, Any]:
    return {
        "id": s.id,
        "sensor_type": s.sensor_type.value if hasattr(s.sensor_type, "value") else s.sensor_type,
        "name": s.name,
        "unit": s.unit,
        "slave_id": s.slave_id,
        "register_address": s.register_address,
        "register_type": s.register_type,
        "data_type": s.data_type,
        "data_format": s.data_format,
        "coefficient": s.coefficient,
        "min_threshold": s.min_threshold,
        "max_threshold": s.max_threshold,
        "poll_interval": s.poll_interval,
        "report_index": s.report_index,
        "parent_id": s.parent_id,
        "is_system_wide": s.is_system_wide,
        "di_type": s.di_type,
        "trigger_on_max": s.trigger_on_max,
        "trigger_on_min": s.trigger_on_min,
        "active": s.active,
    }


def _serialize_config(cfg: AppConfig) -> dict[str, Any]:
    """Chỉ trả về các field thuộc phạm vi remote (không lộ FTP password, token)."""
    return {
        "station_code": cfg.station_code,
        "station_name": cfg.station_name,
        "poll_interval": cfg.poll_interval,
        "serial_port": cfg.serial_port,
        "serial_baudrate": cfg.serial_baudrate,
        "serial_bytesize": cfg.serial_bytesize,
        "serial_parity": cfg.serial_parity,
        "serial_stopbits": cfg.serial_stopbits,
        "modbus_tcp_enabled": cfg.modbus_tcp_enabled,
        "modbus_tcp_port": cfg.modbus_tcp_port,
        "modbus_tcp_bind": cfg.modbus_tcp_bind,
        "modbus_tcp_unit_id": cfg.modbus_tcp_unit_id,
    }


# ── App factory ──────────────────────────────────────────────────────────


def create_app(
    token_provider: Callable[[], str],
    on_applied: Optional[Callable[[int], None]] = None,
    readings_provider: Optional[Callable[[], dict[str, Any]]] = None,
) -> FastAPI:
    """Build FastAPI app.

    Args:
        token_provider: callable trả về Bearer token hợp lệ (đọc từ AppConfig).
            Dùng callable để token có thể xoay mà không cần restart server.
        on_applied: callback (revision) gọi sau khi POST /config thành công —
            `RestServerService` dùng để emit signal vào Qt main thread.
        readings_provider: callable trả về snapshot readings (Monitor cache).
    """
    app = FastAPI(
        title="Data Logger Remote Config API",
        version="1.0.0",
        description="REST API nội bộ cho Central App (LAN) — đọc/ghi cấu hình logger.",
        docs_url="/api/v1/docs",
        openapi_url="/api/v1/openapi.json",
    )

    def _check_auth(request: Request) -> None:
        auth = request.headers.get("authorization", "")
        token = token_provider() or ""
        if not token:
            # Token rỗng = chưa cấu hình; từ chối toàn bộ để tránh "API mở".
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "REST API token not configured")
        if not auth.lower().startswith("bearer "):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
        provided = auth.split(" ", 1)[1].strip()
        if not hmac.compare_digest(provided, token):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid bearer token")

    async def _check_body_size(request: Request) -> None:
        cl = request.headers.get("content-length")
        if cl is not None:
            try:
                if int(cl) > MAX_BODY_BYTES:
                    raise HTTPException(
                        status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        f"Body too large (>{MAX_BODY_BYTES} bytes)",
                    )
            except ValueError:
                pass

    @app.get("/api/v1/health", response_model=HealthResponse)
    def health() -> HealthResponse:
        session = get_session()
        try:
            cfg = _read_app_config(session)
            return HealthResponse(ok=True, api_version=API_VERSION, revision=cfg.config_revision)
        finally:
            session.close()

    @app.get(
        "/api/v1/config",
        response_model=ConfigSnapshot,
        dependencies=[Depends(_check_auth)],
    )
    def get_config() -> ConfigSnapshot:
        session = get_session()
        try:
            cfg = _read_app_config(session)
            sensors = list(session.exec(select(Sensor)).all())
            return ConfigSnapshot(
                api_version=API_VERSION,
                revision=cfg.config_revision,
                config=_serialize_config(cfg),
                sensors=[_serialize_sensor(s) for s in sensors],
            )
        finally:
            session.close()

    @app.get(
        "/api/v1/readings",
        response_model=ReadingsSnapshot,
        dependencies=[Depends(_check_auth)],
    )
    def get_readings() -> ReadingsSnapshot:
        if readings_provider is None:
            return ReadingsSnapshot(ok=True, polling=False, rtu_connected=False, sensors=[])
        try:
            raw = readings_provider()
        except Exception:
            logger.exception("readings_provider failed")
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "Readings snapshot unavailable",
            )
        if not isinstance(raw, dict):
            raw = {}
        sensors_raw = raw.get("sensors") or []
        items: list[ReadingItem] = []
        if isinstance(sensors_raw, list):
            for s in sensors_raw:
                if isinstance(s, dict) and s.get("sensor_id") is not None:
                    try:
                        items.append(ReadingItem(**s))
                    except Exception:
                        continue
        return ReadingsSnapshot(
            ok=bool(raw.get("ok", True)),
            polling=bool(raw.get("polling", False)),
            rtu_connected=bool(raw.get("rtu_connected", False)),
            sensors=items,
        )

    @app.get(
        "/api/v1/reports/latest",
        dependencies=[Depends(_check_auth)],
    )
    def get_latest_report() -> FileResponse:
        path = _find_latest_report_path()
        if path is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "No report file available")
        return FileResponse(
            path,
            media_type="text/plain",
            filename=path.name,
            headers={"Content-Disposition": f'attachment; filename="{path.name}"'},
        )

    @app.post(
        "/api/v1/config",
        response_model=ConfigResponse,
        dependencies=[Depends(_check_auth), Depends(_check_body_size)],
    )
    def post_config(body: ConfigRequest) -> ConfigResponse:
        if body.api_version != API_VERSION:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"api_version={body.api_version} not supported (expected {API_VERSION})",
            )

        session = get_session()
        try:
            cfg = _read_app_config(session)
            if body.expected_revision != cfg.config_revision:
                logger.info(
                    "POST /config conflict: client expected=%d server=%d (request_id=%s)",
                    body.expected_revision, cfg.config_revision, body.request_id,
                )
                return JSONResponse(
                    status_code=status.HTTP_409_CONFLICT,
                    content=ConfigResponse(
                        ok=False,
                        request_id=body.request_id,
                        applied_revision=cfg.config_revision,
                        errors=[FieldError(
                            field="expected_revision",
                            message=(
                                f"Revision conflict: server is at {cfg.config_revision}, "
                                f"client expected {body.expected_revision}"
                            ),
                        )],
                        message="Refresh GET /api/v1/config and retry.",
                    ).model_dump(),
                )

            errors = _apply_config_atomic(session, cfg, body.config)
            if errors:
                session.rollback()
                return JSONResponse(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    content=ConfigResponse(
                        ok=False,
                        request_id=body.request_id,
                        applied_revision=cfg.config_revision,
                        errors=errors,
                    ).model_dump(),
                )

            cfg.config_revision = cfg.config_revision + 1
            session.add(cfg)
            session.commit()
            session.refresh(cfg)

            new_revision = cfg.config_revision
            logger.info(
                "POST /config applied: revision %d → %d (request_id=%s)",
                body.expected_revision, new_revision, body.request_id,
            )
            if on_applied is not None:
                try:
                    on_applied(new_revision)
                except Exception:
                    logger.exception("on_applied callback raised")

            return ConfigResponse(
                ok=True,
                request_id=body.request_id,
                applied_revision=new_revision,
                message="Configuration applied.",
            )
        except HTTPException:
            session.rollback()
            raise
        except Exception as e:
            session.rollback()
            logger.exception("POST /config server error (request_id=%s): %s", body.request_id, e)
            raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Internal error applying config")
        finally:
            session.close()

    return app


def _apply_config_atomic(session, cfg: AppConfig, body: ConfigBody) -> list[FieldError]:
    """Merge partial root + replace full sensors[]. Trả về danh sách lỗi business.

    Caller chịu trách nhiệm commit / rollback dựa trên kết quả.
    """
    errors: list[FieldError] = []

    root_fields = (
        "station_code", "station_name", "poll_interval",
        "serial_port", "serial_baudrate", "serial_bytesize",
        "serial_parity", "serial_stopbits",
        "modbus_tcp_enabled", "modbus_tcp_port",
        "modbus_tcp_bind", "modbus_tcp_unit_id",
    )
    for f in root_fields:
        v = getattr(body, f)
        if v is not None:
            setattr(cfg, f, v)

    bind = (cfg.modbus_tcp_bind or "").strip()
    if not bind:
        errors.append(FieldError(
            field="config.modbus_tcp_bind",
            message="modbus_tcp_bind is required (use 0.0.0.0 for all interfaces).",
        ))

    if body.sensors is not None:
        for existing in list(session.exec(select(Sensor)).all()):
            session.delete(existing)
        session.flush()

        for idx, sp in enumerate(body.sensors):
            try:
                row = Sensor(
                    sensor_type=sp.sensor_type,
                    name=sp.name,
                    unit=sp.unit,
                    slave_id=sp.slave_id,
                    register_address=sp.register_address,
                    register_type=sp.register_type,
                    data_type=sp.data_type,
                    data_format=sp.data_format,
                    coefficient=sp.coefficient,
                    min_threshold=sp.min_threshold,
                    max_threshold=sp.max_threshold,
                    poll_interval=sp.poll_interval,
                    report_index=sp.report_index,
                    parent_id=sp.parent_id,
                    is_system_wide=sp.is_system_wide,
                    di_type=sp.di_type,
                    trigger_on_max=sp.trigger_on_max,
                    trigger_on_min=sp.trigger_on_min,
                    active=sp.active,
                )
                session.add(row)
            except Exception as e:
                errors.append(FieldError(
                    field=f"config.sensors[{idx}]",
                    message=f"Invalid sensor entry: {e}",
                ))

    return errors


def generate_token() -> str:
    """Sinh Bearer token ngẫu nhiên url-safe ~ 32 byte."""
    return secrets.token_urlsafe(32)
