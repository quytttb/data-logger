#pragma once
#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QString>

// Database initialisation and connection management (SQLite WAL).
class Database {
public:
    // Phiên bản schema hiện tại, lưu trong PRAGMA user_version. Khi thêm bước
    // migration mới: tăng số này VÀ thêm bước tương ứng vào migrate() trước
    // khi stamp — nếu không DB cũ sẽ được đánh dấu là đã nâng cấp.
    static constexpr int kSchemaVersion = 1;

    // Initialise the engine, create all tables and run in-place migrations.
    // Must be called once before any DAO access.
    static bool init(const QString &dbPath);


    // Open a new connection on the calling thread (Qt requires one QSqlDatabase
    // per thread). Reuses a thread-local named connection. Log đầy đủ nếu
    // open() thất bại — caller nên kiểm tra isOpen().
    static QSqlDatabase openConnection();

    // Close a connection opened with openConnection(). Với thread-local reuse
    // thì không gọi removeDatabase() — chỉ close handle.
    static void closeConnection(QSqlDatabase &db);

    // Apply all incremental schema migrations (idempotent).
    static bool migrate(QSqlDatabase &db);

private:
    static bool createTables(QSqlDatabase &db);
    // Đọc/ghi PRAGMA user_version; từ chối DB mới hơn app (downgrade).
    static bool ensureSchemaVersion(QSqlDatabase &db);
    // Trả false nếu required pragma (FK, busy_timeout, WAL) không áp dụng được.
    static bool applyPragmas(QSqlDatabase &db);
    static bool addColumnIfMissing(QSqlDatabase &db, const QString &table,
                                   const QString &column, const QString &definition);
    static bool dropColumnIfExists(QSqlDatabase &db, const QString &table,
                                   const QString &column);
};

// RAII wrapper around Database::openConnection()/closeConnection(). The
// connection is opened on construction and guaranteed to be closed when the
// object goes out of scope, even on early return or exception. This avoids
// leaking named connections in Qt's connection pool.
class ScopedDbConnection {
public:
    ScopedDbConnection() : m_db(Database::openConnection()) {}
    ~ScopedDbConnection() { Database::closeConnection(m_db); }

    QSqlDatabase &get() { return m_db; }
    operator QSqlDatabase &() { return m_db; }

    // Non-copyable: copying would close the same handle twice in the destructor.
    ScopedDbConnection(const ScopedDbConnection &) = delete;
    ScopedDbConnection &operator=(const ScopedDbConnection &) = delete;

private:
    QSqlDatabase m_db;
};
