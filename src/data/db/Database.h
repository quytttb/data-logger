#pragma once
#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QString>

// Database initialisation and connection management (SQLite WAL).
class Database {
public:
    // Initialise the engine, create all tables and run in-place migrations.
    // Must be called once before any DAO access.
    static bool init(const QString &dbPath);

    // Open a new connection on the calling thread (Qt requires one QSqlDatabase
    // per thread). Always close with closeConnection() to avoid leaking
    // named connections in Qt's connection pool.
    static QSqlDatabase openConnection();

    // Close and unregister a connection opened with openConnection().
    // Prefer this over db.close() so the connection name is freed immediately.
    static void closeConnection(QSqlDatabase &db);

    // Apply all incremental schema migrations (idempotent).
    static bool migrate(QSqlDatabase &db);

private:
    static bool createTables(QSqlDatabase &db);
    static void applyPragmas(QSqlDatabase &db);
    static bool addColumnIfMissing(QSqlDatabase &db, const QString &table,
                                   const QString &column, const QString &definition);
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
