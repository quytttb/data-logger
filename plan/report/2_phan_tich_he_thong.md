# 2. Phân tích hệ thống

Từ các yêu cầu nguyên lý và kinh nghiệm bóc tách mã nguồn tại giai đoạn 1, hệ thống ứng dụng Data Logger được phân tích và bóc rã thành các luồng chi tiết. Việc thiết kế các biểu đồ phân tích rõ ràng sẽ phân định ranh giới hoạt động của các Thread, chống xung đột biến tham chiếu chung.

## 2.1 Sơ đồ Phân rã Chức năng (BFD - Business Function Diagram)

Hệ thống Data Logger được nhóm thành 4 module (nhóm cụm) chức năng cốt lõi:

```mermaid
mindmap
  root((Data Logger))
    Nhóm Thu thập Dữ liệu
      Worker Polling Modbus
      Decode Giá trị có dấu và Tỷ lệ
      Cơ chế Try-Catch tự kết nối lại
    Nhóm Quản lý Lưu trữ SQLite
      SQLModel ORM
      Thực thi Batch Insert tự động
      Chống lỗi Database Locked bằng WAL
    Nhóm Truyền tải Lập lịch sFTP
      Bộ sinh báo cáo TXT TNMT
      Tiến trình Asyncz Schedule mỗi 5 phút
      Quản lý Hàng đợi Pending File
    Nhóm Giao diện Người dùng PySide6
      Render Live Data Bảng và Thông số
      Vẽ Đồ thị lịch sử theo mốc giờ
      Hộp thoại Cấu hình 
```

## 2.2 Sơ đồ Luồng Dữ liệu (DFD - Data Flow Diagram)

Sơ đồ được thiết kế tuân thủ nghiêm ngặt **Quy tắc vẽ DFD chuẩn (Gane & Sarson notation)**. Nhằm trực quan hóa, bộ ký hiệu được cung cấp dưới dạng biểu đồ sau:

```mermaid
flowchart TD
    subgraph Legend [Chú thích Ký hiệu]
        direction LR
        L1([Thực thể bên ngoài - External Entity])
        L2((Tiến trình xử lý - Process))
        L3[(Kho lưu trữ - Data Store)]
        L1 ~~~ L2 ~~~ L3
    end
```

### DFD Mức Context (Level 0 - Toàn cảnh hệ thống)
Mô tả hệ thống bằng duy nhất 1 Process lớn bao trùm (0.0), chỉ kết nối với các Thực thể cấu thành bên ngoài (External Entities).

```mermaid
flowchart LR
    %% External Entities
    Sensor([Cảm biến Hiện trường])
    User([Nhân viên Vận hành])
    STNMT([FTP Server Sở TNMT])

    %% Process Level 0
    Sys(("0. Hệ thống Data Logger"))

    %% Data flows
    Sensor -- "Dữ liệu Modbus (Polled)" --> Sys
    User -- "Thông số cài đặt & ngưỡng" --> Sys
    
    Sys -- "Giao diện Realtime, Bảng dữ liệu, Cảnh báo" --> User
    Sys -- "File TXT chuẩn Phụ lục 15" --> STNMT
```

### DFD Mức 1 (Phân rã chức năng)
Phá vỡ hệ thống 0.0 phía trên thành 4 Process chức năng cốt lõi. Số lượng và nội dung mũi tên trỏ ra/vào hệ thống được **Cân bằng (Balancing)** tuyệt đối so với Mức 0.

```mermaid
flowchart TD
    %% External Entities
    Sensor([Cảm biến Hiện trường])
    User([Nhân viên Vận hành])
    STNMT([FTP Server Sở TNMT])

    %% Data Stores
    D1[(D1. CSDL SQLite)]
    D2[(D2. File Cấu hình TOML)]

    %% Processes
    P1(("1.0 Thu thập dữ liệu Modbus"))
    P2(("2.0 Hiển thị GUI & Quản lý Cấu hình"))
    P3(("3.0 Quản lý lưu trữ Database"))
    P4(("4.0 Lập lịch & Gửi File TXT"))

    %% Flows from Level 0
    Sensor -- "Dữ liệu Modbus (Polled)" --> P1
    User -- "Thông số cài đặt & ngưỡng" --> P2
    P2 -- "Giao diện Realtime, Bảng dữ liệu, Cảnh báo" --> User
    P4 -- "File TXT chuẩn Phụ lục 15" --> STNMT

    %% Internal Flows
    D2 -- "Cấu hình thanh ghi Modbus" --> P1
    P2 -- "Cấu hình người dùng" --> D2
    P1 -- "Dữ liệu live (đã chuẩn hóa)" --> P2
    P1 -- "Dữ liệu đã chuẩn hóa" --> P3
    P3 -- "Ghi / Đọc bản ghi" --> D1
    D1 -- "Dữ liệu lịch sử" --> P2
    D1 -- "Dữ liệu báo cáo" --> P4
    P2 -- "Yêu cầu tạo báo cáo" --> P4
```

