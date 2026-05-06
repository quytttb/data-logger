import json
import urllib.request
import subprocess
import logging

from PySide6.QtCore import QObject, Signal, Slot, QThread
from PySide6.QtWidgets import QMessageBox
from core._paths import ROOT_DIR

logger = logging.getLogger("datalogger.updater")

def get_current_version() -> str:
    version_file = ROOT_DIR / "VERSION"
    if version_file.exists():
        with open(version_file, "r") as f:
            return f.read().strip()
    try:
        from core._version import __version__
        return __version__
    except ImportError:
        return "0.0.0"

class UpdaterWorker(QThread):
    progress = Signal(int, str)
    finished = Signal(bool, str)

    def __init__(self, repo_url: str):
        super().__init__()
        self.repo_api = f"https://api.github.com/repos/{repo_url}/releases/latest"
        
    def run(self):
        try:
            self.progress.emit(10, "Kiểm tra phiên bản mới...")
            req = urllib.request.Request(self.repo_api, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response:
                if response.status != 200:
                    self.finished.emit(False, "Lỗi kết nối GitHub API.")
                    return
                data = json.loads(response.read().decode('utf-8'))
                
            latest_version = data.get("tag_name", "").lstrip("v")
            current_version = get_current_version()
            
            if latest_version <= current_version:
                self.finished.emit(True, f"Đang ở bản mới nhất (v{current_version}).")
                return

            self.progress.emit(30, f"Phát hiện bản mới: v{latest_version}. Đang tải...")
            assets = data.get("assets", [])
            if not assets:
                self.finished.emit(False, "Không tìm thấy file build trong Release.")
                return
                
            download_url = assets[0]["browser_download_url"]
            temp_tar = ROOT_DIR / f"update_v{latest_version}.tar.gz"
            
            urllib.request.urlretrieve(download_url, temp_tar)
            self.progress.emit(70, "Đang bung nén và áp dụng bản cập nhật...")

            # Gọi script thay thế / deploy hỗ trợ shell execution
            rc = subprocess.run(["bash", str(ROOT_DIR / "deploy.sh"), "--ota", str(temp_tar)], capture_output=True, text=True)
            if rc.returncode == 0:
                self.progress.emit(100, "Cập nhật thành công (Chờ Restart)!")
                self.finished.emit(True, "Đã cập nhật OTA thành công. Sẽ khởi động lại.")
            else:
                self.finished.emit(False, f"Lỗi Deploy OTA: {rc.stderr}")

        except Exception as e:
            logger.error(f"OTA Error: {e}", exc_info=True)
            self.finished.emit(False, f"Cập nhật thất bại: {e}")

class AppUpdater(QObject):
    updateStarted = Signal()
    progressChanged = Signal(int, str)
    updateComplete = Signal(bool, str)

    def __init__(self, repo="quytttb/data-logger", parent=None):
        super().__init__(parent)
        self.repo = repo
        self._worker = None

    @Slot()
    def checkForUpdates(self):
        if self._worker and self._worker.isRunning():
            return
        
        # Đặt QMessageBox confirm
        reply = QMessageBox.question(
            None,
            "Xác nhận cập nhật OTA",
            "Hệ thống sẽ kiểm tra và cài đặt phiên bản mới nhất từ GitHub. Quá trình này có thể khởi động lại phần mềm. Bạn có muốn tiếp tục?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )

        if reply == QMessageBox.Yes:
            self.updateStarted.emit()
            self._worker = UpdaterWorker(self.repo)
            self._worker.progress.connect(self.progressChanged)
            self._worker.finished.connect(self._on_finished)
            self._worker.start()

    def _on_finished(self, success, msg):
        self.updateComplete.emit(success, msg)
        self._worker = None
        if success and "thành công" in msg:
            QMessageBox.information(None, "Cập nhật OTA", msg)
        elif not success:
            QMessageBox.critical(None, "Cập nhật OTA thất bại", msg)
