# Waveshare 7" (1024×600) trên Raspberry Pi OS Lite (full KMS)

Hướng dẫn cấu hình màn **Waveshare 7inch Capacitive Touch Screen LCD (C)** chạy
đúng độ phân giải native **1024×600** với Raspberry Pi dùng driver KMS hiện đại
(`dtoverlay=vc4-kms-v3d`).

## Vấn đề

- Board HDMI của màn Waveshare này **clone nguyên EDID** của một màn 1920×1080 khác
  (báo tên `LEN L1950wD`, kể cả kích thước vật lý). Vì vậy Pi mặc định chạy panel ở
  1080p rồi scale xuống → chữ bé, hơi mờ.
- Hướng dẫn cũ của Waveshare (`hdmi_group`, `hdmi_mode`, `hdmi_cvt`, `hdmi_drive`)
  là cho **driver HDMI legacy** và **bị bỏ qua** khi dùng full KMS.
- Ép mode bằng `video=HDMI-A-1:1024x600M@60` (CVT) bị **driver vc4 từ chối**
  (`User-defined mode not supported`).

## Giải pháp: override EDID của connector

Nạp một EDID tùy chỉnh chỉ quảng cáo đúng timing 1024×600@60 "sạch" mà vc4 chấp
nhận. File EDID và script tạo nằm ở `packaging/linux/edid/`.

### Các bước

1. Copy EDID vào firmware path của Pi:

```bash
sudo mkdir -p /lib/firmware/edid
sudo cp waveshare-1024x600.bin /lib/firmware/edid/
```

2. Thêm tham số sau vào **cuối dòng duy nhất** của `/boot/firmware/cmdline.txt`
   (giữ nguyên 1 dòng, ngăn cách bằng dấu cách):

```
drm.edid_firmware=HDMI-A-1:edid/waveshare-1024x600.bin,HDMI-A-2:edid/waveshare-1024x600.bin
```

   Khai báo cho **cả hai** cổng micro-HDMI để hoạt động bất kể cắm cổng nào. Cổng
   thực sự cắm màn sẽ `connected` và dùng EDID này; cổng trống tự `disconnected`
   (không tạo màn ảo).

3. Reboot.

### Kiểm tra

```bash
# Cổng cắm màn phải báo WS_1024x600 + mode 1024x600
for c in /sys/class/drm/*HDMI*; do \
  echo "$c -> $(cat $c/status) $(cat $c/edid | strings | grep WS_)"; done

# CRTC scan-out thực tế
sudo grep -E 'crtc-pos=[0-9]' /sys/kernel/debug/dri/*/state | grep -v '0x0+0+0'

# App eglfs phải chọn 1024x600
sudo QT_QPA_PLATFORM=eglfs QT_LOGGING_RULES="qt.qpa.eglfs.kms=true" \
  /usr/bin/DataLogger 2>&1 | grep -E 'Selected mode|framebuffer size'
```

Kỳ vọng: `Selected mode 0 : 1024 x 600 @ 60 hz`, framebuffer `QSize(1024, 600)`.

## Tạo lại EDID (nếu cần đổi timing)

```bash
cd packaging/linux/edid
python3 gen_waveshare_edid.py        # sinh lại waveshare-1024x600.bin
edid-decode waveshare-1024x600.bin   # (tuỳ chọn) kiểm tra hợp lệ
```
