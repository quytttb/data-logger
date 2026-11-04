#!/usr/bin/env python3
"""Tạo HTML hướng dẫn sử dụng từ nội dung đã đối chiếu mã nguồn 4M."""
from pathlib import Path
from html import escape

HERE = Path(__file__).resolve().parent
PAGES = []


def table(headers, rows, compact=False):
    return '<table' + (' class="compact"' if compact else '') + '><thead><tr>' + ''.join(
        '<th>' + h + '</th>' for h in headers
    ) + '</tr></thead><tbody>' + ''.join(
        '<tr>' + ''.join('<td>' + cell + '</td>' for cell in row) + '</tr>' for row in rows
    ) + '</tbody></table>'


def steps(items):
    return '<ol>' + ''.join('<li>' + item + '</li>' for item in items) + '</ol>'


def callout(label, text, kind='note'):
    return f'<div class="{kind}"><b>{label}</b> {text}</div>'


def path(text):
    return f'<div class="path">{text}</div>'


def shot(name, caption):
    return f'<figure><img src="../catalogue/assets/{name}" alt="{escape(caption)}"><figcaption>{caption} Ảnh chụp UI thật, dữ liệu demo; không phải dữ liệu trạm đang vận hành.</figcaption></figure>'


def add(title, chapter, body, cover=False):
    PAGES.append((title, chapter, body, cover))


add('HƯỚNG DẪN SỬ DỤNG', 'Tài liệu vận hành', '''
<div class="product">4M Data Logger</div>
<p class="subtitle">Thiết bị thu thập, lưu trữ và truyền dữ liệu quan trắc môi trường.<br>Phiên bản màn hình cảm ứng 7 inch.</p>
<img class="hero" src="../catalogue/assets/device-mockup.svg" alt="Phối cảnh minh họa thiết bị 4M, sử dụng ảnh UI thật">
<p class="small">Hình vỏ thiết bị là minh họa; kích thước, vật liệu và đấu nối theo hồ sơ cấu hình bàn giao.</p>
<div class="doc-data"><p><b>Mã tài liệu:</b> 4M-DL-UM · <b>Phiên bản:</b> Rev. A · <b>Ngày soạn:</b> 23/10/2026</p>
<p><b>Đối tượng:</b> nhân viên vận hành và kỹ thuật viên được phân công.</p>
<p><b>Trạng thái:</b> bản dự thảo đối chiếu phần mềm, cần chạy thử trên thiết bị bàn giao.</p></div>
<div class="warning"><b>Lưu ý trước sử dụng:</b> bản phần mềm được đối chiếu hiện giữ dữ liệu 30 ngày, chưa đáp ứng yêu cầu ít nhất 60 ngày của Điều 39.1.c TT10. Các điểm cần nâng cấp/kiểm thử được nêu ở trang 19. Không dùng tài liệu này như chứng nhận tuân thủ.</div>
''', cover=True)

# Mục lục được tạo sau khi đủ trang; số trang không nhập tay.
add('Mục lục & cách đọc', 'Tra cứu nhanh', '')

add('Tổng quan & chuẩn bị lắp đặt', '01 · Trước khi vận hành', '''
<p class="intro">4M Data Logger đọc cảm biến/analyser qua Modbus RTU RS-485, hiển thị tại trạm, ghi dữ liệu cục bộ và gửi báo cáo TXT qua FTP. Modbus TCP Server và REST API phục vụ tích hợp hệ thống tập trung.</p>
<div class="flow"><div><b>Cảm biến / analyser</b><em>Modbus RTU · RS-485</em></div><div><b>4M Data Logger</b><em>Đo · lưu · hiển thị · báo cáo</em></div><div><b>Hệ thống tiếp nhận</b><em>FTP · Modbus TCP · REST</em></div></div>
''' + table(['Hạng mục', 'Nội dung cần xác nhận'], [
('Thiết bị', 'Màn hình 7 inch, 1024 × 600; nền tảng Raspberry Pi/ARM64. Model phần cứng và phụ kiện theo hồ sơ bàn giao.'),
('Nguồn & mặt tủ', 'Dùng đúng nguồn theo nhãn/bản vẽ được duyệt; không tự suy điện áp nguồn vào từ module xử lý. Không dùng kích thước hình minh họa để khoét tủ.'),
('RS-485', 'Xác định A/B và dây tham chiếu theo tài liệu của bộ chuyển đổi và thiết bị đo; không tự đảo dây khi đang cấp điện.'),
('Thông số truyền', 'Chuẩn bị slave ID, baudrate, parity, data bits, stop bits; register map của từng cảm biến.'),
('Máy chủ', 'Nhận địa chỉ, tài khoản FTP, đường dẫn được phép ghi và cấu hình mạng từ đơn vị phụ trách.'),
('Hồ sơ', 'Lưu bản cấu hình ban đầu và danh sách kênh đo, đơn vị, hệ số, ngưỡng đã được duyệt.'),
]) + callout('An toàn điện:', 'Ngắt và cô lập nguồn trước đấu dây. Chỉ kỹ thuật viên có thẩm quyền được thao tác trong tủ; không nối trực tiếp tải công suất vào cổng tín hiệu nếu chưa có thiết kế giao tiếp phù hợp.', 'warning') + '''
<h2>Phạm vi không được suy diễn</h2>
<p>ANALOG trong ứng dụng là kênh giá trị số đọc qua Modbus, không mặc nhiên là đầu vào vật lý 4–20 mA. DI/DO là các kênh Modbus; số cổng, relay thực, cấp IP, công suất và điều kiện môi trường phải theo cấu hình phần cứng.</p>
''')

