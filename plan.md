# Kế hoạch: phân quyền, audit log và hiệu chuẩn đa điểm

> Trạng thái: **đã triển khai mã và test các phase 0–4; chưa build/chạy test
> trên Raspberry Pi**. Kiểm thử phần cứng và vận hành dưới đây vẫn bắt buộc;
> tài liệu này không phê duyệt thay đổi contract chia sẻ.

## Mục tiêu và phạm vi

Bổ sung cho Data Logger giám sát **khí thải nhà máy nhiệt điện** ba ý tưởng từ firmware tham khảo: phân quyền người dùng trên kiosk, nhật ký thao tác và hiệu chuẩn tuyến tính đa điểm. Không chuyển các phần dành cho nước thải (sampler, cân, driver hiệu chuẩn riêng), không port nguyên UI/DB Qt5.

Trước triển khai repo chưa có tài khoản/role/audit; `LockScreen.qml` là màn
**khóa thiết bị theo license**, không phải màn đăng nhập. Trước đây các mode
`Linear`/`Two-point mapping` đều lưu `sensor.coefficient={"a":...,"b":...}`;
`Formula::applyFormula` áp dụng `a*raw+b`. Không thể khôi phục điểm hiệu chuẩn
từ hệ số cũ.

## 1. Phân quyền người dùng (RBAC)

- Đề xuất ba vai trò cố định ban đầu: **viewer** (xem), **operator** (xem và thực hiện hiệu chuẩn nếu được duyệt), **admin** (cấu hình cảm biến/trạm, tài khoản và phân quyền). Chưa thêm `root` hoặc quyền `sample.do` không liên quan khí thải.
- Định nghĩa ma trận quyền theo **thao tác thực tế** (xem dữ liệu, hiệu chuẩn, sửa cảm biến, sửa cấu hình hệ thống, quản lý tài khoản, xem audit); thống nhất ai có quyền hiệu chuẩn trước khi code. Không chỉ ẩn nút: mọi lệnh ghi từ QML/C++ phải kiểm tra quyền tại điểm thực thi, kể cả đường gọi trực tiếp vào controller.
- Thêm schema tài khoản/role và DAO qua `Database::openConnection`/`ScopedDbConnection`; migration idempotent, prepared statements. Mật khẩu **băm một chiều bằng password KDF phù hợp** (ưu tiên Argon2id, cân nhắc thư viện/package ARM64 và phương án tương đương trước khi chọn), salt riêng; không dùng AES hay Base64 để lưu mật khẩu. Chặn brute force phù hợp kiosk, không log mật khẩu.
- Thiết kế khởi tạo admin lần đầu an toàn, đổi/reset mật khẩu, vô hiệu hóa tài khoản, chống xóa/vô hiệu hóa admin cuối cùng; phiên đăng nhập cục bộ trong RAM và tự khóa khi không hoạt động theo chính sách đã chốt. Tạo màn đăng nhập **riêng**, không thay ý nghĩa màn khóa license hiện tại; kiểm tra hành vi khi app tự khởi động lại sau mất điện.
- REST Bearer hiện là credential **thiết bị** của Central, không phải một người dùng kiosk. Giữ nguyên `/api/v1/config`, `/api/v1/readings`, token và QR v1; **không tự gắn local RBAC/403 vào các endpoint đang chạy**. Nếu sau này cần danh tính người thao tác từ xa thì thiết kế contract/version mới và xin phép trước.

## 2. Audit log

- Bảng `audit_log` gồm thời điểm, actor (user cục bộ hoặc `system`/`remote_device`), hành động, đối tượng, kết quả và bản tóm tắt thay đổi; giữ ID/tên hiển thị của actor khi tài khoản bị đổi tên hoặc vô hiệu hóa. Ghi đăng nhập thành công/thất bại, đăng xuất, quản lý tài khoản, thay đổi cấu hình cảm biến/hệ thống và **lưu/áp dụng hiệu chuẩn**. Không biến log đo cảm biến hoặc mỗi lần tạo báo cáo thành audit sự kiện người dùng.
- Lưu dấu vết cũ/mới ở dạng whitelist trường cần truy vết; **loại trừ** password/hash, REST token, mật khẩu FTP, QR và dữ liệu nhạy cảm tương tự. Ghi sự kiện tại luồng nghiệp vụ có actor/context rõ ràng, không gắn mù vào mọi `DAO::save`.
- Với thay đổi cấu hình/hiệu chuẩn, ưu tiên ghi thay đổi và audit **trong cùng transaction** để tránh thành công mà không có dấu vết; xác định chính sách khi ghi audit thất bại (không được báo thao tác thành công sai). SQLite vẫn dùng WAL và không blocking I/O dài trên UI thread.
- Màn xem/lọc/phân trang audit trong kiosk, chỉ người có quyền xem audit mới được truy cập; không thêm REST audit endpoint mặc định. Retention/giới hạn dung lượng, quyền export và mức bảo đảm chống sửa log cần chốt trước khi triển khai. Không gọi log là bất biến tuyệt đối nếu admin hệ điều hành vẫn có quyền sửa SQLite.

## 3. Thay thế hiệu chuẩn hai điểm bằng hiệu chuẩn đa điểm

