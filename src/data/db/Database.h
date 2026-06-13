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
    // per thread). Caller must call .close() when done.
    static QSqlDatabase openConnection();

    // Apply all incremental schema migrations (idempotent).
    static bool migrate(QSqlDatabase &db);

private:
    static bool createTables(QSqlDatabase &db);
    static void applyPragmas(QSqlDatabase &db);
    static bool addColumnIfMissing(QSqlDatabase &db, const QString &table,
                                   const QString &column, const QString &definition);
};