add('Khởi động & thao tác cơ bản', '02 · Đưa thiết bị vào làm việc', '''
<h2>2.1. Khởi động lần đầu</h2>
''' + steps([
'Kiểm tra nguồn, cáp RS-485 và mạng theo hồ sơ lắp đặt; bảo đảm thiết bị đo đã sẵn sàng.',
'Cấp nguồn. Với bản kiosk đã cài dịch vụ tự khởi động, chờ logo 4M và màn hình ứng dụng xuất hiện.',
'Kiểm tra ngày, giờ, múi giờ và danh sách cảm biến. Nếu báo <b>No sensors</b>, cấu hình kênh tại <b>Settings → Sensors</b>.',
'Với trạm chưa cấu hình: thực hiện lần lượt General (trang 8), Connection (trang 9), Sensors (trang 10–12), rồi Server (trang 13–14).',
'Trở về <b>Monitor</b>, đối chiếu giá trị với màn hình cảm biến/analyser và kiểm tra kết quả trong History.',
]) + table(['Mục trên thanh bên', 'Công dụng'], [
('Monitor', 'Xem giá trị hiện tại, cảnh báo, trạng thái đo và FTP.'),
('History', 'Tra cứu mẫu đã lưu theo ngày và cảm biến.'),
('Trending', 'Xem biểu đồ trực tiếp hoặc truy vấn lịch sử.'),
('Settings', 'Cấu hình General, Connection, Server và Sensors.'),
('Tester', 'Kết nối kiểm tra Modbus, đọc/ghi thanh ghi; dành cho kỹ thuật viên.'),
]) + '''<h2>2.2. Quy tắc thao tác cảm ứng</h2>
<p>Chạm một lần để chọn. Vuốt để xem nội dung dài. Chạm ô nhập để dùng bàn phím ảo; nút <b>OK</b> trên bàn phím chỉ kết thúc nhập, không thay nút <b>Save</b> của biểu mẫu.</p>
''' + callout('Lưu cấu hình:', 'Sau sửa General/Connection/Server, chọn Save và phải thấy thông báo “Configuration saved.”. Nếu xuất hiện Validation error hoặc Failed to save configuration, chưa được coi là lưu thành công.') + callout('Phân biệt:', 'Cancel của cấu hình tải lại giá trị đã lưu. Các thao tác xóa cảm biến, tạo lại token và gắn/gỡ DI/DO có thể lưu ngay; Cancel không phải nút hoàn tác chung.', 'warning'))

add('Hiển thị số liệu — Monitor', '03 · Giám sát tại trạm',
path('Thanh bên → Monitor') + shot('ui-monitor.png', 'Hình 1. Màn hình Monitor, bố cục Grid.') + '''
<h2>3.1. Đọc thông tin trên màn hình</h2>
''' + table(['Vị trí / nhãn', 'Ý nghĩa và thao tác'], [
('Running / Pause', 'Chỉ báo hoạt động polling; không phải nút bật/tắt. Pause có thể xuất hiện khi cấu hình hoặc khi Tester đang dùng cổng serial.'),
('Retrying / Error', 'Kết nối lỗi hoặc đang thử lại. Kiểm tra đường RS-485 và cấu hình theo trang 18; không xem giá trị cũ là mẫu mới.'),
('Thẻ ANALOG', 'Tên/ký hiệu, đơn vị, giá trị hiện tại và trạng thái đo. Giá trị “---” không có nghĩa là bằng 0.'),
('MAX / MIN', 'Cảnh báo vượt ngưỡng đã cài trên kênh. Đối chiếu thiết bị đo trước khi sửa ngưỡng.'),
('Thẻ DI / DO', 'Trạng thái đầu vào/đầu ra số. ON/OFF phải được giải thích theo sơ đồ và ý nghĩa tín hiệu của trạm.'),
('FTP', 'Off: lịch gửi không chạy; Running: đang chạy; OK/Failed: trạng thái upload. Running không bảo đảm đã gửi thành công.'),
], compact=True) + '''<p class="small">Đổi Grid/List hoặc ẩn/hiện DI/DO tại Settings → General → Monitor layout / Show DI/DO sensors, sau đó Save. Màu xanh của một kênh không thay thế việc đánh giá chất lượng số liệu.</p>''')

add('Tra cứu số liệu — History', '04 · Dữ liệu đã lưu',
path('Thanh bên → History') + shot('ui-history.png', 'Hình 2. Màn hình History và bộ lọc ngày/cảm biến.') + steps([
'Chọn <b>From</b> (ngày bắt đầu) và <b>To</b> (ngày kết thúc); ngày bắt đầu không được sau ngày kết thúc.',
'Chọn <b>All sensors</b> hoặc một cảm biến. Chạm biểu tượng kính lúp để tra cứu; chờ kết thúc Loading history… trước thao tác tiếp.',
'Đọc các cột <b>Time, Sensor, Unit, Value, Raw value</b>. Value là giá trị đã xử lý; Raw value là giá trị trước quy đổi.',
'Nếu không thấy mẫu cần tìm, thu hẹp khoảng ngày và chọn đúng cảm biến. Số rows là số dòng được nạp, không phải tổng dữ liệu toàn bộ trạm.',
]) + callout('Giới hạn hiện tại:', 'Mỗi truy vấn History lấy tối đa 2.000 mẫu. Bảng hiện tại không có cột trạng thái thiết bị và không có nút xuất CSV/USB; không suy các chức năng đó từ tài liệu OSG.') + callout('Làm mới:', 'Bản hiện tại có thể tái sử dụng kết quả khi bộ lọc không đổi, kể cả bấm biểu tượng refresh. Đổi bộ lọc hợp lý rồi tìm lại nếu cần truy vấn khác; không liên tục bấm khi đang tải.') + '''<p class="small">Định dạng ngày được chấp nhận: dd/MM/yyyy hoặc yyyy-MM-dd. Phạm vi tìm bao gồm đầu ngày From đến cuối ngày To; dữ liệu đã bị xóa theo chính sách lưu trữ sẽ không xuất hiện trở lại.</p>''')

