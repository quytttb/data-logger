#!/bin/bash
# Script Hỗ trợ OTA Updater và Setup ban đầu

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="datalogger"

if [ "$1" == "--version" ]; then
    if [ -f "$APP_DIR/VERSION" ]; then
        cat "$APP_DIR/VERSION"
    else
        echo "Unknown (VERSION file missing)"
    fi
    exit 0
fi

if [ "$1" == "--ota" ]; then
    TAR_FILE=$2
    echo "[OTA] Đang tiến hành cài đặt bản cập nhật từ $TAR_FILE..."
    
    # 1. Tắt dịch vụ an toàn
    echo "[OTA] Dừng dịch vụ $SERVICE_NAME..."
    sudo systemctl stop $SERVICE_NAME || echo "[OTA] Service chưa tồn tại hoặc đã dừng sẵn."
    
    # 2. Xóa code cũ ngoại trừ db, config, var
    echo "[OTA] Giải nén file thiết lập mới..."
    mkdir -p /tmp/datalogger_ota
    tar -xzf "$TAR_FILE" -C /tmp/datalogger_ota

    # Backup (optional, có thể zip thư mục cũ nếu cần)
    
    echo "[OTA] Cập nhật file..."
    rsync -av --progress /tmp/datalogger_ota/ $APP_DIR/ \
      --exclude 'config' \
      --exclude 'var' \
      --exclude 'logs' \
      --exclude '.venv' \
      --exclude '*.db'
      
    chmod +x $APP_DIR/deploy.sh
    chmod +x $APP_DIR/datalogger || true
    
    # Copy VERSION file (RSync đã kéo qua nếu có, đảm bảo nó tồn tại)
    if [ -f /tmp/datalogger_ota/VERSION ]; then
        cp /tmp/datalogger_ota/VERSION $APP_DIR/VERSION
    fi
    
    rm -rf /tmp/datalogger_ota
    rm -f "$TAR_FILE"
    
    # 3. Bật lại dịch vụ
    echo "[OTA] Start lại SystemD Service..."
    sudo systemctl daemon-reload
    sudo systemctl start $SERVICE_NAME
    
    echo "[OTA] Thành công."
    exit 0

elif [ "$1" == "--service" ]; then
    echo "Creating SystemD service..."
    cat <<SYS > /tmp/$SERVICE_NAME.service
[Unit]
Description=Data Logger App
After=network.target graphical.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/datalogger
Restart=always
RestartSec=5
StandardOutput=append:$APP_DIR/var/logs/service.log
StandardError=append:$APP_DIR/var/logs/service_err.log

[Install]
WantedBy=graphical.target
SYS
    sudo mv /tmp/$SERVICE_NAME.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    echo "Service enabled."
    
    # Tạo VERSION file giả lập nếu chưa có
    if [ ! -f "$APP_DIR/VERSION" ]; then
        echo "1.0.0" > "$APP_DIR/VERSION"
    fi
    exit 0

else
    echo "Sử dụng:"
    echo "  ./deploy.sh --ota <file.tar.gz> # Chạy tự động cập nhật OTA"
    echo "  ./deploy.sh --service           # Cài SystemD service"
    echo "  ./deploy.sh --version           # Xem version hiện tại"
fi
