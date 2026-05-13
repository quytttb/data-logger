#!/bin/bash
# Script Hỗ trợ Triển khai, OTA Updater và Setup ban đầu cho Data Logger

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="datalogger"

# ==========================================
# CÁC HÀM XỬ LÝ LÕI NGẦM (DÀNH CHO PI KHI CHẠY CI/CD HOẶC OTA)
# ==========================================

show_version() {
    if [ -f "$APP_DIR/VERSION" ]; then
        cat "$APP_DIR/VERSION"
    else
        echo "Unknown (VERSION file not found)"
    fi
}

install_service() {
    echo "[systemd] Creating datalogger.service..."
    # Write unit file
    cat <<SYS > /tmp/$SERVICE_NAME.service
[Unit]
Description=Data Logger App
After=network.target graphical.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/datalogger
Restart=always
RestartSec=5
StandardOutput=append:$APP_DIR/var/logs/service.log
StandardError=append:$APP_DIR/var/logs/service_err.log

[Install]
WantedBy=graphical.target
SYS
    # Install unit under /etc/systemd/system
    sudo mv /tmp/$SERVICE_NAME.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    echo "[systemd] Installed and started '$SERVICE_NAME' successfully."
    
    if [ ! -f "$APP_DIR/VERSION" ]; then
        echo "v1.0.0" > "$APP_DIR/VERSION"
    fi
}

run_ota() {
    PKG_FILE=$1
    if [ -z "$PKG_FILE" ] || [ ! -f "$PKG_FILE" ]; then
        echo "[Lỗi] File không tồn tại: $PKG_FILE"
        return 1
    fi

    echo "[OTA] Đang tiến hành cài đặt bản cập nhật từ $PKG_FILE..."

    case "$PKG_FILE" in
        *.deb)
            echo "[OTA] Nhận diện gói Debian (.deb). Cài qua apt/dpkg..."
            ABS_PKG="$(readlink -f "$PKG_FILE")"
            if command -v apt >/dev/null 2>&1; then
                sudo apt install -y "$ABS_PKG" || {
                    echo "[OTA] apt install thất bại, fallback dpkg + apt -f install..."
                    sudo dpkg -i "$ABS_PKG" || true
                    sudo apt -f install -y
                }
            else
                sudo dpkg -i "$ABS_PKG" || true
            fi
            echo "[OTA] Cập nhật .deb hoàn tất (postinst đã reload+restart service)."
            show_version
            return 0
            ;;
        *.tar.gz|*.tgz)
            echo "[OTA] Nhận diện tarball (.tar.gz). Dùng pipeline cũ làm fallback."
            ;;
        *)
            echo "[Lỗi] Định dạng không hỗ trợ: $PKG_FILE (chỉ .deb hoặc .tar.gz)"
            return 1
            ;;
    esac

    # ── Fallback path: legacy .tar.gz OTA ──────────────────────────────────
    echo "[OTA] Dừng dịch vụ $SERVICE_NAME..."
    sudo systemctl stop $SERVICE_NAME || echo "[OTA] Service chưa tồn tại hoặc đã dừng sẵn."

    echo "[OTA] Giải nén file thiết lập mới..."
    mkdir -p /tmp/datalogger_ota
    tar -xzf "$PKG_FILE" -C /tmp/datalogger_ota

    echo "[OTA] Cập nhật file..."
    rsync -av --progress /tmp/datalogger_ota/ $APP_DIR/ \
      --exclude 'config' \
      --exclude 'var' \
      --exclude 'logs' \
      --exclude '.venv' \
      --exclude '*.db'

    chmod +x $APP_DIR/deploy.sh
    chmod +x $APP_DIR/datalogger || true

    if [ -f /tmp/datalogger_ota/VERSION ]; then
        cp /tmp/datalogger_ota/VERSION $APP_DIR/VERSION
    fi

    rm -rf /tmp/datalogger_ota

    echo "[OTA] Start lại SystemD Service..."
    sudo systemctl daemon-reload
    sudo systemctl start $SERVICE_NAME

    echo "[OTA] Cập nhật thành công. Hệ thống đang chạy:"
    show_version
}

release_version() {
    echo "=== BẮT ĐẦU QUY TRÌNH RELEASE TỰ ĐỘNG ==="
    echo "Lưu ý: Chỉ chạy tùy chọn này khi đã commit & push toàn bộ code mới nhất lên branch main."
    read -p "1. Nhập phiên bản mới (VD: v1.0.1): " NEW_VERSION
    
    if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Cảnh báo: Định dạng version thường nên bắt đầu bằng 'v' và 3 số (vd: v1.0.1)"
    fi
    
    # Kiểm tra an toàn: Nếu Tag đã tồn tại thì huỷ bỏ
    if git rev-parse -q --verify "refs/tags/$NEW_VERSION" >/dev/null; then
        echo "[Lỗi] Phiên bản $NEW_VERSION đã tồn tại ở local/remote! Dừng thao tác để tránh xung đột."
        return
    fi
    
    read -p "2. Bạn có chắc chắn muốn phát hành tag Git $NEW_VERSION? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        RAW_VERSION="${NEW_VERSION#v}"
        
        # 1. Update version trong source code
        echo "Đang tự động cập nhật core/_version.py thành $RAW_VERSION..."
        sed -i "s/__version__ = .*/__version__ = \"${RAW_VERSION}\"/" "$APP_DIR/core/_version.py"
        
        # 2. Push commit thay đổi này lên main trước
        git add "$APP_DIR/core/_version.py"
        git commit -m "chore(release): bump version to $NEW_VERSION"
        git push origin main
        
        # 3. Tạo Tag & Trigger CI/CD
        echo "Đang tạo Git Tag $NEW_VERSION..."
        git tag $NEW_VERSION
        
        echo "Đang đẩy Tag $NEW_VERSION lên origin..."
        git push origin $NEW_VERSION
        
        echo "Hoàn tất! Pipeline CI/CD trên GitHub Actions sẽ bắt đầu build phiên bản $NEW_VERSION."
    else
        echo "Đã hủy thao tác."
    fi
}

# ==========================================
# XỬ LÝ DÒNG LỆNH (NON-INTERACTIVE - DÙNG TRÊN RASPBERRY PI KHI OTA)
# ==========================================
if [ "$1" == "--version" ]; then
    show_version
    exit 0
elif [ "$1" == "--ota" ]; then
    run_ota "$2"
    exit 0
elif [ "$1" == "--service" ]; then
    install_service
    exit 0
fi

# ==========================================
# GIAO DIỆN INTERACTIVE LAPTOP DEV MENU
# ==========================================
echo ""
echo "==========================================="
echo "    DATA LOGGER - LAPTOP DEPLOY MANAGER    "
echo "==========================================="
echo " (Cảnh báo: Không chạy script này tương tác trên Pi)"
echo " 1. Release phiên bản mới (Tạo Git Tag -> Kích hoạt CI/CD Build Binary)"
echo " 2. Xem phiên bản code mã nguồn hiện tại"
echo " 3. Thoát"
echo "==========================================="

while true; do
    read -p "Chọn chức năng (1-3): " choice
    
    case $choice in
        1) 
            release_version 
            ;;
        2) 
            echo -n "Phiên bản hiện tại file _version.py: "
            python -c "import core._version as v; print(v.__version__)" 2>/dev/null || echo "Unknown"
            echo ""
            ;;
        3)
            echo "Thoát chương trình. Tạm biệt!"
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ. Vui lòng chọn (1-3)."
            ;;
    esac
done