add('Xem biểu đồ — Trending', '05 · Theo dõi xu hướng',
path('Thanh bên → Trending → biểu tượng bộ lọc') + '''
<p class="intro">Biểu đồ trực tiếp hiển thị cửa sổ gần nhất khoảng 5 phút của các kênh ANALOG đang hoạt động. Không nhầm dữ liệu live trong bộ đệm với toàn bộ lịch sử đã lưu trong cơ sở dữ liệu.</p>
<h2>5.1. Lọc cảm biến và xem lịch sử</h2>
''' + steps([
'Mở <b>Trending</b>. Kiểm tra tên kênh và màu trên phần chú giải.',
'Chạm biểu tượng bộ lọc để mở <b>Trending filter</b>. Tại <b>Show last</b>, nhập số lượng từ 1 đến 365.',
'Chọn đơn vị <b>Minutes</b>, <b>Hours</b> hoặc <b>Days</b>. Ví dụ: 1 Days là khoảng 24 giờ gần nhất tính từ thời điểm truy vấn.',
'Chọn các kênh cần xem. <b>All</b> chọn tất cả; giao diện giữ ít nhất một kênh được chọn. Chọn ít kênh có thang giá trị tương đương để dễ đọc.',
'Chọn <b>Apply</b>, chờ truy vấn hoàn tất. <b>Cancel</b> đóng hộp thoại, không chạy truy vấn lịch sử mới.',
'Muốn quay về trực tiếp: chuyển sang màn hình khác rồi vào lại Trending. Bản hiện tại xóa chế độ lịch sử khi rời màn hình; không hướng dẫn dùng nút Live không có trên giao diện.',
]) + table(['Hiện tượng', 'Cách hiểu'], [
('Đường bị nén sát trục', 'Các kênh dùng chung trục Y; lưu lượng hàng trăm có thể làm pH khó nhìn. Lọc nhóm kênh có thang gần nhau.'),
('Chưa có đường live', 'Chờ tích lũy mẫu và kiểm tra Monitor có đang cập nhật hay không.'),
('Khoảng lịch sử dài', 'Biểu đồ có giảm mẫu để hiển thị; không coi mỗi điểm biểu đồ là từng mẫu nguyên gốc.'),
('Kết quả bị cắt ngắn', 'Truy vấn có trần số mẫu và có thể báo truncated; thu hẹp khoảng thời gian, đối chiếu dữ liệu gốc.'),
]) + callout('Không suy dung lượng lưu:', 'Ô chọn đến 365 Days không chứng minh thiết bị lưu được 365 ngày. Chỉ truy vấn được dữ liệu thực sự còn trong cơ sở dữ liệu; xem trang 19.'))

add('Cài đặt chung — General', '06 · Cấu hình trạm',
path('Settings → General') + '''<p class="intro">Ghi lại cấu hình hiện tại trước khi sửa. Mã trạm trong General không tự thay thế các thành phần tên tệp báo cáo tại Server.</p>''' + table(['Trường trên màn hình', 'Hướng dẫn'], [
('Device ID', 'Thông tin nhận dạng thiết bị; dùng khi yêu cầu hỗ trợ. Không sửa nhận dạng bằng cách chép dữ liệu từ thiết bị khác.'),
('Station code', 'Nhập mã trạm theo cấu hình được duyệt. Đồng bộ với hồ sơ hệ thống tập trung.'),
('Name Device', 'Tên hiển thị/nhận diện thiết bị theo trạm.'),
('Poll interval (s)', 'Chu kỳ polling, từ 1 đến 3.600 giây. Chọn theo yêu cầu vận hành và khả năng đáp ứng của đường RS-485.'),
('Monitor layout', 'Grid: dạng thẻ; List: dạng bảng. Chọn theo nhu cầu theo dõi.'),
('Show DI/DO sensors', 'Ẩn/hiện DI/DO trên Monitor; không phải công tắc tháo dây hoặc vô hiệu hóa tải vật lý.'),
('Time format / Date format', 'Định dạng hiển thị giờ/ngày; khuyến nghị giờ 24h HH:mm:ss và ngày dd/MM/yyyy.'),
('Timezone', 'Chọn múi giờ tương ứng UTC+7 cho Việt Nam. Sau Save, kiểm tra đồng hồ thực tế trên Monitor.'),
]) + steps([
'Điền các thông tin được phép thay đổi; chọn <b>Save</b>.',
'Kiểm tra thông báo thành công. Nếu báo không áp dụng được timezone cho OS, báo kỹ thuật viên; lưu cấu hình không có nghĩa là giờ hệ điều hành đã đúng.',
'Đối chiếu đồng hồ với nguồn thời gian tin cậy. NTP phụ thuộc hệ điều hành, quyền và kết nối mạng.',
]) + callout('Lưu ý thời gian:', 'Không chỉnh giờ tùy tiện khi đang lấy dữ liệu chính thức. Sai giờ có thể làm mẫu, biểu đồ, khoảng báo cáo và tên tệp không khớp. Định dạng giờ trên UI không làm thay đổi quy tắc timestamp TXT.', 'warning'))

add('Cài đặt kết nối cảm biến', '07 · Modbus RTU',
path('Settings → Connection → Local Sensors') + '''
<h2>7.1. Chuẩn bị</h2><p>Tất cả thiết bị trên cùng bus phải có cấu hình truyền tương thích và slave ID không xung đột. Dùng register map của đúng model/firmware cảm biến; không sao chép địa chỉ từ ví dụ demo.</p>
''' + table(['Trường', 'Ý nghĩa'], [
('Port', 'Chọn cổng serial đã được nhận diện, ví dụ /dev/ttyUSB0 (chỉ là ví dụ). Biểu tượng refresh quét lại danh sách cổng.'),
('Baudrate', 'Chọn đúng tốc độ cảm biến: 1.200 / 2.400 / 4.800 / 9.600 / 19.200 / 38.400 / 57.600 / 115.200 bps.'),
('Data bits', 'Số bit dữ liệu theo thiết bị đo; thường là 8 nhưng phải xác minh trên cấu hình thực tế.'),
('Parity', 'N: không parity; E: chẵn; O: lẻ. Phải trùng với thiết bị đo.'),
('Stop bits', 'Chọn 1 hoặc 2 theo cảm biến.'),
]) + steps([
'Chọn Port. Nếu không thấy cổng, kiểm tra bộ chuyển đổi và chạm refresh; không tự rút cáp của trạm đang đo nếu chưa được phép.',
'Điền Baudrate và Data framing đúng tài liệu thiết bị. Chọn <b>Save</b> và chờ thông báo.',
'Về Monitor, chờ kết nối ổn định. Nếu tất cả kênh đều lỗi, kiểm tra cấu hình serial trước khi sửa từng cảm biến.',
'Nếu chỉ một kênh lỗi, kiểm tra slave ID, địa chỉ, register type và data type của kênh đó (trang 10).',
]) + callout('Không đổi cấu hình tùy tiện:', 'Thay port/baudrate có thể tạm gián đoạn toàn bộ bus. Không chạy thêm một phần mềm master khác vào cùng cổng hoặc cùng bus khi 4M đang polling.', 'warning') + '''<h2>7.2. Không thấy cổng serial</h2><p>Báo kỹ thuật viên kiểm tra nguồn thiết bị chuyển đổi, đầu nối, driver và quyền dialout của dịch vụ. Cổng được lưu trong cấu hình có thể vẫn hiện dù bộ chuyển đổi đã bị tháo; thấy tên cổng không chứng minh cổng đang sử dụng được.</p>''')

