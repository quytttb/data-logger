"""Core TxtGenerator — Sinh file báo cáo TXT theo Phụ lục 15, Thông tư 10/2021.

Format file TXT (5 trường mỗi dòng):
    Thông số, Kết quả, Đơn vị, Thời gian, Trạng thái thiết bị
"""

import logging
from datetime import datetime, timedelta

from core._paths import DATA_DIR

logger = logging.getLogger("datalogger.txt_generator")
REPORT_DIR = DATA_DIR / "reports"
REPORT_DIR.mkdir(parents=True, exist_ok=True)

# Giữ file báo cáo trên đĩa tối đa bao nhiêu ngày (theo mtime).
REPORT_RETENTION_DAYS = 60


def cleanup_old_report_files(max_age_days: int = REPORT_RETENTION_DAYS) -> int:
    """Xóa file *.txt trong thư mục báo cáo có thời điểm sửa (mtime) cũ hơn max_age_days.

    Returns:
        Số file đã xóa.
    """
    if max_age_days <= 0 or not REPORT_DIR.is_dir():
        return 0

    cutoff_ts = (datetime.now() - timedelta(days=max_age_days)).timestamp()
    removed = 0
    for path in REPORT_DIR.glob("*.txt"):
        try:
            if path.stat().st_mtime < cutoff_ts:
                path.unlink()
                removed += 1
                logger.debug("Removed report past retention: %s", path.name)
        except OSError as e:
            logger.warning("Retention cleanup skip %s: %s", path, e)

    if removed:
        logger.info(
            "Report retention: deleted %d file(s) older than %d day(s).",
            removed,
            max_age_days,
        )
    return removed


def generate_report(
    records: list[dict],
    sensor_order: list[dict],
    station_code: str,
    report_time: datetime | None = None,
    prefix: str = "",
    suffix_format: str = "yyyyMMddHHmmss",
) -> str:
    """Sinh file TXT báo cáo theo format Phụ lục 15.

    Args:
        records: Danh sách bản ghi sensor_data đã truy vấn.
            Mỗi dict: {"sensor_id": int, "value": float, "recorded_at": datetime}
        sensor_order: Danh sách sensor theo thứ tự report_index.
            Mỗi dict: {"id": int, "name": str, "unit": str, "report_index": int}
        station_code: Mã trạm (VD: "TRAM-BD-001").
        report_time: Thời điểm báo cáo, mặc định là datetime.now().
        prefix: Tiền tố tên file (VD: "TH_BSON_KHILO2__").
        suffix_format: Hậu tố thời gian (VD: "yyyyMMddHHmmss").

    Returns:
        Đường dẫn tuyệt đối đến file TXT đã tạo.
    """
    if report_time is None:
        report_time = datetime.now()

    # Chuyển đổi định dạng thời gian từ QML sang Python strftime
    suffix_fmt_python = suffix_format.replace("yyyy", "%Y").replace("MM", "%m").replace("dd", "%d").replace("HH", "%H").replace("mm", "%M").replace("ss", "%S")
    time_str = report_time.strftime(suffix_fmt_python)
    
    # Định dạng tên file: {prefix}{time_str}.txt
    filename = f"{prefix}{time_str}.txt"
    # Fallback to default if prefix is empty and suffix is empty
    if not filename.replace(".txt", ""):
        filename = f"{station_code}_{report_time.strftime('%Y%m%d%H%M%S')}.txt"
        
    filepath = REPORT_DIR / filename

    sensor_map = {s["id"]: s for s in sensor_order}

    lines: list[str] = []
    for record in sorted(records, key=lambda r: r["recorded_at"]):
        sid = record["sensor_id"]
        sensor_info = sensor_map.get(sid)
        if sensor_info is None:
            continue

        name = sensor_info["name"]
        unit = sensor_info.get("unit", "")
        val = record["value"]
        val_str = f"{val:.4f}" if val is not None else ""
        ts = record["recorded_at"]
        ts_str = ts.strftime("%Y%m%d%H%M%S") if isinstance(ts, datetime) else str(ts)
        
        # Xác định trạng thái báo cáo phụ lục thiết bị
        status_code = record.get("status")
        if status_code is None:
            status_code = "00" if val is not None else "02"
            
        lines.append(f"{name}\t{val_str}\t{unit}\t{ts_str}\t{status_code}")

    content = "\n".join(lines)
    filepath.write_text(content, encoding="utf-8")

    logger.debug("Generated report file: %s (%d lines)", filename, len(lines))
    return str(filepath)
