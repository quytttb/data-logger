# Hướng dẫn sử dụng 4M Data Logger

- `4M-DataLogger-Huong-Dan-Su-Dung.pdf`: bản A4 20 trang, Rev. A, ngày 23/10/2026.
- `build_manual.py`: nội dung gốc và bộ tạo HTML; sửa nội dung ở đây để không bị mất khi tạo lại.
- `huong-dan-su-dung.html`: nguồn in được tạo từ script.
- `manual.css`: bố cục hướng dẫn nền trắng, chữ rõ, bảng và hình có chú thích.

Xuất lại: `bash docs/user-manual/build-pdf.sh` từ thư mục gốc repo. Cần Python 3 và Google Chrome; có thể đặt `CHROME_BIN`. Ảnh/font/logo dùng chung với `docs/catalogue/assets/`, không nhân bản tài nguyên. Khi di chuyển bộ nguồn, giữ cả hai thư mục; PDF xuất ra là tệp độc lập.

## Cách tham khảo tài liệu OSG

Đã đọc hướng dẫn OSG EV-24 31 trang người dùng cung cấp. Giữ cách tổ chức tổng quan, cấu hình, từng nhóm thao tác với nhãn trường, ảnh màn hình và chú thích. Không sao chép ảnh, thông số, logo, nội dung văn bản hay tính năng riêng của OSG (4–20 mA trực tiếp, website vận hành, lấy mẫu, SMS/email...). Không coi các tính năng trong tài liệu OSG là đã có trên 4M.

## Căn cứ và giới hạn

Đối chiếu README, CHANGELOG, tài liệu TT10/provision QR, QML các màn hình và C++ Controller/DAO/RetentionWorker của repo tại ngày soạn. Đặc biệt:

- Nút Save/Cancel và các thao tác ghi ngay ở Settings/Transmission/Digital I/O.
- Xóa cảm biến xóa cả `sensor_data` liên quan (`SensorDao`).
- Tester tạm dừng Monitor và trả quyền serial khi Disconnect.
- History có 5 cột, tối đa 2.000 mẫu và có cache; không hướng dẫn xuất CSV/USB không có trên UI.
- Trending rời tab sẽ clear chế độ lịch sử; không mô tả nút Live không tồn tại ở bản hiện tại.
- Lưu dữ liệu hiện vẫn 30 ngày, yêu cầu TT10 ít nhất 60 ngày; cần nâng cấp và kiểm thử trước nghiệm thu.
- Bộ ghi TXT/trạng thái, truyền bù, quyền truy cập cần nghiệm thu riêng; xem `../catalogue/TT10-REVIEW.md`.

Ảnh Monitor/History/Sensors là ảnh UI thật đã chụp ở đợt catalogue với dữ liệu demo. Vỏ thiết bị là minh họa. Các trang cấu hình khác hướng dẫn bằng nhãn trường đã đọc từ QML, không giả lập ảnh màn hình và không chứa token/QR/mật khẩu thật.

Đây là **bản dự thảo cần chạy thử trên thiết bị bàn giao**, chưa phải xác nhận đã thử thành công mọi quy trình trên phần cứng. Thông tin nguồn, đấu dây, gá lắp, số cổng, IP, nhiệt độ và liên hệ phải theo hồ sơ dự án; không tự thêm thông số chưa xác nhận.