add('Thêm, sửa và xóa cảm biến', '08 · Danh sách kênh đo',
path('Settings → Sensors') + shot('ui-settings-sensors.png', 'Hình 3. Danh sách cảm biến và nút + Add.') + steps([
'Chọn <b>+ Add</b> để thêm kênh; hoặc chạm một dòng rồi chọn biểu tượng <b>bút chì</b> để sửa. Không cần double-click.',
'Tại <b>Basic &amp; Modbus</b>, bật Active khi muốn kênh tham gia đo; điền Name, Sensor symbol, Unit cho ANALOG.',
'Nhập <b>Slave ID</b> (1–247), <b>Address</b> (0–65535) và <b>Register type</b> đúng tài liệu thiết bị.',
'Chọn <b>Input Registers / Holding Registers</b> cho ANALOG; <b>Discrete Inputs</b> cho DI; <b>Coils</b> cho DO. Không để Invalid.',
'Với ANALOG, chọn Data type và Endian format; sang Scaling &amp; Alarms nếu cần. Chọn Save rồi kiểm tra trên Monitor.',
]) + callout('Địa chỉ Modbus:', 'Address là địa chỉ truy vấn. Nếu hãng ghi số tham chiếu kiểu 30001/40001 hoặc đánh số từ 1, kỹ thuật viên phải xác định cách quy đổi đúng; không nhập nguyên số tham chiếu theo phỏng đoán.') + callout('Xóa không thể coi là ẩn kênh:', 'Chọn dòng → thùng rác → xác nhận sẽ xóa cảm biến và dữ liệu sensor_data liên quan trong bản hiện tại. Sao lưu được kiểm chứng trước thao tác; dùng Active để ngừng dùng kênh nếu muốn giữ cấu hình thay vì xóa.', 'warning'))

add('Quy đổi giá trị & cảnh báo', '09 · Scaling & Alarms',
path('Settings → Sensors → chọn kênh ANALOG → bút chì → Scaling & Alarms') + '''<p class="small">Trước quy đổi, kiểm tra Data type tại Basic &amp; Modbus: int16/uint16 dùng 1 thanh ghi; int32/uint32/float32 dùng 2 thanh ghi. int là có dấu, uint là không dấu. Endian format AB/BA áp dụng 16 bit; ABCD/CDAB/BADC/DCBA áp dụng 32 bit, chọn theo register map của hãng.</p>''' + table(['Trường / chế độ', 'Cách thiết lập'], [
('No scaling (raw value)', 'Giữ nguyên giá trị đã giải mã từ thanh ghi; dùng khi cảm biến đã trả đơn vị kỹ thuật.'),
('Linear (y = ax + b)', 'Nhập a và b; y là kết quả quy đổi, x là raw value. Ví dụ x = 718, a = 0.01, b = 0 thì y = 7.18.'),
('Two-point mapping', 'Khai báo RawMin/RawMax và ScaleMin/ScaleMax. Hai giá trị Raw không được bằng nhau; kiểm tra cả hai đầu dải và điểm giữa.'),
('Advanced (JSON)', 'Chỉ kỹ thuật viên sử dụng cấu hình đã được kiểm thử; không nhập công thức hoặc JSON đoán từ tài liệu khác.'),
('Decimal places', '0–6 chữ số thập phân theo nhu cầu hiển thị/báo cáo. Không làm tăng độ chính xác của cảm biến.'),
('Min threshold / Max threshold', 'Ngưỡng cảnh báo theo giá trị đã xử lý. Để trống là tắt ngưỡng tương ứng; không nhập 0 để thay cho “tắt”.'),
]) + '''<h2>9.1. Trình tự kiểm tra</h2>''' + steps([
'Đọc và ghi lại raw value, giá trị trên thiết bị đo và đơn vị chuẩn.',
'Chọn chế độ quy đổi phù hợp, không quy đổi lần thứ hai nếu analyzer đã trả giá trị thật.',
'Đặt ngưỡng theo hồ sơ vận hành đã duyệt; chọn <b>Save</b>.',
'Đối chiếu Value và Raw value trong History, kiểm tra các điểm thử nằm trong và ngoài ngưỡng trên môi trường an toàn.',
'Nếu có liên kết DO, kiểm tra kết quả tác động theo quy trình trang 12; ghi nhận và khôi phục trạng thái làm việc.',
]) + callout('Ví dụ không phải hiệu chuẩn:', 'Các con số trên chỉ giải thích phép quy đổi. Không dùng hệ số/ngưỡng demo để vận hành chính thức; thay đổi a/b có thể làm biến đổi dữ liệu và cảnh báo.', 'warning') + callout('Phân biệt cảnh báo:', 'MAX/MIN là ngưỡng do trạm cấu hình; không tự đồng nghĩa vượt quy chuẩn pháp lý. Giá trị bất thường cần kiểm tra cảm biến và công tác QA/QC.'))

