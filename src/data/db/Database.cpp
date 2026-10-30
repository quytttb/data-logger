#include "Database.h"
#include "utils/system/AppPaths.h"
#include "utils/system/TimezoneOptions.h"
#include <QSqlQuery>
#include <QSqlRecord>
#include <QDebug>
#include <QUuid>
#include <QThread>

static QString s_dbPath;

bool Database::init(const QString &dbPath) {
    s_dbPath = dbPath;
    QString connName = "main";
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(dbPath);

    if (!db.open()) {
        qCritical() << "Database::init failed to open:" << db.lastError().text();
        return false;
    }

    if (!applyPragmas(db)) {
        qCritical() << "Database::init applyPragmas failed";
        return false;
    }

    if (!createTables(db)) return false;
    if (!migrate(db))      return false;
    if (!ensureSchemaVersion(db)) return false;

    return true;
}

QSqlDatabase Database::openConnection() {
    // Use the thread pointer as the connection name so each thread always
    // reuses a single named connection — avoids Qt's "still in use" warning
    // that fires when removeDatabase is called while a DAO copy is alive.
    QString connName = QStringLiteral("thread_%1")
                           .arg(reinterpret_cast<quintptr>(QThread::currentThread()), 0, 16);

    if (QSqlDatabase::contains(connName)) {
        QSqlDatabase db = QSqlDatabase::database(connName, /*open=*/false);
        if (!db.isOpen()) {
            if (!db.open()) {
                qWarning() << "Database::openConnection failed to reopen" << connName
                           << db.lastError().text();
            } else if (!applyPragmas(db)) {
                qWarning() << "Database::openConnection applyPragmas failed for" << connName
                           << "— closing";
                db.close();
            }
        }
        return db;
    }

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(s_dbPath);
    if (!db.open()) {
        qWarning() << "Database::openConnection failed to open" << connName
                   << db.lastError().text();
        return db; // closed handle — caller phải kiểm tra isOpen()
    }
    if (!applyPragmas(db)) {
        qWarning() << "Database::openConnection applyPragmas failed for" << connName
                   << "— closing connection";
        db.close();
    }
    return db;
}

void Database::closeConnection(QSqlDatabase &db) {
    // With thread-local reuse the connection stays open between calls.
    // Just close and null the caller's handle; removeDatabase is NOT called
    // so DAO copies on the stack never trigger Qt's "still in use" warning.
    if (db.isValid())
        db.close();
    db = QSqlDatabase();
}

bool Database::applyPragmas(QSqlDatabase &db) {
    auto execPragma = [&](const QString &sql, bool required) -> bool {
        QSqlQuery q(db);
        if (!q.exec(sql)) {
            if (required)
                qWarning() << "applyPragmas failed (required):" << sql << q.lastError().text();
            else
                qDebug() << "applyPragmas failed (optional):" << sql << q.lastError().text();
            return !required;
        }
        return true;
    };

    // Required
    if (!execPragma(QStringLiteral("PRAGMA journal_mode = WAL;"), true)) return false;
    if (!execPragma(QStringLiteral("PRAGMA busy_timeout = 5000;"), true)) return false;
    if (!execPragma(QStringLiteral("PRAGMA foreign_keys = ON;"), true)) return false;

    // Verify required — nếu không đạt thì coi như failed
    {
        QSqlQuery q(db);
        if (q.exec(QStringLiteral("PRAGMA journal_mode;")) && q.next()) {
            const QString mode = q.value(0).toString().toLower();
            if (mode != QLatin1String("wal")) {
                qWarning() << "applyPragmas: journal_mode is" << mode << "expected wal — failing";
                return false;
            }
        } else {
            qWarning() << "applyPragmas: cannot query journal_mode" << q.lastError().text();
            return false;
        }
        if (q.exec(QStringLiteral("PRAGMA foreign_keys;")) && q.next()) {
            if (q.value(0).toInt() != 1) {
                qWarning() << "applyPragmas: foreign_keys not enabled — failing";
                return false;
            }
        } else {
            qWarning() << "applyPragmas: cannot query foreign_keys" << q.lastError().text();
            return false;
        }
        // busy_timeout cũng verify bằng đọc lại (best effort nhưng vẫn warn)
        if (q.exec(QStringLiteral("PRAGMA busy_timeout;")) && q.next()) {
            if (q.value(0).toInt() < 4000)
                qWarning() << "applyPragmas: busy_timeout too low:" << q.value(0).toInt();
        }
    }

    // Best-effort
    execPragma(QStringLiteral("PRAGMA synchronous = NORMAL;"), false);
    execPragma(QStringLiteral("PRAGMA journal_size_limit = 1000000;"), false);
    execPragma(QStringLiteral("PRAGMA mmap_size = 30000000;"), false);
    execPragma(QStringLiteral("PRAGMA temp_store = MEMORY;"), false);
    execPragma(QStringLiteral("PRAGMA cache_size = -20000;"), false);
    return true;
}

