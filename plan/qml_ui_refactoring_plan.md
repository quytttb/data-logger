# Kế Hoạch Tái Cấu Trúc Giao Diện (QML UI Refactoring Plan)

## Mục tiêu
Dựa trên kiến trúc chuẩn của **Qt Quick Controls Gallery**, kế hoạch này nhằm tái cấu trúc lại giao diện QML của ứng dụng Data Logger để giải quyết 4 vấn đề cốt lõi: 
1. Hiệu năng (tránh tải toàn bộ giao diện vào RAM cùng lúc).
2. Tái sử dụng và quản lý Theme (tránh hardcode màu sắc).
3. Chuẩn hóa UX/UI bằng các Control bản địa (tránh tự phát minh lại control).
4. Tách biệt Logic & UI (không phụ thuộc vào chuỗi text hiển thị để xử lý logic).

---

## Giai đoạn 1: Cải thiện Kiến trúc & Điều hướng (Navigation)

### 1.1 Áp dụng Lazy-Loading cho Content Area
- Loại bỏ `StackLayout` đang nạp sẵn cả 4 View (`TesterView`, `DashboardView`, `HistoryView`, `SettingsView`).
- Thay thế bằng **`Loader`** (nếu muốn giữ nguyên kết cấu tĩnh) hoặc **`StackView`** (nếu muốn hiệu ứng chuyển trang).
  - *Đề xuất:* Dùng `Loader` kết hợp `source` trỏ tới file `.qml` tương ứng khi người dùng click vào Tab. Quá trình này giúp giải phóng RAM của các màn hình không hiển thị.

### 1.2 Dùng Control chuẩn cho Sidebar / Menu
- Thay thế block `Rectangle + Text + MouseArea` thủ công trong Repeater của Menu.
- Sử dụng **`ItemDelegate`** hoặc **`TabButton`** của Qt Quick Controls 2 để có sẵn hiệu ứng Hover, Click, Ripple Effect và hỗ trợ bàn phím/Accessibility tốt hơn.

---

## Giai đoạn 2: Cơ chế Theming & Quản lý Màu Sắc

### 2.1 Tạo file cấu hình Qt Quick Controls (`qtquickcontrols2.conf`)
- Thêm file `qtquickcontrols2.conf` vào resources đồ họa để khai báo Theme mặc định (Material/Universal) và màu Primary (`#558dff`), giúp các thành phần tiêu chuẩn (Button, CheckBox, Slider) tự động nhận màu thương hiệu mà không cần code.

### 2.2 Tạo kho màu trung tâm (`Theme.qml` Singleton)
- Gom toàn bộ mã màu hardcode (`#131313`, `#1c1b1b`, `#2a2a2a`, `#ff6666`, `#7dffa2`, `#b0c6ff`) vào một file `Theme.qml` (đăng ký dạng qmldir singleton).
- Trong các file QML khác, trỏ màu động: `color: Theme.background`, `color: Theme.accent`, `color: Theme.error`...
- Việc này tạo tiền đề nâng cấp tính năng **Light Theme / Dark Theme** chỉ bằng 1 nút bấm sau này.

---

## Giai đoạn 3: Tách biệt Logic Controller và View (Decoupling)

### 3.1 Chấm dứt dùng string matching trên View
- **Vấn đề cần fix:** Chỗ định ranh màu status đang dùng logic kiểm tra chuỗi `if (st.indexOf("MẤT") >= 0...)`.
- **Hành động (Python Backend):** Cập nhật `dashboard_controller.py` hoặc `report_controller.py` để bắn thêm các System Property quy định mã trạng thái.
  - Ví dụ: Thêm `statusMode` dạng Integer (0: Error, 1: OK, 2: Warning, 3: Stopped).
- **Hành động (QML Frontend):** Chuyển màu dựa trên `statusMode`:
  ```qml
  color: statusMode === 0 ? Theme.error : Theme.ok
  ```

---

## Giai đoạn 4: Chuẩn hóa trang con (Sub-Pages)

