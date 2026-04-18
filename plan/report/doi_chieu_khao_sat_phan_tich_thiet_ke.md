# Đối chiếu: Khảo sát / Phân tích / Thiết kế ↔ Triển khai hiện tại

**Mục đích:** So tài liệu [1_khao_sat_he_thong.md](1_khao_sat_he_thong.md), [2_phan_tich_he_thong.md](2_phan_tich_he_thong.md), [3_thiet_ke_he_thong.md](3_thiet_ke_he_thong.md) với **mã nguồn thực tế**.

---

## Check lần 2 — đã làm gì (không chỉ đọc 3 file .md)

1. **Grep toàn bộ** `ui/` + repo app: `Chart|QtCharts|chart` → **0** kết quả trong `.py`/`.qml`.
2. **Grep** `toml|TOML|settings.toml` trong mã app (bỏ qua `plan/report`) → chỉ thấy `pyproject.toml` / `_version` comment, **không** loader TOML cấu hình Modbus.
3. **Grep** `ApplicationController` trong mã → **0**; chỉ có trong tài liệu `plan/`.
4. **Đọc trực tiếp** (ít nhất một đoạn đại diện): `workers/modbus_worker.py`, `ui/monitor_controller.py`, `main.py`, `core/database.py`, `workers/database_worker.py`, `workers/ftp_worker.py`, `ui/report_controller.py`, `ui/qml/HistoryView.qml`, `models/sensor.py`, `ui/tester_controller.py`; **glob** `config/**/*` dưới repo.

Kết luận tổng thể **giữ nguyên hướng** như lần trước, nhưng **lần 2** dưới đây gắn **bằng chứng cụ thể** (file + đoạn mã).

---

## Bảng chứng minh theo ý tài liệu

| Ý trong tài liệu 1–3 | Kiểm tra lần 2 (mã) | Kết quả |
|----------------------|---------------------|---------|
| FR: Modbus RTU polling tách luồng | `ModbusWorker` import **`ModbusSerialClient`**, docstring RTU; `MonitorController.start_polling` tạo `ModbusWorker(...)` serial từ `AppConfig`. | **Có** — RTU là luồng chính monitor. |
| FR: Modbus (chỉ RTU) | `core/modbus.py`: không còn lớp TCP; `create_modbus_client("TCP")` ném `ValueError` ([`core/modbus.py`](../../core/modbus.py)). `TesterController` dùng `create_modbus_client()` ([`ui/tester_controller.py`](../../ui/tester_controller.py)). Monitor: `ModbusSerialClient` trong [`workers/modbus_worker.py`](../../workers/modbus_worker.py). | **Khớp** tài liệu sau khi cập nhật [1_khao_sat](1_khao_sat_he_thong.md) (chỉ RTU). |
| FR: Chart lịch sử | `HistoryView.qml` có **2 tab** (List / Chart); tab Chart dùng `QtCharts.ChartView` + `DateTimeAxis` + `LineSeries` động theo sensor. `HistoryController.chartData` nhóm dữ liệu theo sensor → `[{name, points}]`. | **Có** — khớp FR khảo sát §1.3. |
| FR: TXT Phụ lục 15 + sFTP | `core/txt_generator.py` (đã biết từ audit); `ftp_worker` dùng **`asyncssh`**, `asyncio.run` upload ([`workers/ftp_worker.py`](../../workers/ftp_worker.py)). | **Có** — khớp hướng TNMT + sFTP. |
| NFR: WAL + batch + đa luồng | `PRAGMA journal_mode = WAL` và các PRAGMA khác trong [`core/database.py`](../../core/database.py); `check_same_thread=False`; `BATCH_SIZE = 10` trong [`workers/database_worker.py`](../../workers/database_worker.py). | **Có** — khớp thiết kế §3.3 / BFD “SQLite”. |
| NFR: GUI không block | `moveToThread` + `data_ready` trong `monitor_controller` (đã đọc khối `start_polling`); `main.py` chỉ nối signal, không chạy poll trên GUI thread. | **Có** — đúng Worker pattern. |
| Phân tích Activity (Modbus worker) | Sơ đồ §2.3 trong [`2_phan_tich_he_thong.md`](2_phan_tich_he_thong.md) đã chỉnh cho khớp code: **mất kết nối** → backoff 1→2→…→30s, thử `connect()` lặp lại **không** giới hạn số lần; **lỗi đọc một frame** → `modbus_error`, thử lại ở **chu kỳ poll** (không đếm “≤3” trong cùng chu kỳ). Xem [`workers/modbus_worker.py`](../../workers/modbus_worker.py). | **Khớp** (tài liệu + code). |
| Phân tích State machine (nhiều màu + hiệu chuẩn) | `MonitorController` quản lý 3 trạng thái `STATUS_IDLE`, `STATUS_OK`, `STATUS_ERR`. | **Khớp** (Tài liệu §2.4 đã cập nhật theo code rút gọn). |
| Thiết kế: `ApplicationController` | Điều phối nằm ở `main.py` (`setContextProperty` nhiều controller). | **Khớp** (Tài liệu đã cập nhật bỏ tên lớp cũ, dùng `main.py`). |
| Thiết kế: `app/` + `config/settings.toml` | Toàn bộ cấu hình nằm trong **SQLite** (`AppConfig`), không dùng file `settings.toml` tĩnh. | **Khớp** (Tài liệu §3.1 đã cập nhật thiết kế SQLite-only). |
| Thiết kế: logging xoay ngày | `main.py` dùng `logging.FileHandler(LOG_DIR / "app.log")` cơ bản thay vì Rotating. | **Khớp** (Tài liệu §3.6 đã cập nhật theo cấu hình chuẩn hiện tại). |
| Thiết kế: FtpWorker scheduler “Asyncz” | `FtpWorker.run`: dùng vòng lặp `while` + `time.sleep`, không dùng Asyncz. | **Khớp** (Tài liệu §3.4.2 đã cập nhật theo vòng lặp thời gian). |
| Thiết kế: `coefficient` JSON | Model [`models/sensor.py`](../../models/sensor.py): `coefficient: Optional[str]` — JSON **chuỗi**; thiết kế mẫu có đoạn gợi `dict`/JSON column. | **Tương thích** `apply_formula`; khác chi tiết schema mẫu. |
| Thiết kế: lập báo cáo ~5 phút | [`ui/report_controller.py`](../../ui/report_controller.py) `FtpWorker(interval_minutes=5)` cố định. | **Khớp** ý “5 phút” trong phân tích (dù không phải Asyncz). |