bool Database::createTables(QSqlDatabase &db) {
    QSqlQuery q(db);

    const QStringList stmts = {
        R"(CREATE TABLE IF NOT EXISTS app_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_code TEXT NOT NULL DEFAULT '',
            station_name TEXT NOT NULL DEFAULT '',
            time_format TEXT NOT NULL DEFAULT 'HH:mm:ss',
            date_format TEXT NOT NULL DEFAULT 'dd/MM/yyyy',
            timezone TEXT NOT NULL DEFAULT 'UTC',
            buzzer_enable INTEGER NOT NULL DEFAULT 0,
            ftp_address TEXT NOT NULL DEFAULT '',
            ftp_port INTEGER NOT NULL DEFAULT 21,
            ftp_username TEXT NOT NULL DEFAULT '',
            ftp_password TEXT NOT NULL DEFAULT '',
            ftp_remote_path TEXT NOT NULL DEFAULT '/',
            file_prefix TEXT NOT NULL DEFAULT '',
            poll_interval INTEGER NOT NULL DEFAULT 3,
            monitor_view_mode TEXT NOT NULL DEFAULT 'grid',
            monitor_show_digital_io INTEGER NOT NULL DEFAULT 1,
            serial_port TEXT NOT NULL DEFAULT '/dev/ttyUSB0',
            serial_baudrate INTEGER NOT NULL DEFAULT 9600,
            serial_bytesize INTEGER NOT NULL DEFAULT 8,
            serial_parity TEXT NOT NULL DEFAULT 'N',
            serial_stopbits INTEGER NOT NULL DEFAULT 1,
            server_active INTEGER NOT NULL DEFAULT 0,
            server_device_type TEXT NOT NULL DEFAULT 'Standard',
            server_name TEXT NOT NULL DEFAULT '',
            server_send_interval INTEGER NOT NULL DEFAULT 5,
            server_start_time TEXT NOT NULL DEFAULT '00:00',
            server_base_folder TEXT NOT NULL DEFAULT '',
            server_time_folder TEXT NOT NULL DEFAULT 'yyyy/MM/dd',
            file_suffix TEXT NOT NULL DEFAULT 'yyyyMMddHHmmss',
            modbus_tcp_enabled INTEGER NOT NULL DEFAULT 0,
            modbus_tcp_port INTEGER NOT NULL DEFAULT 5020,
            modbus_tcp_bind TEXT NOT NULL DEFAULT '0.0.0.0',
            modbus_tcp_unit_id INTEGER NOT NULL DEFAULT 1,
            rest_api_enabled INTEGER NOT NULL DEFAULT 0,
            rest_api_port INTEGER NOT NULL DEFAULT 8080,
            rest_api_bind TEXT NOT NULL DEFAULT '0.0.0.0',
            rest_api_token TEXT NOT NULL DEFAULT '',
            config_revision INTEGER NOT NULL DEFAULT 1,
            ui_locale TEXT NOT NULL DEFAULT 'vi',
            theme TEXT NOT NULL DEFAULT 'dark',
            auto_add_transmit INTEGER NOT NULL DEFAULT 1,
            -- Audit M5: alarm hysteresis (absolute, 0 = off) and configurable
            -- DO fail-safe policy on (re)connect.
            alarm_hysteresis REAL NOT NULL DEFAULT 0,
            do_failsafe_on_reconnect INTEGER NOT NULL DEFAULT 1
        ))",

        R"(CREATE TABLE IF NOT EXISTS sensor (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sensor_type TEXT NOT NULL DEFAULT 'ANALOG',
            name TEXT NOT NULL,
            unit TEXT NOT NULL DEFAULT '',
            slave_id INTEGER NOT NULL,
            register_address INTEGER NOT NULL,
            register_type TEXT NOT NULL DEFAULT 'holding',
            data_type TEXT NOT NULL DEFAULT 'int16',
            data_format TEXT NOT NULL DEFAULT 'AB',
            coefficient TEXT DEFAULT '{}',
            min_threshold REAL DEFAULT NULL,
            max_threshold REAL DEFAULT NULL,
            report_index INTEGER NOT NULL DEFAULT 0,
            decimals INTEGER NOT NULL DEFAULT 4,
            sensor_symbol TEXT NOT NULL DEFAULT '',
            transmit_enabled INTEGER NOT NULL DEFAULT 0,
            di_type TEXT DEFAULT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        ))",

        R"(CREATE TABLE IF NOT EXISTS sensor_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sensor_id INTEGER NOT NULL,
            raw_value REAL,
            value REAL,
            status TEXT DEFAULT NULL,
            is_alarm INTEGER NOT NULL DEFAULT 0,
            alarm_type TEXT NOT NULL DEFAULT '',
            recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (sensor_id) REFERENCES sensor(id)
        ))",

        R"(CREATE TABLE IF NOT EXISTS analog_digital_link (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            analog_sensor_id INTEGER NOT NULL,
            digital_sensor_id INTEGER NOT NULL,
            di_type TEXT,
            trigger_on_max INTEGER NOT NULL DEFAULT 1,
            trigger_on_min INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (analog_sensor_id) REFERENCES sensor(id),
            FOREIGN KEY (digital_sensor_id) REFERENCES sensor(id)
        ))",

        R"(CREATE TABLE IF NOT EXISTS report_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            retry_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        ))",

        R"(CREATE TABLE IF NOT EXISTS device_license (
            id INTEGER PRIMARY KEY,
            fingerprint TEXT NOT NULL,
            bound_at TEXT NOT NULL DEFAULT (datetime('now'))
        ))",

        // RBAC: tài khoản kiosk. password_hash là PBKDF2 (không bao giờ plaintext).
        // username UNIQUE COLLATE NOCASE để "Admin" và "admin" không trùng.
        R"(CREATE TABLE IF NOT EXISTS user_account (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL COLLATE NOCASE UNIQUE,
            display_name TEXT NOT NULL DEFAULT '',
            role TEXT NOT NULL CHECK (role IN ('viewer','operator','admin')),
            password_hash TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            must_change_password INTEGER NOT NULL DEFAULT 0,
            failed_attempts INTEGER NOT NULL DEFAULT 0,
            locked_until TEXT DEFAULT NULL,
            last_login_at TEXT DEFAULT NULL,
            created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
        ))",

        // Audit: giữ snapshot username/display_name để log còn đọc được khi
        // tài khoản bị đổi tên hoặc xóa. actor_user_id ON DELETE SET NULL.
        R"(CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            occurred_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            actor_kind TEXT NOT NULL DEFAULT 'system'
                CHECK (actor_kind IN ('local','system','remote_device')),
            actor_user_id INTEGER DEFAULT NULL,
            actor_username TEXT NOT NULL DEFAULT '',
            actor_display_name TEXT NOT NULL DEFAULT '',
            action TEXT NOT NULL,
            entity TEXT NOT NULL DEFAULT '',
            entity_id TEXT NOT NULL DEFAULT '',
            result TEXT NOT NULL DEFAULT 'ok'
                CHECK (result IN ('ok','denied','failed')),
            detail_json TEXT NOT NULL DEFAULT '{}',
            FOREIGN KEY (actor_user_id) REFERENCES user_account(id) ON DELETE SET NULL
        ))",

        // Hiệu chuẩn: mỗi lần áp dụng là một phiên (giữ lịch sử), điểm lưu riêng.
        // sensor.coefficient vẫn là nguồn runtime; bảng này không thay thế nó.
        R"(CREATE TABLE IF NOT EXISTS calibration_session (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sensor_id INTEGER NOT NULL,
            method TEXT NOT NULL DEFAULT 'linear',
            point_count INTEGER NOT NULL,
            a REAL NOT NULL,
            b REAL NOT NULL,
            r2 REAL DEFAULT NULL,
            max_residual REAL DEFAULT NULL,
            note TEXT NOT NULL DEFAULT '',
            created_by INTEGER DEFAULT NULL,
            created_by_username TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            FOREIGN KEY (sensor_id) REFERENCES sensor(id) ON DELETE CASCADE,
            FOREIGN KEY (created_by) REFERENCES user_account(id) ON DELETE SET NULL
        ))",

        R"(CREATE TABLE IF NOT EXISTS calibration_point (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            raw_value REAL NOT NULL,
            reference_value REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (session_id) REFERENCES calibration_session(id) ON DELETE CASCADE
        ))",

        // Indices for frequent queries
        "CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor_id ON sensor_data(sensor_id)",
        "CREATE INDEX IF NOT EXISTS idx_sensor_data_recorded_at ON sensor_data(recorded_at)",
        // M-3: composite index for the hot range query
        // "WHERE sensor_id=? AND recorded_at BETWEEN ? AND ?".
        "CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor_recorded ON sensor_data(sensor_id, recorded_at)",
        // Audit: lọc theo thời gian (màn tra cứu/retention) và theo actor/hành động.
        "CREATE INDEX IF NOT EXISTS idx_audit_log_occurred_at ON audit_log(occurred_at)",
        "CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action)",
        "CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON audit_log(actor_user_id)",
        // Hiệu chuẩn: lấy lịch sử mới nhất của một cảm biến + điểm theo phiên.
        "CREATE INDEX IF NOT EXISTS idx_calibration_session_sensor ON calibration_session(sensor_id, id)",
        "CREATE INDEX IF NOT EXISTS idx_calibration_point_session ON calibration_point(session_id)",
    };

    for (const QString &stmt : stmts) {
        if (!q.exec(stmt)) {
            qCritical() << "createTables error:" << q.lastError().text();
            return false;
        }
    }
    return true;
}