### 4.1 Đóng gói lại các File View
- Rà soát các file `DashboardView.qml`, `HistoryView.qml`, `SettingsView.qml`, `TesterView.qml`.
- Biến chúng thành các Component lỏng lẻo (Loosely coupled), không phụ thuộc ngược lại vào `Main.qml`. Các View con chỉ nên nhận Property Alias hoặc signal/slot để giao tiếp lên cấp cha.
- Áp dụng các tính năng Layout thông minh (`ColumnLayout`, `RowLayout`, `GridLayout`) thay vì dùng `anchors` thủ công ở những nơi không cần thiết để hỗ trợ responsive khi resize cửa sổ.

### 4.2 Cải tiến trải nghiệm người dùng (UX) trên Trang Cài Đặt (SettingsView)
- **Vấn đề:** Giao diện màn hình cảm ứng 7-inch khá nhỏ, việc nhồi nhét hai vùng "Báo cáo & FTP" và "Danh sách cảm biến" trên cùng một màn hình (cùng lúc hiển thị) gây chật chội, thao tác khó.
- **Giải pháp:** 
  - Sử dụng **`TabBar`** kết hợp **`SwipeView`** (hoặc Sidebar con) bên trong lớp `SettingsView.qml` để chia màn hình cài đặt thành 2 tab độc lập:
    - Tab 1: "Cấu hình chung / Báo cáo FTP"
    - Tab 2: "Quản lý / Danh sách Cảm Biến"
  - **Áp dụng Lazy-loading:** Bên trong mỗi Tab, sử dụng `Loader` để tải giao diện. Việc này giúp tab "Danh sách Cảm Biến" (có thể chứa nhiều component phức tạp) chỉ được nạp vào RAM khi người dùng thực sự bấm sang tab đó, tiết kiệm tài nguyên cho thiết bị nhúng.
- Điều này không chỉ nới rộng khoảng trống cho các nút chạm (touch target size) lớn hơn cho dễ bấm, mà còn giúp người dùng tập trung thông tin, tránh thao tác nhầm trên màn hình nhỏ.

### 4.3 Loại bỏ Control cũ và nâng cấp bộ CheckBox / ComboBox
- **Vấn đề:** Đang sử dụng các CheckBox, ComboBox nguyên bản, cũ hoặc không đồng nhất với tổng thể theme (thường xảy ra nếu quên không cấu hình Theme, hoặc dùng lộn control Quick 1).
- **Giải pháp:** Kiểm tra lại tất cả các module dùng `CheckBox`, `ComboBox`.
  - Khai báo ép kiểu chuẩn `QtQuick.Controls` (phiên bản 2) đồng loạt.
  - Tận dụng Material Design Material Theme từ file cấu hình `qtquickcontrols2.conf`. Cân nhắc đóng gói thành Component tùy chỉnh riêng (vd: `AppComboBox.qml`, `AppCheckBox.qml`) có đi kèm focus outline, hover effects nếu muốn giao diện nổi bật, mang chất riêng hơn.

---

## Quy trình thực hiện đề xuất

1. [ ] **Bước 1:** Tạo file `qtquickcontrols2.conf` và thiết lập basic theme. Nâng chuẩn các thành phần cơ bản (loại bỏ `CheckBox`, `ComboBox` cũ, chuyển qua QQC2) dựa theo Theme.
2. [ ] **Bước 2:** Cập nhật lại Backend Python để loại bỏ dependency của QML đối với tiếng Việt (trạng thái hệ thống).
3. [ ] **Bước 3:** Đập bỏ `StackLayout` trong `Main.qml`, cấu hình lại `Loader` / `StackView` + `ItemDelegate` cho menu sidebar.
4. [ ] **Bước 4:** Tạo Singleton `Theme.qml` và sửa lại toàn bộ hardcode color trên các view hiện tại để thống nhất kiểu dáng.
5. [ ] **Bước 5:** Đặc biệt tập trung tối ưu `SettingsView.qml`, sử dụng `TabBar` hoặc `SwipeView` chia chia nhỏ "Báo cáo / FTP" và "Quản lý Cảm Biến" để tăng độ thoáng cho màn cảm ứng (Giai đoạn 4.2).
6. [ ] **Bước 6:** Test độ mượt mà khi chuyển màn hình, kiểm tra thao tác chạm trên màn hình 7-inch thực tế và độ quản lý Memory.