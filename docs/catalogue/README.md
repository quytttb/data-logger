# 4M Data Logger — catalogue & datasheet

Tài liệu giới thiệu bằng tiếng Việt cho **4M Data Logger**. Catalogue dùng ảnh chụp giao diện QML thực tế với dữ liệu demo; phối cảnh vỏ thiết bị là minh họa SVG, không phải ảnh sản phẩm cuối cùng.

## Tệp đầu ra

- `4M-DataLogger-Catalogue.pdf` — catalogue A4, 6 trang.
- `4M-DataLogger-Datasheet.pdf` — datasheet kỹ thuật A4, 2 trang.
- `catalogue.html`, `datasheet.html` — nguồn in.
- `assets/` — ảnh giao diện, font, logo, stylesheet và SVG minh họa.

Hướng dẫn vận hành riêng: [`../user-manual/4M-DataLogger-Huong-Dan-Su-Dung.pdf`](../user-manual/4M-DataLogger-Huong-Dan-Su-Dung.pdf), nguồn và cách tạo tại [`../user-manual/README.md`](../user-manual/README.md).

## Phong cách trình bày sau khi đọc tài liệu tham khảo

Đã xem toàn bộ bố cục 31 trang hướng dẫn EV-24, 2 trang KDES Introduction và 18 trang NAHACO/Gasmet do người dùng cung cấp. Tài liệu 4M giữ A4 dọc 6 + 2 trang, không đổi thành bộ slide ngang.

- EV-24: tham khảo nền trắng, chữ đậm dễ đọc, bảng thông số chia nhóm và ảnh UI có chú thích.
- KDES: tham khảo cách ghép hình sản phẩm với nội dung theo cột, ưu tiên thông tin kỹ thuật hơn trang trí.
- NAHACO/Gasmet: tham khảo thanh màu đầu trang, tiêu đề vừa phải, sơ đồ luồng và các bước triển khai đơn giản.
- Giữ logo/màu xanh 4M; không lấy hình, logo, chứng nhận, số đo hay thông số từ các tài liệu đó.

`assets/editorial.css` là lớp trình bày mới, tải sau `assets/style.css`. Nền tối và các hiệu ứng card/đổ bóng của bản đầu được thay bằng bố cục kỹ thuật nền trắng, chữ tối, đường phân cách và bảng thông số. Ảnh UI thực tế không bị vẽ lại.

## Xuất PDF

Yêu cầu Google Chrome/Chromium có hỗ trợ headless:

```bash
cd docs/catalogue
./build-pdf.sh
```

Lệnh này xuất PDF ngay trong thư mục này. Sau khi thay đổi layout, kiểm tra từng trang bằng `pdftoppm` hoặc trình xem PDF trước khi phát hành.

## Phạm vi thông số đã kiểm chứng

- 7 inch cảm ứng, 1024×600; nền tảng Raspberry Pi/ARM64; Qt 6.11/QML kiosk.
- Modbus RTU RS-485, các baud rate 1.200–115.200 bps, kiểu dữ liệu/byte order được liệt kê trong datasheet.
- SQLite WAL; phần mềm hiện giữ 30 ngày dữ liệu/báo cáo và 14 ngày log. **Điều 39.1.c TT10 yêu cầu ít nhất 60 ngày dữ liệu gần nhất**; tài liệu Rev. 1.1 ghi rõ yêu cầu cần nâng cấp, chưa tuyên bố phần mềm đã đáp ứng.
- Modbus TCP Server (cổng mặc định 5020), REST API (cổng mặc định 8080, Bearer token), FTP client.
- Báo cáo TXT theo định dạng Phụ lục 15 TT10/2021. Đây **không** là tuyên bố tuân thủ hoặc chứng nhận TT10.
- FTP hiện là FTP thường; không đưa ra tuyên bố SFTP.

Các nội dung này được đối chiếu với `README.md`, `docs/tt10-data-format.md` và mã nguồn hiện tại.

## Rà soát theo tài liệu sếp gửi — Rev. 1.1

Xem `TT10-REVIEW.md` để biết điều khoản, nguồn và các điểm cần xử lý trước nghiệm thu: lưu ≥ 60 ngày, cấu trúc TXT, trạng thái 00/01/02, chu kỳ ≤ 05 phút, GMT+7, truyền bù và kiểm soát truy cập. Chỉ sửa tài liệu trong đợt này, không sửa mã ứng dụng. Mẫu TXT trong catalogue là mẫu yêu cầu Phụ lục 15, không phải tệp xuất của bộ ghi hiện tại.

Chỉnh sửa trực tiếp hai HTML và `assets/style.css`; không chạy lại các script tạo bản cũ trong `/tmp/opencode/tools/`, vì sẽ ghi đè nội dung rà soát.

## Bắt buộc xác nhận trước khi phát hành thương mại

Không suy diễn hoặc tự điền các giá trị dưới đây:

1. Kích thước tổng thể, kích thước khoét tủ, vật liệu vỏ và bản vẽ cơ khí.
2. Cấp bảo vệ IP, dải nhiệt độ/độ ẩm làm việc và yêu cầu EMC/an toàn điện.
3. Nguồn vào của phiên bản thương mại, công suất tiêu thụ và sơ đồ đấu dây.
4. Bố trí/cấu hình cổng vật lý, mã model và danh mục tùy chọn theo đơn hàng.
5. Ảnh sản phẩm vỏ hoàn thiện, thông tin liên hệ và nhận diện thương mại được duyệt.

Khi các dữ kiện trên đã được xác nhận, cập nhật cả datasheet, catalogue và thay thế chú thích “minh họa” tương ứng.
