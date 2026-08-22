# Material 3 — Component guidelines (Data Logger / Edge)

SoT component chung: [`shared/logger-ui-kit/README.md`](../../shared/logger-ui-kit/README.md)
(kit dùng chung với central_logger — không fork, không copy local).

Palette: **Teal** primary, **Indigo** accent; **dark only** (kiosk), touch targets ≥48dp
(`ThemeMode.touch = true`, bind trong `Main.qml`). Không dynamic color.

## Shell layout

```
ApplicationWindow (fullscreen kiosk, EGLFS)
└── RowLayout (horizontal)
    ├── AppSideBar (AppTheme.railWidth = 80)          ← edge-only
    └── ColumnLayout
        ├── MainHeaderChrome (+ *TaskBar theo tab)    ← edge-only
        └── MainTabContent (tabs, không Loader view)
```

## Tokens

| Token | Nguồn | Ghi chú |
|-------|-------|---------|
| Màu M3, text, semantic, chart series | `LoggerKit.Theme` → `AppColors` | light/dark qua `ThemeMode.mode`; edge cố định `"dark"` |
| Metrics, shape, spacing, motion | `LoggerKit.Theme` → `AppTheme` | `buttonHeight = touch ? 48 : 40`, `spacingXS…spacingL` |
| Typography | `LoggerKit.Theme` → `AppTypography` | |
| DI/DO indicator colors | `DataLogger.Theme` → `IoColors` | edge-only, không đưa vào kit |

**Rule:** cấm hardcode màu hex / `font.pixelSize` / spacing số trong views — luôn dùng token.
Legacy singleton `Theme.*` đã bị xóa; thay bằng `AppColors.*` / `AppTheme.*`.

## Components

Chung (từ `import LoggerKit.Components`): `AppButton` (kind enum + `fillColor` +
`iconSpinning`), `UiIcon`, `MaterialIcons`, `ElevatedPane`, `EmptyStatePlaceholder`,
`TableContentStack`, `AppTableView`, `TableHeaderCell`, `TableCellBackground`,
`AppScrollBar`, `AppNotifier`, `AppToastHost`, `MessageDetailDialog`, `DateField`,
`DatePickerPopup`, `ChartGraphsTheme`, `ChartGraphsView`, `ChartLinePointMarker`,
`StatusChip` (generic), `ClipboardService`.

Edge-only (`import DataLogger.Components`):

| Component | Notes |
|-----------|-------|
| `AppSideBar` | Rail điều hướng tab (Monitor/History/Trending/Settings/Tester) |
| `MainHeaderChrome` | Header + Loader taskbar theo tab hiện tại |
| `MonitorTaskBar` / `HistoryTaskBar` / `TrendingTaskBar` / `SettingsTaskBar` / `ModbusTesterTaskBar` | Taskbar mỗi tab; Start/Stop dùng `kind: Primary` + `fillColor: AppColors.success/error` |
| `ThemedTabButton` | Tab button cảm ứng |
| `MessagePopup` | Popup xác nhận/tin nhắn touch-friendly (thay AlertDialog desktop) |
| `sensor/*` | `SensorConfigForm`, `SensorBasicTab`, `SensorScalingTab`, `SensorDigitalIOTab`, `ProvisionQrPopup` |

## AppButton mapping (sau khi hợp nhất API với central)

| Cũ (edge) | Mới (kit) |
|-----------|-----------|
| `variant: "filled"` + `accent: <màu>` | `kind: AppButton.Primary` + `fillColor: <màu>` |
| `variant: "tonal"` | `kind: AppButton.Neutral` |
| `variant: "outlined"` | `kind: AppButton.Secondary` |
| toggle Read/Write (`variant` theo trạng thái) | `kind:` ternary `Primary : Secondary` |
| `iconSpinning` | giữ nguyên (kit hỗ trợ) |

## Notification policy

Giống central (xem kit README): toast qua `AppNotifier.show(...)` + `AppToastHost`
đặt 1 lần trong `Main.qml`; lỗi chi tiết mở `MessageDetailDialog` qua
`Connections { target: AppNotifier; onDetailRequested }`. Edge không dùng
`contextId`/copy-path (kiosk không có navigation giữa logger).

## Manual QA (dark)

- [ ] Monitor — sensor cards, DI/DO colors từ `IoColors`, Start/Stop fill đúng màu
- [ ] History — bảng trong `ElevatedPane`, DateField/DatePickerPopup từ kit
- [ ] Trending — chart nền khớp pane, marker từ kit
- [ ] Settings — form elevated, nút Save `fillColor: success`, Cancel `Neutral`
- [ ] Tester — toggle Read/Write `kind` chuyển đúng khi đổi mode
