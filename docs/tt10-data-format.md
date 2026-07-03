# TT10 data format (Thông tư 10/2021 — Phụ lục 15)

## File naming

| App field | DB column | TT10 | Example |
|-----------|-----------|------|---------|
| `filePrefix` | `file_prefix` | `TenTinh_TenCoSo_TenTram_` | `HN_ABCD_NUO001_` |
| `fileSuffix` | `file_suffix` | `Thoigian` (Qt date pattern) | `yyyyMMddHHmmss` |
| `serverBaseFolder` | `server_base_folder` | Station folder (`TenTram`) | `NUO001` |
| `serverTimeFolder` | `server_time_folder` | Date subfolder | `yyyy/MM/dd` |

**File name:** `filePrefix + QDateTime::toString(fileSuffix) + ".txt"`

**Remote directory:** `ftpRemotePath` + `serverBaseFolder` + formatted `serverTimeFolder`

## File content (TAB-separated)

For each active ANALOG sensor with `transmit_enabled`, five columns repeat:

`sensor_symbol` TAB `value` TAB `unit` TAB `timestamp` TAB `status`

- **sensor_symbol:** `sensor.sensorSymbol` (Bảng 34 TT10); fallback: `sensor.name`
- **status:** pass-through from `sensor_data.status` (`00`/`01`/`02` TT10; `03` maintenance is internal)

## Sensor UI

- ComboBox **Ký hiệu cảm biến** on add/edit (ANALOG only); suggestions from `SensorSymbols.symbols` (Bảng 34)
- Display label: `sensorSymbol - name` in Settings table and Monitor cards
- **Thông số truyền** tab: choose sensors, edit `sensorSymbol`, toggle `transmit_enabled`

## Status codes

| Code | TT10 | Notes |
|------|------|-------|
| `00` | Đang đo | |
| `01` | Hiệu chuẩn | |
| `02` | Báo lỗi | |
| `03` | — | Internal maintenance; written as-is |