add('Liên kết DI/DO với kênh đo', '10 · Trạng thái & đầu ra cảnh báo',
path('Settings → Sensors → sửa kênh ANALOG đã lưu → Digital I/O') + '''
<p class="intro">Tab Digital I/O xuất hiện khi sửa một kênh ANALOG đã tồn tại, không xuất hiện trong bước thêm mới. Cần tạo các kênh Discrete Inputs/Coils trước khi liên kết.</p>
<div class="columns"><div><h2>10.1. Gắn trạng thái DI</h2>''' + steps([
'Tạo kênh DI tại Sensors với Register type = <b>Discrete Inputs</b> và địa chỉ đúng.',
'Mở Digital I/O của kênh ANALOG, chọn thẻ <b>DI</b> và chọn DI sensor.',
'Chọn <b>Status code</b> phù hợp với ý nghĩa tín hiệu, rồi <b>Attach DI</b>.',
'Kiểm tra Attached sensors. Chọn liên kết để sửa mã bằng <b>Update</b>, hoặc <b>Detach</b> để gỡ.',
]) + '''</div><div><h2>10.2. Gắn cảnh báo DO</h2>''' + steps([
'Tạo kênh DO với Register type = <b>Coils</b>.',
'Trong Digital I/O, chọn <b>DO</b>, chọn DO sensor còn khả dụng.',
'Đánh dấu <b>Trigger on Max</b> và/hoặc <b>Trigger on Min</b>, chọn <b>Attach DO</b>.',
'Kiểm tra liên kết và thử tác động an toàn; một DO đã gắn kênh khác có thể không nằm trong danh sách chọn.',
]) + '''</div></div>''' + table(['Mã hiển thị', 'Trạng thái'], [
('00 — Monitoring', 'Đang đo.'),
('01 — Calibrating', 'Hiệu chuẩn.'),
('02 — Error', 'Báo lỗi thiết bị.'),
('03 — Maintenance', 'Bảo trì nội bộ; không có trong Bảng 35 TT10. Chưa mặc nhiên được phép truyền như mã TT10.'),
], compact=True) + callout('Tác động trực tiếp:', 'Attach DI/DO, Update và Detach gọi thay đổi liên kết ngay. Đóng biểu mẫu hoặc Cancel không bảo đảm hoàn tác những thay đổi này.', 'warning') + callout('An toàn đầu ra:', 'Không thử DO/ghi coil vào thiết bị thật khi tải còn có thể tác động nguy hiểm. Việc ghép tín hiệu, cực tính, relay trung gian và trạng thái mất nguồn phải được kiểm tra theo thiết kế tủ.', 'warning'))

add('Cấu hình truyền báo cáo FTP', '11 · Server / General Settings',
path('Settings → Server → General Settings') + table(['Trường', 'Hướng dẫn'], [
('Active', 'Bật lịch tạo/gửi báo cáo khi cấu hình máy chủ và danh sách kênh đã kiểm tra.'),
('Server name', 'Tên nhận diện cấu hình máy chủ.'),
('Send interval (min)', 'Chọn 1, 2, 3, 5, 10, 15, 20, 30 hoặc 60 phút. Với yêu cầu TT10, cấu hình ≤ 5 phút và kiểm thử độ trễ thực tế.'),
('Start time', 'Giờ neo lịch dạng HH:mm, ví dụ 00:00; theo phương án trạm.'),
('Host / Port', 'Địa chỉ và cổng máy chủ FTP được cấp, cổng mặc định 21. Không nhầm với cổng REST 8080 hoặc Modbus TCP 5020.'),
('Username / Password', 'Thông tin do đơn vị tiếp nhận cấp; nhập kín, không chụp vào biên bản công khai.'),
('Station folder / Date subfolder', 'Thư mục trạm và phân cấp ngày; mẫu thường dùng NUO001 và yyyy/MM/dd.'),
('File prefix / File suffix', 'Phần đầu tên tệp và mẫu thời gian; thiết lập chi tiết tại trang 14.'),
('Remote path', 'Bản xem trước tên tệp/đường dẫn đích; không chứng minh máy chủ cho phép ghi hoặc tệp đã được gửi.'),
]) + steps([
'Nhập thông tin theo tài khoản FTP và thư mục được cấp. Đối chiếu các giá trị, nhất là Host/Port và dấu gạch dưới trong tên tệp.',
'Chọn kênh tại <b>Transfer Parameters</b> (trang 14), bật Active và chọn <b>Save</b>.',
'Trở về Monitor, theo dõi FTP. Xác nhận với phía tiếp nhận rằng đúng tệp, đúng giờ, đủ thông số đã tới máy chủ.',
'Khi báo FTP Failed, ghi thời điểm và thông báo lỗi; kiểm tra mạng/tài khoản/quyền thư mục. Không đổi sang SFTP bằng cách chỉ đổi Port.',
]) + callout('Phương thức truyền:', 'Bản hiện tại dùng FTP thường, không phải FTPS/SFTP. Điều 39 nêu FTP hoặc FTPs hoặc sFTP; khả năng bảo mật mạng và yêu cầu của bên nhận phải được xem xét riêng.', 'warning'))

add('Chọn thông số truyền & tên tệp', '12 · Nội dung báo cáo',
path('Settings → Server → Transfer Parameters') + steps([
'Kiểm tra danh sách các kênh ANALOG. Chọn <b>Sensor symbol</b> đúng thông số; không dùng tên tự do thay cho mã được bên nhận yêu cầu.',
'Đánh dấu <b>Transmit</b> cho kênh cần gửi; <b>Select all / Deselect all</b> thay đổi toàn bộ ô chọn.',
'Chọn <b>Save</b> trên thanh chung để lưu. <b>Auto-add new sensors</b> áp dụng chính sách cho kênh mới; luôn kiểm lại danh sách trước bàn giao.',
'Chỉ các kênh ANALOG active, có bật truyền mới được đưa vào báo cáo; kênh bị loại có thể vẫn xem trên Monitor.',
]) + callout('Nút Delete tại Transfer Parameters:', 'Bản hiện tại tắt truyền ngay cho các dòng đang được đánh dấu Transmit; không phải xóa cảm biến khỏi Sensors. Không dùng nút này như thao tác chọn dòng thông thường.', 'warning') + '''<h2>12.1. Ví dụ cấu hình tên tệp theo Phụ lục 15</h2>''' + table(['Trường', 'Ví dụ minh họa'], [
('File prefix', '<code>HN_ABCD_NUO001_</code> — có dấu gạch dưới cuối.'),
('File suffix', '<code>yyyyMMddHHmmss</code> — giờ 24h theo mẫu Qt.'),
('Station folder', '<code>NUO001</code>'),
('Date subfolder', '<code>yyyy/MM/dd</code>'),
('Tên tệp kết quả', '<code>HN_ABCD_NUO001_20261023120000.txt</code>'),
], compact=True) + '''<p class="small">Các mã trên là ví dụ, không phải cấu hình của trạm thật. Phụ lục 15 quy định mã tỉnh, cơ sở 4 ký tự, trạm 6 ký tự (NUO/KHI và 3 ký tự tên trạm); xác nhận với đơn vị tiếp nhận trước sử dụng.</p>''' + callout('Giới hạn cần xử lý trước nghiệm thu:', 'Bộ ghi TXT hiện cần sửa/kiểm thử cách xuống dòng từng thông số và mã 03. Việc đặt tên đúng và FTP OK chưa chứng minh toàn bộ tệp đáp ứng Phụ lục 15; xem trang 19.', 'warning'))

