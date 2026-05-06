"""Core TxtGenerator — Sinh file báo cáo TXT theo Phụ lục 15, Thông tư 10/2021.

Format file TXT (5 trường mỗi dòng):
    Thông số, Kết quả, Đơn vị, Thời gian, Trạng thái thiết bị
"""

import logging
from datetime import datetime

from core._paths import DATA_DIR

logger = logging.getLogger("datalogger.txt_generator")
REPORT_DIR = DATA_DIR / "reports"
REPORT_DIR.mkdir(parents=True, exist_ok=True)


def generate_report(
    records: list[dict],
    sensor_order: list[dict],
    station_code: str,
    report_time: datetime | None = None,
) -> str:
    """Sinh file TXT báo cáo theo format Phụ lục 15.

    Args:
        records: Danh sách bản ghi sensor_data đã truy vấn.
            Mỗi dict: {"sensor_id": int, "value": float, "recorded_at": datetime}
        sensor_order: Danh sách sensor theo thứ tự report_index.
            Mỗi dict: {"id": int, "name": str, "unit": str, "report_index": int}
        station_code: Mã trạm (VD: "TRAM-BD-001").
        report_time: Thời điểm báo cáo, mặc định là datetime.now().

    Returns:
        Đường dẫn tuyệt đối đến file TXT đã tạo.
    """
    if report_time is None:
        report_time = datetime.now()

    # Định dạng tên file: TenTinh_TenCoso_TenTram_yyyyMMddhhmmss.txt
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

    logger.info("Đã tạo file báo cáo: %s (%d dòng)", filename, len(lines))
    return str(filepath)