bool Database::migrate(QSqlDatabase &db) {
    // Ensure all columns from later revisions exist on old databases.
    struct ColDef { const char *table, *col, *def; };
    const ColDef additions[] = {
        {"sensor",      "decimals",      "INTEGER NOT NULL DEFAULT 4"},
        {"sensor_data", "status",        "TEXT DEFAULT NULL"},
        {"app_config",  "ui_locale",     "TEXT NOT NULL DEFAULT 'vi'"},
        {"app_config",  "ftp_protocol",  "TEXT NOT NULL DEFAULT 'sftp'"},
        {"app_config",  "modbus_tcp_enabled",  "INTEGER NOT NULL DEFAULT 0"},
        {"app_config",  "modbus_tcp_port",     "INTEGER NOT NULL DEFAULT 5020"},
        {"app_config",  "modbus_tcp_bind",     "TEXT NOT NULL DEFAULT '0.0.0.0'"},
        {"app_config",  "modbus_tcp_unit_id",  "INTEGER NOT NULL DEFAULT 1"},
        {"app_config",  "rest_api_enabled",    "INTEGER NOT NULL DEFAULT 0"},
        {"app_config",  "rest_api_port",       "INTEGER NOT NULL DEFAULT 8080"},
        {"app_config",  "rest_api_bind",       "TEXT NOT NULL DEFAULT '0.0.0.0'"},
        {"app_config",  "rest_api_token",      "TEXT NOT NULL DEFAULT ''"},
        {"app_config",  "config_revision",     "INTEGER NOT NULL DEFAULT 1"},
        {"app_config",  "theme",               "TEXT NOT NULL DEFAULT 'dark'"},
        {"sensor",      "parameter_code", "TEXT NOT NULL DEFAULT ''"},
        {"sensor",      "transmit_enabled", "INTEGER NOT NULL DEFAULT 0"},
        {"app_config",  "auto_add_transmit", "INTEGER NOT NULL DEFAULT 1"},
        {"report_log",  "remote_path",    "TEXT NOT NULL DEFAULT ''"},
        // Audit M5: alarm hysteresis + configurable DO fail-safe policy.
        {"app_config",  "alarm_hysteresis",        "REAL NOT NULL DEFAULT 0"},
        {"app_config",  "do_failsafe_on_reconnect", "INTEGER NOT NULL DEFAULT 1"},
        // Monitor view mode (grid/list)
        {"app_config",  "monitor_view_mode",       "TEXT NOT NULL DEFAULT 'grid'"},
        {"app_config",  "monitor_show_digital_io", "INTEGER NOT NULL DEFAULT 1"},
    };

    for (const auto &a : additions) {
        if (!addColumnIfMissing(db, a.table, a.col, a.def))
            return false;
    }

    // Rename legacy app_config columns to filePrefix / fileSuffix names.
    auto renameColumn = [&](const char *oldName, const char *newName) -> bool {
        QSqlQuery q(db);
        q.exec(QStringLiteral("PRAGMA table_info(app_config)"));
        bool hasOld = false;
        bool hasNew = false;
        while (q.next()) {
            const QString col = q.value("name").toString();
            if (col == QLatin1String(oldName)) hasOld = true;
            if (col == QLatin1String(newName)) hasNew = true;
        }
        if (!hasOld || hasNew)
            return true;
        QSqlQuery ren(db);
        const QString stmt = QStringLiteral("ALTER TABLE app_config RENAME COLUMN %1 TO %2")
                                 .arg(QString::fromLatin1(oldName), QString::fromLatin1(newName));
        if (ren.exec(stmt))
            return true;
        // Fallback: add → copy → drop (SQLite without RENAME support).
        if (!addColumnIfMissing(db, "app_config", newName,
                                QString::fromLatin1(oldName) == QLatin1String("ftp_prefix")
                                    ? QStringLiteral("TEXT NOT NULL DEFAULT ''")
                                    : QStringLiteral("TEXT NOT NULL DEFAULT 'yyyyMMddHHmmss'")))
            return false;
        QSqlQuery copy(db);
        copy.exec(QStringLiteral("UPDATE app_config SET %1 = %2").arg(
            QString::fromLatin1(newName), QString::fromLatin1(oldName)));
        return dropColumnIfExists(db, "app_config", oldName);
    };
    if (!renameColumn("ftp_prefix", "file_prefix"))
        return false;
    if (!renameColumn("server_file_suffix", "file_suffix"))
        return false;

    // Rename parameter_code → sensor_symbol on sensor table.
    auto renameSensorColumn = [&](const char *oldName, const char *newName) -> bool {
        QSqlQuery q(db);
        q.exec(QStringLiteral("PRAGMA table_info(sensor)"));
        bool hasOld = false;
        bool hasNew = false;
        while (q.next()) {
            const QString col = q.value("name").toString();
            if (col == QLatin1String(oldName)) hasOld = true;
            if (col == QLatin1String(newName)) hasNew = true;
        }
        if (!hasOld || hasNew)
            return true;
        QSqlQuery ren(db);
        const QString stmt = QStringLiteral("ALTER TABLE sensor RENAME COLUMN %1 TO %2")
                                 .arg(QString::fromLatin1(oldName), QString::fromLatin1(newName));
        if (ren.exec(stmt))
            return true;
        if (!addColumnIfMissing(db, "sensor", newName, QStringLiteral("TEXT NOT NULL DEFAULT ''")))
            return false;
        QSqlQuery copy(db);
        copy.exec(QStringLiteral("UPDATE sensor SET %1 = %2").arg(
            QString::fromLatin1(newName), QString::fromLatin1(oldName)));
        return dropColumnIfExists(db, "sensor", oldName);
    };
    if (!renameSensorColumn("parameter_code", "sensor_symbol"))
        return false;

    // Legacy 0/0 thresholds: không tự migrate nữa. Trước đây 0/0 từng được dùng
    // để biểu diễn "không ngưỡng" nhưng 0/0 cũng là giá trị hợp lệ cho sensor
    // quanh zero. Không có metadata để phân biệt nên để nguyên — user tự điều
    // chỉnh qua UI. Nếu cần, thêm màn hình xác nhận migration riêng.

    // Legacy: timezone was stored as an offset label ("UTC+7"). It is now an
    // IANA zone id that `timedatectl` accepts directly ("Etc/GMT-7"; the POSIX
    // sign is inverted). Rewrite any old rows in place. The mapping lives in
    // TimezoneOptions (single source of truth shared with the Settings UI).
    QSqlQuery tz(db);
    for (const auto &e : TimezoneOptions::entries()) {
        tz.prepare("UPDATE app_config SET timezone=:iana WHERE timezone=:legacy");
        tz.bindValue(":iana", e.second);
        tz.bindValue(":legacy", e.first);
        tz.exec();
    }

    // The "auto sync time" (NTP toggle) feature was removed; drop its column.
    if (!dropColumnIfExists(db, "app_config", "auto_sync_time"))
        return false;

    // Per-sensor poll_interval removed — all sensors now share AppConfig.pollInterval.
    if (!dropColumnIfExists(db, "sensor", "poll_interval"))
        return false;

    return true;
}