add('Kết nối SCADA / Central Logger', '13 · Network Services & QR',
path('Settings → Connection → Network Services') + '''
<h2>13.1. Modbus TCP Server</h2>
''' + steps([
'Bật <b>Active</b> trong Modbus TCP Server; nhập Bind address, Port (mặc định <b>5020</b>) và Unit ID theo cấu hình tích hợp.',
'Chọn <b>Save</b>. Kiểm tra trạng thái <b>Listening</b>; nếu Error, đọc thông báo ngay bên dưới và báo kỹ thuật viên.',
'Trên SCADA/Central, dùng IP thực tế của logger, port và register map v1 được cấp. <b>0.0.0.0</b> là địa chỉ bind mọi giao diện, không phải địa chỉ client dùng để kết nối.',
]) + '''<h2>13.2. HTTP REST Server và ghép nối QR</h2>''' + steps([
'Bật Active, kiểm tra Bind address và Port (mặc định <b>8080</b>); chọn Save để dịch vụ lắng nghe và tạo token khi chưa có.',
'Chạm biểu tượng QR cạnh API token khi REST đã hoạt động. Trong Central Logger, dùng <b>Add Logger → Scan QR</b>.',
'Kiểm tra Central kết nối đúng IP LAN và tên trạm. Không gửi ảnh QR/token qua kênh không được phép.',
'Chỉ dùng <b>Regenerate</b> khi được phê duyệt: thao tác đổi token được lưu ngay, có xác nhận. Sau đổi phải ghép nối/cập nhật token cho các client liên quan.',
]) + table(['Dịch vụ', 'Điểm cần nhớ'], [
('REST /api/v1/readings', 'Cần Bearer token; đọc snapshot hiện tại.'),
('REST /api/v1/config', 'Đọc cấu hình có token; POST chỉ cập nhật app-config, không sửa trường cảm biến.'),
('REST /api/v1/health', 'Không cần token; không dùng khả năng gọi health để kết luận token đúng.'),
], compact=True) + callout('Bảo mật:', 'Modbus TCP không có Bearer token; HTTP/FTP không mặc nhiên mã hóa. Chỉ triển khai trong mạng được kiểm soát, không tự mở các cổng ra Internet. QR chứa bí mật truy cập; không đưa vào tài liệu công khai.', 'warning'))

add('Kiểm tra Modbus — Tester', '14 · Chỉ dành cho kỹ thuật viên',
path('Thanh bên → Tester') + callout('Gây gián đoạn đo:', 'Connect tạm dừng polling khi Monitor đang chạy hoặc thử kết nối lại, để Tester giữ cổng serial. Phải Disconnect khi xong; không chỉ đổi màn hình rồi bỏ quên kết nối.', 'warning') + '''
<h2>14.1. Đọc thử một vùng nhỏ</h2>''' + steps([
'Xác nhận được phép thử; kiểm tra thông số Serial đang lấy từ Settings → Connection. Chọn <b>Connect</b>, chờ kết nối xong.',
'Chọn <b>Read</b>, Slave ID, Register type, Data type và Endian format đúng register map.',
'Đặt <b>Start address</b>, <b>End address</b> và <b>Registers per read</b> vừa đủ. Bắt đầu với vùng nhỏ được phép đọc; Scan range là quét dải địa chỉ trên slave đã chọn, không tự tìm mọi slave ID.',
'Chọn <b>Scan range</b>; bảng hiển thị Address và Value. Dùng <b>Stop scan</b> để dừng; <b>Hide 0</b> chỉ ẩn giá trị 0, không xóa hay bỏ qua dữ liệu gốc.',
'Nếu cần tạo kênh, chọn <b>Save new sensor</b>, kiểm tra lại toàn bộ biểu mẫu Settings rồi Save. Các trường được chuyển theo cấu hình quét, không tự suy địa chỉ từ dòng kết quả.',
'Chọn <b>Disconnect</b>, về Monitor và xác nhận Running cùng giá trị mới. Clear table chỉ xóa bảng kết quả Tester, không xóa lịch sử đo.',
]) + '''<h2>14.2. Ghi thử — thao tác có rủi ro</h2>
<p>Write chỉ dành cho Holding Registers/Coils và địa chỉ được hãng cho phép. Điền Write address/Write value và kiểm tra loại dữ liệu. Bản hiện tại gửi lệnh khi bấm nút Write thực thi; <b>không dựa vào giả định sẽ có hộp thoại xác nhận thứ hai</b>.</p>
''' + callout('Không ghi khi chưa có phương án an toàn:', 'Lệnh có thể tác động thiết bị/relay ngay. Không thử trên thanh ghi cấu hình, hiệu chuẩn hoặc điều khiển tải khi chưa có hướng dẫn của hãng và người có thẩm quyền. Sau ghi phải đọc lại, kiểm tra trạng thái thật và khôi phục theo kế hoạch.', 'warning'))

add('Vận hành hằng ngày & khởi động lại', '15 · Quy trình tại trạm', '''
<h2>15.1. Kiểm tra đầu ca</h2>
<ul class="checklist"><li>Ngày/giờ đúng, múi giờ UTC+7; ứng dụng không bị che bởi hộp thoại hay màn hình lỗi.</li><li>Monitor có đúng danh sách kênh, không bị bỏ Active hoặc nhầm đơn vị.</li><li>Running và giá trị mới tiếp tục cập nhật; không chỉ nhìn một ảnh chụp tĩnh.</li><li>Đối chiếu cảnh báo MAX/MIN, trạng thái hiệu chuẩn/lỗi/bảo trì với tình trạng thật.</li><li>Kiểm tra FTP và xác nhận tệp trên máy chủ theo trách nhiệm được giao.</li><li>Tra cứu History một khoảng gần nhất; không còn kết nối Tester đang giữ cổng.</li></ul>
<h2>15.2. Khi cần khởi động lại</h2>
''' + steps([
'Báo người phụ trách, ghi nhận thời gian và lý do. Lưu các cấu hình đang sửa và dừng công việc Tester an toàn.',
'Chạm nút khởi động lại màu đỏ ở cuối thanh bên; đọc hộp thoại <b>Confirm reboot</b>.',
'Chỉ chọn <b>Reboot</b> khi đã được phép. Đây là khởi động lại cả thiết bị, không phải chỉ làm mới bảng.',
'Chờ hệ thống boot và ứng dụng tự mở theo cấu hình kiosk; kiểm tra giờ, polling, dữ liệu mới và FTP sau khởi động.',
]) + callout('Không dùng reboot thay tắt nguồn:', 'UI hiện không có quy trình shutdown được mô tả trong tài liệu này. Khi bảo trì cần cắt nguồn, để kỹ thuật viên tắt hệ điều hành theo quy trình bàn giao rồi mới cô lập nguồn; không bấm Reboot rồi rút nguồn giữa lúc boot.', 'warning') + '''
<h2>15.3. Mất điện / mất mạng</h2>
<p>Khi có điện trở lại, kiểm tra hệ thống và đối chiếu khoảng trống dữ liệu. Khi mạng phục hồi, xác nhận tệp thực sự được truyền bù, không chỉ nhìn FTP Running. Ghi nhật ký sự cố và thông báo theo quy trình trạm; không tự tạo dữ liệu lấp khoảng trống.</p>
''')

