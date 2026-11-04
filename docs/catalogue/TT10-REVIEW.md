# Rà soát tài liệu theo TT10/2021/TT-BTNMT — 22/10/2026

## Phạm vi và nguồn

Đối chiếu bản PDF người dùng cung cấp: `THAM_KHAO/thong tu 10-btnmt_2021.pdf`, đặc biệt Điều 39 (trang đánh số 44–46) và Phụ lục 15 (trang 101–105), với catalogue/datasheet và một số điểm mã nguồn liên quan. Không phải chứng nhận tuân thủ, không bao phủ toàn bộ hệ thống quan trắc, không xác minh tình trạng hiệu lực/sửa đổi pháp luật sau bản PDF này.

## Kết luận quan trọng: lưu ít nhất 60 ngày

**Điều 39 khoản 1 điểm c:** “Bảo đảm lưu giữ liên tục ít nhất là 60 ngày dữ liệu gần nhất.” Dữ liệu tối thiểu gồm thông số, kết quả, đơn vị, thời gian và trạng thái thiết bị đo.

Mã nguồn `src/network/workers/RetentionWorker.h` hiện đặt `kSensorDataKeepDays = 30`, `kReportKeepDays = 30`. Vì vậy không thể chỉ thay chữ 30 thành 60 rồi coi là đã đáp ứng. Bản tài liệu sửa ghi rõ **≥ 60 ngày là yêu cầu cấu hình**, còn phần mềm cần nâng cấp và kiểm thử trước nghiệm thu. Chưa sửa mã ứng dụng trong đợt sửa catalogue này. Dữ liệu từng bị xóa không thể khôi phục chỉ bằng tăng ngưỡng.

14 ngày log vận hành là chính sách riêng, không thay cho 60 ngày dữ liệu quan trắc. Yêu cầu 60 ngày không đồng nghĩa yêu cầu lưu camera: Điều 39.3.c quy định camera RTSP và lưu tối thiểu 03 tháng, thuộc phạm vi hệ thống cần bố trí riêng.

## Tệp TXT: mẫu tài liệu đã chỉnh, bộ ghi cần sửa riêng

- Phụ lục 15 mục 1: `TenTinh_TenCoSo_TenTram_Thoigian.txt`; mã cơ sở 4 ký tự; mã trạm 6 ký tự (NUO/KHI và 3 ký tự trạm). Mẫu catalogue trước đó thiếu mã cơ sở, đã sửa thành `HCM_ABCD_NUO001_20261022163156.txt`.
- Mục 2: 5 cột cách TAB, mỗi thông số một dòng trong cấu trúc mẫu. Thời gian dạng `yyyyMMddhhmmss` trong văn bản; dùng `yyyyMMddHHmmss` trong Qt để biểu diễn giờ 24h. Đã sửa thời gian trong ví dụ tài liệu; nhãn cột chỉ là hướng dẫn trình bày, không thuộc tệp TXT.
- Bảng 34: mẫu pH dùng đơn vị `-`, Flow dùng `m3/h`; đơn vị và ký hiệu thật phải cấu hình theo thông số/trạm và yêu cầu tiếp nhận. Không sửa hoặc vẽ lại đơn vị trên ảnh chụp UI.
- Bảng 35: `00` đang đo, `01` hiệu chuẩn, `02` báo lỗi. Mã `03` maintenance của ứng dụng không có trong bảng; cần quy tắc ánh xạ được chấp thuận trước khi gửi.
- `src/core/tt10/Tt10ReportWriter.cpp`: thời gian đã dùng `yyyyMMddHHmmss`, nhưng hiện gom mọi nhóm 5 trường vào **một dòng**, và cho mã `03` đi qua. Ví dụ trong tài liệu là mẫu yêu cầu, **không** phải ảnh/tệp đầu ra của bộ ghi hiện tại. Cần sửa và bổ sung test trước khi khẳng định đầu ra đáp ứng Phụ lục 15.

## Truyền dữ liệu và điều kiện triển khai cần nghiệm thu

- **Điều 39.2.a:** FTP hoặc FTPs hoặc sFTP; không bắt buộc phải hỗ trợ đồng thời cả ba. FTP thường của ứng dụng là một phương thức được nêu; không quảng cáo FTPS/SFTP. Đường truyền tối thiểu 30 Mb/s là yêu cầu triển khai.
- **Điều 39.2.b:** truyền chậm nhất sau 05 phút kể từ khi có kết quả; mỗi lần một tệp. Không dùng câu “lên lịch theo giờ” như thể mặc định đáp ứng. Cần cấu hình và đo thử chu kỳ, độ trễ thực tế. IP tĩnh cho hệ thống nước thải/khí thải là yêu cầu triển khai.
- **Điều 39.2.c:** đồng bộ GMT+7. Có NTP/timezone cấu hình được chưa chứng minh trạm đã cấu hình/đồng bộ đúng.
- **Điều 39.2.d:** tự truyền bù ngay sau phục hồi kết nối. Chưa kiểm thử end-to-end mất mạng/khôi phục; không khẳng định đã đáp ứng. Gián đoạn trên 12 giờ còn có nghĩa vụ thông báo của đơn vị vận hành.
- **Điều 39.1.đ:** hiển thị và trích xuất đủ thông tin, kể cả trạng thái đo. Cần nghiệm thu khả năng tra cứu/trích xuất 60 ngày, không chỉ xem ảnh màn hình.
- **Điều 39.4:** kiểm soát truy cập bằng tài khoản/mật khẩu, niêm phong cổng và quản lý quyền theo yêu cầu cơ quan quản lý. Bearer token REST hay khóa thiết bị không tự chứng minh đáp ứng đầy đủ yêu cầu này.
- **Điều 39.2.đ:** điều khiển lấy mẫu tự động từ xa (nếu có) cần kiểm tra trên cấu hình dự án; không suy từ DO chung.

## Nội dung chưa nên phát hành như tuyên bố thương mại

Chưa ghi “tuân thủ TT10” hoặc “đạt TT10” cho toàn sản phẩm. Cần xử lý chính sách lưu 60 ngày, cấu trúc TXT/trạng thái, truyền bù, cấu hình chu kỳ/GMT+7, quyền truy cập và nghiệm thu hệ thống. Vỏ, nguồn, IP, nhiệt độ và cổng vật lý vẫn phải xác nhận riêng.