### DFD Mức 2 (Phân rã Process 1.0 - Cơ chế Polling)
Phân rã chi tiết quá trình `1.0 Thu thập dữ liệu Modbus` nhằm phân chia rõ công việc cho Worker. Các luồng (Flows) và thực thể kế thừa hoàn toàn từ Level 1.

```mermaid
flowchart TD
    Sensor([Cảm biến Hiện trường])
    D2[(D2. File Cấu hình TOML)]
    To_P3(("3.0 Quản lý lưu trữ Database"))
    To_P2(("2.0 Hiển thị GUI & Quản lý Cấu hình"))

    P1_1(("1.1 Tiếp nhận cấu hình Polling"))
    P1_2(("1.2 Hỏi đáp Modbus"))
    P1_3(("1.3 Xử lý & Chuẩn hóa dữ liệu"))

    D2 -- "Cấu hình thanh ghi Modbus" --> P1_1
    Sensor -- "Dữ liệu Modbus (Polled)" --> P1_2
    P1_1 -- "Tham số Port/Baud/Timeout" --> P1_2
    P1_2 -- "Mảng giá trị thô" --> P1_3
    P1_3 -- "Dữ liệu đã chuẩn hóa" --> To_P3
    P1_3 -- "Dữ liệu live" --> To_P2
```

### DFD Mức 2 (Phân rã Process 2.0 - Giao diện và Cấu hình)
Phân rã chi tiết quá trình `2.0 Nạp UI & Cấu hình môi trường`. Các luồng biên kế thừa hoàn toàn từ Level 1.

```mermaid
flowchart TD
    User([Nhân viên Vận hành])
    D1[(D1. CSDL SQLite)]
    D2[(D2. File Cấu hình TOML)]
    From_P1(("1.0 Thu thập dữ liệu Modbus"))
    To_P4(("4.0 Lập lịch & Gửi File TXT"))

    P2_1(("2.1 Hiển thị Realtime & Cảnh báo"))
    P2_2(("2.2 Quản trị cấu hình trạm"))
    P2_3(("2.3 Truy vấn lịch sử & Yêu cầu báo cáo"))

    From_P1 -- "Dữ liệu live" --> P2_1
    User -- "Thông số cài đặt & ngưỡng" --> P2_2
    D1 -- "Dữ liệu lịch sử" --> P2_3
    P2_2 -- "Cấu hình người dùng" --> D2
    P2_1 -- "Giao diện Realtime, Bảng, Cảnh báo" --> User
    P2_3 -- "Giao diện Realtime, Bảng, Cảnh báo" --> User
    P2_3 -- "Yêu cầu tạo báo cáo" --> To_P4
```

### DFD Mức 2 (Phân rã Process 3.0 - Lưu trữ Database)
Phân rã chi tiết quá trình `3.0 Quản lý lưu trữ Database`. Process này chịu trách nhiệm gom dữ liệu từ hàng chờ và ghi theo lô xuống SQLite.

```mermaid
flowchart TD
    From_P1(("1.0 Thu thập dữ liệu Modbus"))
    D1[(D1. CSDL SQLite)]

    P3_1(("3.1 Tiếp nhận dữ liệu"))
    P3_2(("3.2 Gom batch"))
    P3_3(("3.3 Ghi SQL"))

    From_P1 -- "Dữ liệu đã chuẩn hóa" --> P3_1
    P3_1 -- "Bản ghi đơn" --> P3_2
    P3_2 -- "Batch dữ liệu" --> P3_3
    P3_3 -- "Ghi / Đọc bản ghi" --> D1
```

### DFD Mức 2 (Phân rã Process 4.0 - Kết xuất sFTP)
Phân rã chi tiết quá trình `4.0 Kết xuất và gửi sFTP`. Đây là tiến trình lập lịch chạy ngầm qua Asyncz, chịu trách nhiệm sinh file báo cáo và đẩy lên máy chủ Sở TNMT.

