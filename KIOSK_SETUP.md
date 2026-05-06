# Kiosk Mode Setup (Raspberry Pi OS Desktop)

Để cấu hình ứng dụng Data Logger tự động khởi động toàn màn hình (Kiosk mode) thay cho Desktop thông thường một cách sạch sẽ:

1. Tạo file autostart `/home/pi/.config/autostart/data-logger.desktop`:
```ini
[Desktop Entry]
Type=Application
Name=Data Logger
Exec=/home/pi/Documents/Projects/data-logger/.venv/bin/python /home/pi/Documents/Projects/data-logger/main.py --fullscreen
StartupNotify=false
Terminal=false
```

2. Đảm bảo ứng dụng chạy full-screen bằng flag `--fullscreen` (hoặc cấu hình tự động trong GUI).

3. Tắt màn hình chờ / tiết kiệm pin trên GUI:
Tạo hoặc sửa file `/etc/xdg/lxsession/LXDE-pi/autostart`:
```text
@xset s off
@xset -dpms
@xset s noblank
```

Chỉ cần khởi động lại máy, ứng dụng sẽ chạy đè lên UI Pi OS thông thường trong chế độ toàn màn hình.
