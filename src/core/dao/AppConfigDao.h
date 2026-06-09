#pragma once
#include "../../models/AppConfig.h"
#include <QSqlDatabase>
#include <optional>

class AppConfigDao {
public:
    explicit AppConfigDao(QSqlDatabase db);

    // Returns the single config row, or a default-constructed AppConfig if none exists.
    AppConfig load();

    // Upserts the single config row. Returns true on success.
    bool save(const AppConfig &cfg);

    // Increment config_revision and return the new value.
    int bumpRevision();

    // Generate and persist a random REST API token.
    QString generateAndSaveToken();

private:
    QSqlDatabase m_db;
    AppConfig rowToConfig(const class QSqlRecord &rec);
};