add('Tra cứu sự cố thường gặp', '16 · Chẩn đoán an toàn',
table(['Hiện tượng', 'Kiểm tra / xử lý theo thứ tự'], [
('Màn hình không lên', 'Kiểm tra nguồn và màn hình theo hồ sơ; không cấp thử điện áp khác. Nếu có điện mà ứng dụng không mở, báo kỹ thuật viên kiểm tra dịch vụ kiosk.'),
('No sensors', 'Sensors có ít nhất một kênh Active? Cấu hình đã Save? Không xóa/tạo lại hàng loạt để thử.'),
('Retrying / Error mọi kênh', 'Kiểm tra nguồn thiết bị đo, bus A/B, cổng serial, baudrate/framing và Tester có đang Connect. Một bus chỉ có master theo thiết kế.'),
('Một kênh không đọc được', 'Kiểm tra slave ID, Address, loại thanh ghi, số thanh ghi theo kiểu dữ liệu; đối chiếu register map của đúng firmware.'),
('Giá trị sai rất lớn / âm', 'Kiểm tra int/uint/float, 16/32 bit, Endian format và hệ số quy đổi. Không sửa ngưỡng chỉ để tắt cảnh báo.'),
('Không có dữ liệu History', 'Kiểm tra ngày, bộ lọc và quá trình polling/ghi DB. Dữ liệu quá hạn hoặc bị xóa không lấy lại bằng cách đổi ngày tìm.'),
('History không thấy mẫu mới', 'Có thể dùng kết quả cache của bộ lọc cũ; xem trang 6. Không hiểu 2.000 rows là toàn bộ cơ sở dữ liệu.'),
('Biểu đồ trống / bị nén', 'Kiểm tra dữ liệu Monitor, khoảng tìm, kênh được chọn và trục dùng chung; thử ít kênh cùng thang đo.'),
('FTP Failed', 'Kiểm tra mạng, Host/Port, tài khoản, quyền tạo thư mục và danh sách Transmit. Xác nhận lỗi phía máy chủ; không đưa mật khẩu vào ảnh báo lỗi.'),
('TCP/REST Error', 'Kiểm tra bind IP có tồn tại, port có bị chiếm/quyền hạn và dịch vụ đã Save. Dùng IP LAN thật từ client, không dùng 0.0.0.0.'),
('Central mất kết nối sau đổi token', 'Cập nhật token/scan QR lại trên các client được phép. Không tái sử dụng QR cũ.'),
('Lưu cấu hình báo lỗi', 'Đọc Validation error hoặc Failed to save configuration; giữ lại nội dung lỗi. Kiểm tra lại các trường thay vì cho rằng nút Save đã thành công.'),
], compact=True) + callout('Dừng thao tác và báo kỹ thuật:', 'Cảnh báo thiếu dung lượng, lỗi cơ sở dữ liệu, sai giờ hệ thống, khóa thiết bị hoặc đầu ra DO bất thường. Không tự xóa DB/log để “chữa nhanh”, không tháo thẻ nhớ khi đang chạy.', 'warning'))

add('Lưu trữ & lưu ý TT10', '17 · Phạm vi phiên bản được hướng dẫn', '''
<p class="intro">Hướng dẫn này mô tả hành vi phần mềm đang đối chiếu, không thay hồ sơ nghiệm thu. Không thể làm thiết bị tuân thủ TT10 chỉ bằng chọn một mẫu tên tệp.</p>
''' + table(['Yêu cầu / điểm kiểm tra', 'Hiện trạng và việc cần làm'], [
('Lưu dữ liệu ≥ 60 ngày', '<b>Điều 39.1.c</b> yêu cầu ít nhất 60 ngày gần nhất, đủ thông số, kết quả, đơn vị, thời gian và trạng thái. Mã hiện giữ sensor_data/báo cáo đã gửi 30 ngày; cần nâng cấp, kiểm thử dung lượng và lịch xóa trước nghiệm thu.'),
('Cấu trúc TXT', 'Phụ lục 15: mỗi thông số một dòng, 5 trường phân cách TAB, thời gian đúng mẫu. Bộ ghi hiện gom các nhóm vào một dòng; cần sửa/kiểm thử, không chỉ đổi tên tệp.'),
('Mã trạng thái', 'Bảng 35: 00 đang đo, 01 hiệu chuẩn, 02 lỗi. 03 Maintenance là mã nội bộ đang cần quy tắc xử lý được duyệt trước truyền.'),
('Truyền trong 05 phút', 'Điều 39.2.b yêu cầu chậm nhất 05 phút sau khi có kết quả. Cấu hình chu kỳ ≤ 5 phút chưa thay thử nghiệm độ trễ thực tế.'),
('GMT+7 & truyền bù', 'Xác minh đồng hồ thật và thử mất mạng/khôi phục; chưa khẳng định truyền bù end-to-end đã đạt.'),
('Truy cập & cổng', 'Tài khoản/mật khẩu, quyền quản lý và niêm phong cổng cần được tổ chức theo cấu hình hệ thống/cơ quan quản lý; token REST không thay toàn bộ yêu cầu này.'),
('Camera / lấy mẫu', 'Thuộc cấu hình hệ thống riêng (nếu có); không suy khả năng từ chức năng DO. Tài liệu này không hướng dẫn RTSP hay điều khiển bộ lấy mẫu chưa được tích hợp/nghiệm thu.'),
], compact=True) + '''<h2>17.1. Bảo vệ dữ liệu</h2>
<p>Chính sách hiện tại giữ log hệ thống 14 ngày, độc lập với dữ liệu quan trắc. Nhờ kỹ thuật viên thực hiện sao lưu trước sửa cấu hình/xóa kênh và trước khi dữ liệu hết hạn. SQLite WAL cần sao lưu nhất quán: không chỉ chép một tệp .db đang ghi rồi coi là đầy đủ; dùng công cụ backup phù hợp hoặc quy trình dừng an toàn được duyệt.</p>
''' + callout('Không thể khôi phục bằng tăng ngưỡng:', 'Dữ liệu đã bị xóa sau 30 ngày hoặc khi xóa cảm biến không tự quay lại khi nâng ngưỡng lên 60 ngày. Cần kế hoạch bảo toàn dữ liệu trước triển khai nâng cấp.', 'warning') + '''<p class="small">Nguồn đối chiếu: bản Thông tư 10/2021/TT-BTNMT người dùng cung cấp, Điều 39 và Phụ lục 15; không phải kết luận pháp lý về mọi văn bản sửa đổi sau đó. Chi tiết nội bộ: docs/catalogue/TT10-REVIEW.md.</p>''')

