# Naming conventions (Data Logger)

Aligns with [central_logger](https://github.com/) architecture — C++ orchestration, QML presentation.

## C++ layers

| Type | Role | Examples |
|------|------|----------|
| **Controller** (`QML_SINGLETON`) | Global orchestration, workers, config | `MonitorController`, `SettingsController`, `TesterController`, `ReportController` |
| **ViewModel** (`QML_ELEMENT`, per-view or singleton when shared chrome needs it) | Page filters, async loading, table binding | `HistoryViewModel` |
| **Model** (`QAbstract*Model`) | Pure data for views | `MonitorModel`, `SensorListModel`, `HistoryTableModel` |

## QML

- Import modules: `DataLogger.Core`, `DataLogger.Network`, `DataLogger.Components`, `DataLogger.Theme`.
- Prefer **camelCase** for new QML-facing API (`refreshPorts`, `recordCount`).
- Legacy **snake_case** wrappers on `SensorListModel` remain until Settings QML is migrated.
- Use design tokens: `AppColors`, `AppTheme`, `AppTypography`; legacy `Theme.*` aliases stay for gradual migration.
- Notifications: `AppNotifier.show()` + `AppToastHost` in `Main.qml`; keep `MessagePopup` only for confirm dialogs.

## Signals

- User feedback: `messageSent(title, body)` on controllers → routed to `AppNotifier` in `Main.qml`.
- Config lifecycle: `configLoaded`, `configSaved` on `SettingsController`.

## Files

- Core history: `src/core/history/` (`HistoryRow`, `HistoryTableModel`, `HistoryViewModel`).
- Workers: `src/network/workers/` only (no duplicate `src/workers/`).
