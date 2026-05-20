# Provisioning QR — `central-logger-provision/v1`

Schema dùng chung giữa **Data Logger (edge)** và **Central Logger App** để ghép nối logger qua LAN mà không cần gõ Bearer token thủ công.

## JSON trong QR

Chuỗi UTF-8 **một dòng** (compact, không URL-encode), ví dụ:

```json
{"schema":"central-logger-provision/v1","api_token":"<rest_api_token>","host":"192.168.1.50","api_port":8080,"modbus_port":5020,"modbus_unit_id":1,"station_code":"TRAM-XXX","station_name":"Tên trạm"}
```

## Trường

| Field | Bắt buộc | Mô tả | Nguồn edge |
|-------|----------|--------|------------|
| `schema` | Có | Luôn `central-logger-provision/v1` | Hằng số |
| `api_token` | Có | Bearer token REST hiện tại | `AppConfig.rest_api_token` |
| `host` | Khuyến nghị | IP LAN để Central kết nối (không `127.0.0.1` khi Central ở máy khác) | Bind REST nếu cụ thể, else IP LAN máy |
| `api_port` | Không (default 8080) | Cổng HTTP REST | `rest_api_port` |
| `modbus_port` | Không (default 5020) | Cổng Modbus TCP poll | `modbus_tcp_port` |
| `modbus_unit_id` | Không (default 1) | Unit ID Modbus TCP | `modbus_tcp_unit_id` |
| `station_code` | Không | Mã trạm | `station_code` |
| `station_name` | Không | Tên trạm | `station_name` |

## Edge (Data Logger)

- **Settings → Connection → Network Services → HTTP REST Server**
- **QR** icon button next to API token (enabled when REST Active + token present)
- Token **không** có trong `GET /api/v1/config`; **không** ghi token vào log

## Central App

1. Add Logger → Scan QR (ảnh PNG/JPG hoặc camera)
2. Parse JSON, kiểm tra `schema`
3. Lưu `api_token`, kết nối `http://{host}:{api_port}/api/v1/...` với header `Authorization: Bearer <api_token>`
4. Poll Modbus tại `{host}:{modbus_port}`, unit `modbus_unit_id`

## Xác minh

```bash
curl -s -H "Authorization: Bearer <api_token từ QR>" \
  "http://<host>:<api_port>/api/v1/health"
```

Kỳ vọng HTTP 200, body có `"ok": true`.

## Mẫu cố định (decoder test)

File mẫu không chứa token production:

- [`tests/fixtures/provision-qr-sample.json`](../tests/fixtures/provision-qr-sample.json)
- [`tests/fixtures/provision-qr-sample.png`](../tests/fixtures/provision-qr-sample.png) — QR encode JSON mẫu trên (dùng verify decoder Central)