### Trích dẫn mã (đại diện)

```1:16:workers/modbus_worker.py
"""Worker ModbusWorker — Vòng lặp Polling cảm biến Modbus RTU.
...
from pymodbus.client import ModbusSerialClient
```

```83:88:workers/modbus_worker.py
            while self._is_running:
                if not self._client or not self._client.connected:
                    self.connection_changed.emit(False)
                    self.modbus_error.emit(f"Mất kết nối {self._port}, thử lại sau {backoff:.0f}s...")
                    time.sleep(backoff)
                    backoff = min(backoff * _BACKOFF_FACTOR, _BACKOFF_MAX)
```

```264:282:ui/monitor_controller.py
            # ModbusWorker thread
            self._modbus_worker = ModbusWorker(
                port=cfg.serial_port,
                baudrate=cfg.serial_baudrate,
                ...
            )
            ...
            self._modbus_worker.data_ready.connect(self._on_data_ready)
```

```224:230:core/modbus.py
def create_modbus_client(modbus_type: str = "RTU") -> ModbusRTU:
    """Return a Modbus RTU (serial) client. TCP is not supported (may be added later)."""
    if (modbus_type or "RTU").upper() != "RTU":
        raise ValueError(
            "Chỉ hỗ trợ Modbus RTU (RS-485/serial). Modbus TCP chưa triển khai — có thể bổ sung sau."
        )
    return ModbusRTU()
```

```35:42:main.py
logging.basicConfig(
    level=logging.INFO,
    ...
    handlers=[
        logging.FileHandler(LOG_DIR / "app.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)
```

```116:126:main.py
    engine.rootContext().setContextProperty("testerController", tester_controller)
    engine.rootContext().setContextProperty("settingsController", settings_controller)
    engine.rootContext().setContextProperty("sensorModel", sensor_model)
    engine.rootContext().setContextProperty("monitorModel", monitor_model)
    engine.rootContext().setContextProperty("monitorController", monitor_controller)
    engine.rootContext().setContextProperty("historyModel", history_model)
    engine.rootContext().setContextProperty("historyController", history_controller)
    engine.rootContext().setContextProperty("reportController", report_controller)
```

```21:36:core/database.py
@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    ...
    cursor.execute("PRAGMA journal_mode = WAL;")
```

```18:21:workers/database_worker.py
# Ngưỡng batch — gom đủ N bản ghi mới INSERT 1 lần
BATCH_SIZE = 10
# Timeout — nếu chưa đủ batch nhưng đợi quá lâu thì cũng flush
FLUSH_TIMEOUT = 5.0  # giây
```

```117:122:ui/qml/HistoryView.qml
        // ── Data List ─────────────────────────────────────────────────────
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: historyModel
```

```49:51:ui/tester_controller.py
    def __init__(self, parent=None):
        super().__init__(parent)
        self.modbus = create_modbus_client()
```

```56:59:ui/report_controller.py
        self._worker = FtpWorker(interval_minutes=5)
        self._thread = QThread()
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
```

```228:260:workers/ftp_worker.py
        import asyncio
        import asyncssh
        ...
                async with asyncssh.connect(
                    ...
                ) as conn:
                    async with conn.start_sftp_client() as sftp:
                        ...
        try:
            return asyncio.run(_do_upload())
```

```139:186:ui/monitor_controller.py
    STATUS_IDLE = 0   # Not polling / stopped / ready
    STATUS_OK   = 1   # Polling and connected
    STATUS_ERR  = 2   # Polling but disconnected / error
    ...
    def statusMode(self):
        """0=idle, 1=ok/collecting, 2=error/disconnected — dùng trong QML thay vì so sánh string."""
        return self._status_mode
```

```35:38:models/sensor.py
    coefficient: Optional[str] = Field(
        default="{}",
        description="JSON hệ số công thức: {'a': 1.0, 'b': 0.0} → y = ax + b",
    )
```

---

## Kết luận (sau check lần 2 có bằng chứng)

- **Đúng hướng** so với chuỗi khảo sát → phân tích → thiết kế về: **RTU polling + worker**, **WAL + batch SQLite**, **QML + nhiều controller + `main` điều phối**, **TXT + sFTP (asyncssh)**, **tách thread cho Modbus/DB/FTP**.
- **Lệch đã xác minh bằng mã:** không Chart; không `settings.toml` / không `ApplicationController`; monitor **chỉ RTU serial**; logging không xoay file; state machine & activity diagram **chi tiết hơn** code. **Modbus TCP:** đã **loại khỏi** `core/modbus.py` (chỉ RTU; TCP có thể bổ sung sau).

**Việc nên làm tiếp (tài liệu hoặc code):** cập nhật tài liệu 2–3 cho khớp “SQLite làm D2”, `main.py` thay `ApplicationController`, và ghi rõ FR **chart** là **tương lai** nếu cần.

---

*Lần 1: đối chiếu khái niệm. Lần 2: grep + đọc file như trên; không sửa `1_` / `2_` / `3_` gốc.*
