#include "Database.h"
#include "utils/AppPaths.h"
#include <QSqlQuery>
#include <QSqlRecord>
#include <QDebug>
#include <QUuid>
#include <atomic>

static std::atomic<int> s_connCounter{0};
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
    int n = ++s_connCounter;
    QString connName = QStringLiteral("conn_%1").arg(n);
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(s_dbPath);
    db.open();
    applyPragmas(db);
    return db;
}

void Database::applyPragmas(QSqlDatabase &db) {
    QSqlQuery q(db);
    q.exec("PRAGMA journal_mode = WAL;");
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
            timezone TEXT NOT NULL DEFAULT 'UTC+7',
            auto_sync_time INTEGER NOT NULL DEFAULT 0,
            buzzer_enable INTEGER NOT NULL DEFAULT 0,
            ftp_address TEXT NOT NULL DEFAULT '',
            ftp_port INTEGER NOT NULL DEFAULT 21,
            ftp_username TEXT NOT NULL DEFAULT '',
            ftp_password TEXT NOT NULL DEFAULT '',
            ftp_remote_path TEXT NOT NULL DEFAULT '/',
            ftp_prefix TEXT NOT NULL DEFAULT '',
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
            server_file_suffix TEXT NOT NULL DEFAULT 'yyyyMMddHHmmss',
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
            theme TEXT NOT NULL DEFAULT 'dark'
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
        {"sensor_data", "status",        "TEXT DEFAULT NULL"},
        {"app_config",  "ui_locale",     "TEXT NOT NULL DEFAULT 'vi'"},
        {"app_config",  "ftp_prefix",    "TEXT NOT NULL DEFAULT ''"},
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
    };

    for (const auto &a : additions) {
        if (!addColumnIfMissing(db, a.table, a.col, a.def))
            return false;
    }
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
