import logging
import logging.handlers
import gzip
import shutil
import os
import tomllib
from pathlib import Path
from core._paths import ROOT_DIR, LOG_DIR


def _namer(default_name: str) -> str:
    """Thêm đuôi .gz cho các file log cũ."""
    return default_name + ".gz"


def _rotator(source: str, dest: str) -> None:
    """Nén file log bằng gzip khi xoay vòng (rotate)."""
    with open(source, "rb") as f_in:
        with gzip.open(dest, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)
    os.remove(source)


def setup_logging() -> None:
    # Đọc config.toml
    from core._paths import CONFIG_DIR

    config_path = CONFIG_DIR / "config.toml"
    log_level = logging.INFO
    log_file = LOG_DIR / "app.log"
    max_bytes = 5 * 1024 * 1024  # 5MB
    backup_count = 5

    try:
        if config_path.exists():
            with open(config_path, "rb") as f:
                cfg = tomllib.load(f)
                if "logging" in cfg:
                    log_cfg = cfg["logging"]
                    log_level = getattr(logging, log_cfg.get("level", "INFO").upper(), logging.INFO)
                    if "file" in log_cfg:
                        file_path_str = log_cfg["file"]
                        if file_path_str.startswith("/"):
                            log_file = Path(file_path_str)
                        else:
                            log_file = ROOT_DIR / file_path_str
    except Exception as e:
        print(f"Error reading config.toml for logging: {e}")

    # Tạo thư mục chứa log nếu chưa có
    log_file.parent.mkdir(parents=True, exist_ok=True)

    # Cấu hình RotatingFileHandler
    file_handler = logging.handlers.RotatingFileHandler(
        log_file, maxBytes=max_bytes, backupCount=backup_count, encoding="utf-8"
    )
    file_handler.namer = _namer
    file_handler.rotator = _rotator

    # Console handler
    stream_handler = logging.StreamHandler()

    # Apply configuration
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        handlers=[file_handler, stream_handler],
        force=True,  # Ghi đè các config có sẵn (cho Python 3.8+)
    )

    logger = logging.getLogger("datalogger")
    logger.info("Logging configured. Compressed rotation enabled.")