bool Database::ensureSchemaVersion(QSqlDatabase &db) {
    QSqlQuery read(db);
    if (!read.exec(QStringLiteral("PRAGMA user_version")) || !read.next()) {
        qCritical() << "Database::ensureSchemaVersion: không đọc được user_version:"
                    << read.lastError().text();
        return false;
    }
    const int version = read.value(0).toInt();

    if (version > kSchemaVersion) {
        qCritical() << "Database::ensureSchemaVersion: DB schema" << version
                    << "mới hơn app" << kSchemaVersion
                    << "— từ chối chạy để tránh hỏng dữ liệu (xóa DB nếu đang thử nghiệm)";
        return false;
    }
    if (version == kSchemaVersion)
        return true;

    // createTables() + migrate() đã chạy trước đó, nên schema đã ở bản hiện tại.
    // Khi thêm migration mới: viết bước nâng cấp trong migrate() TRƯỚC khi stamp.
    QSqlQuery stamp(db);
    if (!stamp.exec(QStringLiteral("PRAGMA user_version = %1").arg(kSchemaVersion))) {
        qCritical() << "Database::ensureSchemaVersion: không ghi được user_version:"
                    << stamp.lastError().text();
        return false;
    }
    qInfo() << "Database: schema version" << version << "->" << kSchemaVersion;
    return true;
}

bool Database::addColumnIfMissing(QSqlDatabase &db, const QString &table,
                                   const QString &column, const QString &definition) {
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table));
    while (q.next()) {
        if (q.value("name").toString() == column)
            return true; // already exists
    }
    QString stmt = QStringLiteral("ALTER TABLE %1 ADD COLUMN %2 %3").arg(table, column, definition);
    if (!q.exec(stmt)) {
        qWarning() << "addColumnIfMissing error:" << q.lastError().text();
        return false;
    }
    return true;
}

bool Database::dropColumnIfExists(QSqlDatabase &db, const QString &table,
                                   const QString &column) {
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table));
    bool present = false;
    while (q.next()) {
        if (q.value("name").toString() == column) {
            present = true;
            break;
        }
    }
    if (!present)
        return true; // already gone

    // Requires SQLite >= 3.35 (bundled with Qt 6). The column is not indexed or
    // referenced by a FK, so a plain DROP COLUMN is safe.
    QString stmt = QStringLiteral("ALTER TABLE %1 DROP COLUMN %2").arg(table, column);
    if (!q.exec(stmt)) {
        qWarning() << "dropColumnIfExists error:" << q.lastError().text();
        return false;
    }
    return true;
}