add('Kiểm tra bàn giao & yêu cầu hỗ trợ', '18 · Biểu mẫu vận hành', '''
<p>Đánh dấu sau khi kiểm tra trên thiết bị thực, không đánh dấu chỉ dựa trên ảnh demo trong tài liệu.</p>
<ul class="checklist">
<li>Nguồn, đấu dây và gá lắp đúng bản vẽ; nhãn cổng và hồ sơ thiết bị đầy đủ.</li>
<li>Ghi nhận Device ID, mã trạm, phiên bản phần mềm và bản cấu hình đã sao lưu.</li>
<li>Thử từng kênh: slave ID, địa chỉ, kiểu dữ liệu, quy đổi, đơn vị và giá trị đối chiếu.</li>
<li>Thử ngưỡng min/max và DI/DO theo phương án an toàn, sau đó khôi phục đúng chế độ.</li>
<li>Giờ GMT+7 đúng; History và Trending có dữ liệu trong khoảng thử.</li>
<li>FTP được bên nhận xác nhận; tên tệp/nội dung/chu kỳ và truyền bù đã được kiểm thử.</li>
<li>Nếu áp dụng TT10: nâng cấp và kiểm chứng lưu ≥ 60 ngày, cấu trúc TXT/trạng thái và các yêu cầu liên quan ở trang 19.</li>
<li>Tester đã Disconnect; Monitor cập nhật trở lại sau thử và sau reboot.</li>
<li>Bảo vệ token/QR/tài khoản; phân công người giữ bản sao lưu và nhật ký sự cố.</li>
</ul>
<h2>18.1. Ghi nhận tại trạm</h2>
<p>Tên trạm: <span class="fill" style="min-width:115mm"></span></p>
<p>Device ID: <span class="fill" style="min-width:110mm"></span></p>
<p>Phiên bản phần mềm: <span class="fill"></span> Ngày kiểm tra: <span class="fill"></span></p>
<p>Người kiểm tra: <span class="fill"></span> Người tiếp nhận: <span class="fill"></span></p>
<h2>18.2. Khi yêu cầu hỗ trợ 4M</h2>
<p>Cung cấp thời điểm lỗi và múi giờ, Device ID, màn hình đang dùng, cấu hình liên quan không chứa bí mật, hiện tượng trên cảm biến thật và thao tác ngay trước sự cố. Gửi log qua kênh được phê duyệt; che token, QR, mật khẩu và thông tin mạng nhạy cảm trước chia sẻ.</p>
<div class="result"><b>Nguyên tắc vận hành:</b> chỉ thay đổi trong phạm vi được phân quyền, ghi nhận trước/sau sửa, kiểm chứng dữ liệu thực và báo cáo khi có khoảng trống. Không bịa số liệu hoặc tắt cảnh báo để che sự cố.</div>
<p class="small">4M Technologies · Thông tin liên hệ và quy trình hỗ trợ theo hồ sơ bàn giao của dự án.</p>
''')

assert len(PAGES) == 20
toc = '<p class="intro">Chọn tên mục để đi đến trang tương ứng trong bản PDF/HTML hỗ trợ liên kết.</p><ul class="toc">'
for i, (title, _, _, _) in enumerate(PAGES[2:], start=3):
    toc += f'<li><a href="#page-{i}">{escape(title)}</a><span>{i:02d}</span></li>'
toc += '</ul>' + callout('Quy ước:', '<b>Chữ đậm</b> là nhãn trên UI hoặc thao tác cần chọn. Nội dung tiếng Việt giải thích giao diện tiếng Anh. Ô vàng là cảnh báo; ô xanh là lưu ý/kết quả kiểm tra.')
toc += '<p class="small">Ảnh minh họa UI chụp từ phần mềm với dữ liệu demo ngày 22/10/2026; một số bản cài có thể khác bố cục. Các trang không có ảnh dùng nhãn và hành vi đã đối chiếu mã nguồn, không phải ảnh UI mô phỏng.</p>'
PAGES[1] = (PAGES[1][0], PAGES[1][1], toc, False)

html = '''<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>4M Data Logger — Hướng dẫn sử dụng</title><link rel="stylesheet" href="manual.css"></head><body>'''
for i, (title, chapter, body, cover) in enumerate(PAGES, 1):
    html += f'''<section class="page{' cover' if cover else ''}" id="page-{i}"><div class="inside">
    <header><div class="brand"><img src="../catalogue/assets/logo.svg" alt="4M"><div>4M TECHNOLOGIES<small>HƯỚNG DẪN SỬ DỤNG · DATA LOGGER</small></div></div><div class="meta">4M-DL-UM · Rev. A<br>23/10/2026 · Bản dự thảo</div></header>
    <div class="chapter">{escape(chapter)}</div><h1>{escape(title)}</h1>{body}
    </div><div class="footer"><span>4M Data Logger · Hướng dẫn sử dụng · Rev. A</span><span>{i:02d} / {len(PAGES):02d}</span></div></section>'''
html += '</body></html>'
(HERE / 'huong-dan-su-dung.html').write_text(html, encoding='utf-8')
print(f'Đã tạo hướng dẫn {len(PAGES)} trang: {HERE / "huong-dan-su-dung.html"}')
