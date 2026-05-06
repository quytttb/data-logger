#!/bin/bash
# Script Hỗ trợ Triển khai, OTA Updater và Setup ban đầu cho Data Logger

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="datalogger"

# ==========================================
# CÁC HÀM XỬ LÝ LÕI
# ==========================================

show_version() {
    if [ -f "$APP_DIR/VERSION" ]; then
        cat "$APP_DIR/VERSION"
    else
        echo "Unknown (Không tìm thấy file VERSION)"
    fi
}

install_service() {
    echo "[Service] Đang tạo SystemD service..."
    # Tạo file cấu hình service
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
    # Copy vào systemd
    sudo mv /tmp/$SERVICE_NAME.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    echo "[Service] Đã cài đặt và khởi động service '$SERVICE_NAME' thành công."
    
    if [ ! -f "$APP_DIR/VERSION" ]; then
        echo "v1.0.0" > "$APP_DIR/VERSION"
    fi
}

run_ota() {
    TAR_FILE=$1
    if [ -z "$TAR_FILE" ] || [ ! -f "$TAR_FILE" ]; then
        echo "[Lỗi] File không tồn tại: $TAR_FILE"
        return 1
    fi
    
    echo "[OTA] Đang tiến hành cài đặt bản cập nhật từ $TAR_FILE..."
    
    # 1. Dừng service an toàn
    echo "[OTA] Dừng dịch vụ $SERVICE_NAME..."
    sudo systemctl stop $SERVICE_NAME || echo "[OTA] Service chưa tồn tại hoặc đã dừng sẵn."
    
    # 2. Giải nén vào thư mục dùng một lần
    echo "[OTA] Giải nén file thiết lập mới..."
    mkdir -p /tmp/datalogger_ota
    tar -xzf "$TAR_FILE" -C /tmp/datalogger_ota

    # 3. Đồng bộ (rsync)
    echo "[OTA] Cập nhật file..."
    rsync -av --progress /tmp/datalogger_ota/ $APP_DIR/ \
      --exclude 'config' \
      --exclude 'var' \
      --exclude 'logs' \
      --exclude '.venv' \
      --exclude '*.db'
      
    chmod +x $APP_DIR/deploy.sh
    chmod +x $APP_DIR/datalogger || true
    
    # Kéo file VERSION (nếu rsync thiếu xót)
    if [ -f /tmp/datalogger_ota/VERSION ]; then
        cp /tmp/datalogger_ota/VERSION $APP_DIR/VERSION
    fi
    
    # Dọn dẹp
    rm -rf /tmp/datalogger_ota
    
    # 4. Start lại service
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
    
    read -p "2. Bạn có chắc chắn muốn phát hành tag Git $NEW_VERSION? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "Đang tạo Git Tag $NEW_VERSION..."
        git tag $NEW_VERSION
        
        echo "Đang đẩy Tag $NEW_VERSION lên origin..."
        git push origin $NEW_VERSION
        
        echo "Hoàn tất! Pipeline CI/CD trên GitHub Actions sẽ bắt đầu build phiên bản $NEW_VERSION."
    else
        echo "Đã hủy thao tác."
    fi
}

build_nuitka() {
    echo "=== XÂY DỰNG BINARY NUITKA THỦ CÔNG ==="
    echo "Phù hợp để test nhanh khi đang phát triển (dev) trên Raspberry Pi."
    read -p "Xác nhận build? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        nuitka3 --standalone --onefile \
            --include-data-dir=config=config \
            --include-data-dir=ui/qml=ui/qml \
            --plugin-enable=pyside6 \
            --output-filename=datalogger \
            main.py
        echo "Hoàn tất. File thực thi là 'datalogger'."
    else
        echo "Đã hủy."
    fi
}

# ==========================================
# XỬ LÝ MÔI TRƯỜNG DÒNG LỆNH (NON-INTERACTIVE)
# (Dùng cho ứng dụng tự động gọi)
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
# GIAO DIỆN INTERACTIVE (MENU)
# ==========================================
while true; do
    echo ""
    echo "==========================================="
    echo "    DATA LOGGER - DEPLOY & OTA MANAGER     "
    echo "==========================================="
    echo " 1. Release phiên bản mới (Git Tag -> CI/CD)"
    echo " 2. Build binary Nuitka thủ công trên Pi"
    echo " 3. Cài đặt SystemD service (--service)"
    echo " 4. Cập nhật OTA cài File thủ công (--ota)"
    echo " 5. Xem version hiện tại"
    echo " 6. Thoát"
    echo "==========================================="
    read -p "Chọn chức năng (1-6): " choice
    
    case $choice in
        1) release_version ;;
        2) build_nuitka ;;
        3) install_service ;;
        4)
            read -p "Nhập đường dẫn tới file .tar.gz (vd: /tmp/update.tar.gz): " tar_path
            run_ota "$tar_path"
            ;;
        5)
            echo -n "Phiên bản hiện hành: "
            show_version
            echo ""
            ;;
        6)
            echo "Thoát chương trình. Tạm biệt!"
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ."
            ;;
    esac
done