```mermaid
flowchart TD
    D1[(D1. CSDL SQLite)]
    STNMT([FTP Server Sở TNMT])
    From_P2(("2.0 Hiển thị GUI & Quản lý Cấu hình"))
    D3[(D3. Thư mục đệm TXT)]

    P4_1(("4.1 Trích xuất định kỳ"))
    P4_2(("4.2 Tiếp nhận yêu cầu đột xuất"))
    P4_3(("4.3 Sinh file TXT Phụ lục 15"))
    P4_4(("4.4 Gửi file qua sFTP"))

    D1 -- "Dữ liệu báo cáo" --> P4_1
    From_P2 -- "Yêu cầu tạo báo cáo" --> P4_2
    P4_1 -- "Tập bản ghi" --> P4_3
    P4_2 -- "Yêu cầu đột xuất" --> P4_3
    P4_3 -- "File TXT đã định dạng" --> D3
    D3 -- "File chờ gửi" --> P4_4
    P4_4 -- "File TXT chuẩn Phụ lục 15" --> STNMT
```


## 2.3 Sơ đồ Hoạt động (Activity Diagram: Vòng lặp Core Kháng lỗi)

Đây là điểm chốt yếu được đúc kết từ repo tham chiếu `Victron_Modbus_TCP`. Tiến trình thu thập dữ liệu là xương sống, phải bao bọc được mọi loại rủi ro nhiễu đường truyền.

```mermaid
flowchart LR
    %% Định dạng CSS cho Legend
    classDef action fill:#fff,stroke:#333,stroke-width:1px,color:#000,rx:10px,ry:10px;
    classDef decision fill:#fff,stroke:#333,stroke-width:1px,color:#000;
    classDef subprocess fill:#fff,stroke:#333,stroke-width:1px,color:#000;

    subgraph Legend [Chú thích Activity Diagram]
        direction TB
        
        S1((" ")) --- T1[Điểm bắt đầu]
        S2(" "):::action --- T2[Hoạt động / Trạng thái]
        S3{" "}:::decision --- T3[Điểm rẽ nhánh]
        S4[[" "]]:::subprocess --- T4[Tiến trình con]
        S5(((" "))) --- T5[Điểm kết thúc]
        
        %% Làm ẩn viền và nền của phần chữ
        style T1 fill:none,stroke:none
        style T2 fill:none,stroke:none
        style T3 fill:none,stroke:none
        style T4 fill:none,stroke:none
        style T5 fill:none,stroke:none
    end
```

```mermaid
flowchart TD
    %% Định dạng CSS cho Ký hiệu chuẩn Activity Diagram Không Màu (Hỗ trợ Dark Mode)
    classDef action fill:#fff,stroke:#333,stroke-width:1px,color:#000,rx:10px,ry:10px;
    classDef decision fill:#fff,stroke:#333,stroke-width:1px,color:#000;
    
    subgraph MainThread [Main GUI Thread]
        Start(( )) --> LoadConfig(Đọc file TOML Config):::action
        LoadConfig --> InitModbus(Khởi tạo pymodbus client):::action
        InitModbus --> SetupWorker(Khởi tạo & Chạy QThread Worker):::action
    end
    
    subgraph WorkerThread [Modbus Polling Thread]
        SetupWorker --> CheckStop{" "}:::decision
        
        CheckStop -- "[Có lệnh Dừng]" --> EndNode(((" ")))
        CheckStop -- "[Tiếp tục]" --> ReadReg("Gọi read_holding_registers / input_registers"):::action
        
        ReadReg --> CheckPkt{" "}:::decision
        
        %% Nhánh Lỗi
        CheckPkt -- "[Lỗi Timeout / CRC]" --> EmitErr(Phát QtSignal 'modbus_error'):::action
        EmitErr --> CheckRetry{" "}:::decision
        
        CheckRetry -- "[Retry ≤ 3 lần]" --> Backoff("Exponential Backoff<br>Tăng thời gian chờ"):::action
        Backoff --> CheckStop
        
        CheckRetry -- "[Retry > 3 lần]" --> SkipCycle(Bỏ qua chu kỳ):::action
        SkipCycle --> Sleep
        
        %% Nhánh Thành công
        CheckPkt -- "[Gói tin Hợp lệ]" --> ConvertSigned(Dịch bit signed/unsigned):::action
        ConvertSigned --> ApplyFormula(Áp hệ số & công thức):::action
        ApplyFormula --> EmitLive(Phát QtSignal 'data_live' cho GUI):::action
        EmitLive --> QueueDB(Đẩy vào Queue lưu Database an toàn):::action
        QueueDB --> Sleep(Nghỉ theo 'poll_interval'):::action
        
        %% Vòng lặp khép kín
        Sleep --> CheckStop
    end
```