- **Một luồng nhập 2..N cặp** `(raw, giá trị chuẩn)`, tính đường thẳng `y = a*x + b` bằng bình phương tối thiểu. Với đúng 2 điểm và hai raw khác nhau, kết quả phải tương đương `Two-point mapping` hiện tại; không thêm mode hai điểm thứ hai.
- Đề xuất UI mới gồm `No scaling`, **Hiệu chuẩn tuyến tính (2..N điểm)** và `Advanced JSON`. Bỏ UI `Linear`/`Two-point mapping` riêng sau khi có phương án hiển thị/sửa **hệ số `a,b` nhập tay** hiện có: có thể đặt mục nhập tay trong cùng màn hiệu chuẩn, hoặc giữ lối nhập JSON nâng cao; không ép tạo điểm giả từ `a,b`. Chốt UX này trước khi loại bỏ mode cũ.
- Lưu điểm hiệu chuẩn và metadata (sensor, người thực hiện, thời điểm, ghi chú/nguồn chuẩn nếu cần) **riêng**; tiếp tục ghi `sensor.coefficient={"a":...,"b":...}` để runtime `Formula` không phải hồi quy ở mỗi lần poll và giữ tương thích dữ liệu cũ. Tính toán/kiểm tra ở C++, không đặt nghiệp vụ trong QML. Không tự suy diễn `{"coeffs":...}` legacy thành điểm khi chưa xác minh định dạng và runtime hỗ trợ.
- UI cho thêm/xóa/sửa điểm, xem `a`, `b`, R² và sai số từng điểm, xác nhận trước khi **áp dụng**; R² chỉ phản ánh độ khớp, **không phải chứng nhận đạt chuẩn**. Kiểm tra N≥2, raw đủ biến thiên, dữ liệu hữu hạn, tràn số, sai số và độ chính xác hiển thị; quyết định giới hạn N theo nhu cầu vận hành/màn 7 inch, không mặc định cứng 2..5.
- Migration idempotent giữ nguyên mọi `coefficient` cũ. Dữ liệu chỉ có `a,b` mở lại ở trạng thái **hệ số hiện hành, chưa có điểm gốc**, không làm thay đổi kết quả đo; cấu hình JSON không hiểu rõ giữ nguyên để chỉnh trong Advanced, không âm thầm làm mất dữ liệu. Lưu điểm + cập nhật hệ số + audit cùng transaction, kiểm tra khi xóa cảm biến và khi áp dụng hệ số mới trong worker.

## Trình tự triển khai đề xuất

1. **Thiết kế và nền dữ liệu:** chốt ma trận quyền/chính sách vận hành; migration bảng tài khoản, audit, điểm hiệu chuẩn; kiểm tra backup/rollback DB và tương thích cấu hình cũ. Chọn KDF sau khi xác nhận khả năng đóng gói trên Pi.
2. **Auth/RBAC:** DAO, login/session, màn đăng nhập riêng, guard backend + UI, test các đường ghi và khởi tạo admin/khóa thiết bị.
3. **Audit:** writer + transaction tại các luồng ghi trọng yếu, màn tra cứu và chính sách retention; test không lộ secret, thất bại ghi và truy cập trái quyền.
4. **Hiệu chuẩn:** thuật toán hồi quy, DAO/metadata, thay form cũ bằng luồng 2..N điểm, nối audit và runtime `a,b`; test tính tương đương N=2, N>2, dữ liệu sai, mở/lưu cấu hình cũ.
5. **Tích hợp:** Qt Test + CTest, kiểm thử kiosk/Pi (restart/mất điện giữa ghi), xác nhận báo cáo TT10/FTP, REST/QR v1 và Modbus map v1 **không đổi**; cập nhật README/CHANGELOG/tài liệu vận hành khi triển khai.

## Quyết định và xác minh còn lại

- Operator được áp dụng hiệu chuẩn trực tiếp; chỉ admin xem audit. Không có
  bước duyệt riêng. Lưu nhiều phiên; nhập `a,b` thủ công ở form cảm biến của
  admin, không tạo điểm giả từ hệ số.
- Tạo admin lần đầu trên kiosk; mật khẩu PBKDF2-HMAC-SHA256 600.000 vòng,
  tối thiểu 8 ký tự có chữ và số; khóa phiên sau 5 phút không hoạt động.
  Năm lần đăng nhập sai khóa 60 giây và tăng dần tới tối đa 15 phút.
- Giữ audit 365 ngày, chưa hỗ trợ export hay chống sửa bởi admin hệ điều hành;
  không ghi token/mật khẩu/ghi chú tự do hoặc JSON hệ số tùy ý vào audit.
- Đã thêm test Qt Test/CTest và kiểm tra cú pháp/lint; **chưa chạy build/test**.
  Cần thực hiện trên Pi: test tự động, hiệu chuẩn khi polling, khởi động lại và
  ngắt điện giữa transaction, độ trễ KDF, kiểm tra TT10/FTP và Central. Chỉ
  xác nhận tương thích thực tế sau khi các bước này thành công.

**Ranh giới contract:** mọi thay đổi Provision QR v1, REST `/api/v1/config` + `/api/v1/readings` hoặc Modbus TCP map v1 cần người dùng đồng ý rõ ràng và cập nhật cả tài liệu edge/Central; kế hoạch hiện tại không thay đổi các contract này.
