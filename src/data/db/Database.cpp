#include "Database.h"
#include "utils/system/AppPaths.h"
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

    applyPragmas(db);

    if (!createTables(db)) return false;
    if (!migrate(db))      return false;

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
            db.open();
            applyPragmas(db);
        }
        return db;
    }

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(s_dbPath);
    db.open();
    applyPragmas(db);
    return db;
}

void Database::closeConnection(QSqlDatabase &db) {
    // With thread-local reuse the connection stays open between calls.
    // Just close and null the caller's handle; removeDatabase is NOT called
    // so DAO copies on the stack never trigger Qt's "still in use" warning.
    db.close();
    db = QSqlDatabase();
}

void Database::applyPragmas(QSqlDatabase &db) {
    QSqlQuery q(db);
    q.exec("PRAGMA journal_mode = WAL;");
    q.exec("PRAGMA busy_timeout = 5000;");
    q.exec("PRAGMA synchronous = NORMAL;");
    q.exec("PRAGMA journal_size_limit = 1000000;");
    q.exec("PRAGMA mmap_size = 30000000;");
    q.exec("PRAGMA temp_store = MEMORY;");
    q.exec("PRAGMA cache_size = -20000;");
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
            timezone TEXT NOT NULL DEFAULT 'Etc/GMT-7',
            buzzer_enable INTEGER NOT NULL DEFAULT 0,
            ftp_address TEXT NOT NULL DEFAULT '',
            ftp_port INTEGER NOT NULL DEFAULT 21,
            ftp_username TEXT NOT NULL DEFAULT '',
            ftp_password TEXT NOT NULL DEFAULT '',
            ftp_remote_path TEXT NOT NULL DEFAULT '/',
            file_prefix TEXT NOT NULL DEFAULT '',
            poll_interval INTEGER NOT NULL DEFAULT 3,
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
            auto_add_transmit INTEGER NOT NULL DEFAULT 1
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
            poll_interval INTEGER NOT NULL DEFAULT 3,
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

        // Indices for frequent queries
        "CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor_id ON sensor_data(sensor_id)",
        "CREATE INDEX IF NOT EXISTS idx_sensor_data_recorded_at ON sensor_data(recorded_at)",
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

    // Legacy: empty thresholds were saved as 0.0 instead of NULL.
    QSqlQuery fix(db);
    fix.exec("UPDATE sensor SET min_threshold=NULL, max_threshold=NULL "
             "WHERE min_threshold=0 AND max_threshold=0");

    // Legacy: timezone was stored as an offset label ("UTC+7"). It is now an
    // IANA zone id that `timedatectl` accepts directly ("Etc/GMT-7"; the POSIX
    // sign is inverted). Rewrite any old rows in place.
    struct TzMigration { const char *legacy, *iana; };
    static const TzMigration tzMigrations[] = {
        {"UTC-12", "Etc/GMT+12"}, {"UTC-11", "Etc/GMT+11"}, {"UTC-10", "Etc/GMT+10"},
        {"UTC-9",  "Etc/GMT+9"},  {"UTC-8",  "Etc/GMT+8"},  {"UTC-7",  "Etc/GMT+7"},
        {"UTC-6",  "Etc/GMT+6"},  {"UTC-5",  "Etc/GMT+5"},  {"UTC-4",  "Etc/GMT+4"},
        {"UTC-3",  "Etc/GMT+3"},  {"UTC-2",  "Etc/GMT+2"},  {"UTC-1",  "Etc/GMT+1"},
        {"UTC+0",  "Etc/GMT"},    {"UTC+1",  "Etc/GMT-1"},  {"UTC+2",  "Etc/GMT-2"},
        {"UTC+3",  "Etc/GMT-3"},  {"UTC+4",  "Etc/GMT-4"},  {"UTC+5",  "Etc/GMT-5"},
        {"UTC+5:30", "Asia/Kolkata"},
        {"UTC+6",  "Etc/GMT-6"},  {"UTC+7",  "Etc/GMT-7"},  {"UTC+8",  "Etc/GMT-8"},
        {"UTC+9",  "Etc/GMT-9"},  {"UTC+10", "Etc/GMT-10"}, {"UTC+11", "Etc/GMT-11"},
        {"UTC+12", "Etc/GMT-12"},
    };
    QSqlQuery tz(db);
    for (const auto &m : tzMigrations) {
        tz.prepare("UPDATE app_config SET timezone=:iana WHERE timezone=:legacy");
        tz.bindValue(":iana", QString::fromLatin1(m.iana));
        tz.bindValue(":legacy", QString::fromLatin1(m.legacy));
        tz.exec();
    }

    // The "auto sync time" (NTP toggle) feature was removed; drop its column.
    if (!dropColumnIfExists(db, "app_config", "auto_sync_time"))
        return false;

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