## 2.4 Cấu trúc Máy Trạng thái Giao diện (System State Machine)

Trạng thái toàn cục (State) của thiết bị trên màn hình PySide6 được thiết kế dựa trên màu sắc nhãn dán, nhằm giúp nhân viên cơ sở và người trực màn hình dễ dàng nắm bắt hiện trạng:

```mermaid
flowchart TD
    subgraph Legend [Chú thích Ký hiệu]
        direction LR
        ST[Tên trạng thái - Màu sắc]
        TR -- "Sự kiện kích hoạt" --> TR2[Trạng thái đích]
    end
```

```mermaid
stateDiagram-v2
    [*] --> KhoiTao
    state "Khởi tạo Hệ thống - VÀNG" as KhoiTao
    state "Hoạt động Tiêu chuẩn - XANH LÁ" as BinhThuong
    state "Rớt Cảm biến - CAM" as MatCamBien
    state "Lỗi Đường truyền Sở - ĐỎ" as MatMang
    state "Đang Hiệu chuẩn - XANH DƯƠNG" as HieuChuan

    KhoiTao --> BinhThuong: Kết nối Modbus + sFTP thành công
    BinhThuong --> MatCamBien: Timeout Modbus ≥ 3 chu kỳ
    MatCamBien --> BinhThuong: Modbus phục hồi
    BinhThuong --> MatMang: sFTP timeout (không gửi được 5 phút)
    MatMang --> BinhThuong: sFTP kết nối lại thành công
    MatCamBien --> MatMang: sFTP cũng mất kết nối
    MatMang --> MatCamBien: sFTP phục hồi nhưng Modbus vẫn lỗi
    BinhThuong --> HieuChuan: Nhân viên kích hoạt chế độ hiệu chuẩn
    HieuChuan --> BinhThuong: Hoàn tất hiệu chuẩn
    [*] --> KhoiTao: Reboot / Power-on
```

**Giải thích các trạng thái:**
- **Khởi tạo (VÀNG)**: Ứng dụng lần đầu load lên, cấp quyền file system và thăm dò cấu hình chân ngõ ra tự động thông qua Udev.
- **Hoạt động Tiêu chuẩn (XANH LÁ)**: Thanh ghi trả dữ liệu chuẩn, DB ghi đúng chu kỳ, và tiến trình Asyncz báo cáo thành công file kỳ 5 phút trước lên sFTP.
- **Rớt Cảm Biến (CAM)**: Không nhận được data Modbus liên tục 5 giây. Giá trị tại GUI hiển thị `---` hoặc `N/A`, DB tự động đắp mã lỗi hoặc `NULL` tương ứng theo Thông tư môi trường.
- **Lỗi Đường Truyền Sở (ĐỎ)**: Trạm vẫn đo đạc và lưu xuống SQLite bình thường. Tuy nhiên báo động đỏ nháy vì Thread Asyncssh báo Timeout kết nối sFTP. Hệ thống đẩy toàn bộ báo cáo vào hàng đợi đệm cục bộ chờ phục hồi.

## 2.5 Đặc tả Ràng buộc Dữ liệu Lõi (Database Integrity)

Dựa trên cấu trúc Phân tích DFD này, thiết kế của SQLite (chạy DB Model thông qua SQLModel) không còn là đồ chơi mà mang tính công nghiệp thực thụ. 
Ứng dụng sẽ kích hoạt cứng dòng lệnh `PRAGMA journal_mode = WAL` (Write-Ahead Logging). Với kiến trúc phân nhánh của DFD phía trên, Luồng `DB_Worker` có thể thoải mái thực hiện hàng loạt tác vụ `INSERT INTO` ở nền, mà hoàn toàn không gây cản trở rủi ro Lock DB khi Luồng `FTP_Worker` vẫn đang chiếm quyền `SELECT` để xuất data sinh báo cáo thời gian thực, hay user đang bấm xem thống kê tháng.
