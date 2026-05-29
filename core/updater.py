import json
import urllib.request
import subprocess
import logging

from PySide6.QtCore import QObject, Signal, Slot, QThread
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
            self.progress.emit(10, "Checking for a newer version…")
            req = urllib.request.Request(self.repo_api, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req) as response:
                if response.status != 200:
                    self.finished.emit(False, "Could not reach GitHub API.")
                    return
                data = json.loads(response.read().decode("utf-8"))

            latest_version = data.get("tag_name", "").lstrip("v")
            current_version = get_current_version()

            if latest_version <= current_version:
                self.finished.emit(
                    True, f"You are already on the latest version (v{current_version})."
                )
                return

            self.progress.emit(30, f"New version found: v{latest_version}. Downloading…")
            assets = data.get("assets", [])
            if not assets:
                self.finished.emit(False, "No build asset found in the GitHub release.")
                return

            download_url = assets[0]["browser_download_url"]
            temp_tar = ROOT_DIR / f"update_v{latest_version}.tar.gz"

            urllib.request.urlretrieve(download_url, temp_tar)
            self.progress.emit(70, "Extracting and applying the update…")

            # Gọi script thay thế / deploy hỗ trợ shell execution
            rc = subprocess.run(
                ["bash", str(ROOT_DIR / "deploy.sh"), "--ota", str(temp_tar)],
                capture_output=True,
                text=True,
            )
            if rc.returncode == 0:
                self.progress.emit(100, "Update applied (restart pending).")
                self.finished.emit(
                    True, "OTA update completed successfully. Please restart the application."
                )
            else:
                self.finished.emit(False, f"OTA deploy failed: {rc.stderr}")

        except Exception as e:
            logger.error(f"OTA Error: {e}", exc_info=True)
            self.finished.emit(False, f"Update failed: {e}")


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
        """Start update check (caller should confirm in UI, e.g. MessagePopup in QML)."""
        if self._worker and self._worker.isRunning():
            return
        self.updateStarted.emit()
        self._worker = UpdaterWorker(self.repo)
        self._worker.progress.connect(self.progressChanged)
        self._worker.finished.connect(self._on_finished)
        self._worker.start()

    def _on_finished(self, success, msg):
        self.updateComplete.emit(success, msg)
        self._worker = None
