#include "DeviceLock.h"
#include "DeviceId.h"
#include "AppPaths.h"
#include <QFile>
#include <QDir>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QtDebug>

namespace DeviceLock {

namespace {

// Backup file now lives in writable app data dir (not /var/lib which is root-only).
// This path is guaranteed writable by the kiosk user and created by AppPaths::ensureDirectories().
QString backupPath() {
    return AppPaths::dataDir() + QStringLiteral("/.device_key");
}

QString readDbFingerprint()
{
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("main"));
    if (!db.isValid() || !db.isOpen())
        return {};

    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("SELECT fingerprint FROM device_license LIMIT 1")))
        return {};
    if (!q.next())
        return {};
    return q.value(0).toString();
}

bool writeDbFingerprint(const QString &fingerprint)
{
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("main"));
    if (!db.isValid() || !db.isOpen())
        return false;

    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("DELETE FROM device_license")))
        return false;
    q.prepare(QStringLiteral(
        "INSERT INTO device_license (id, fingerprint) VALUES (1, :fp)"));
    q.bindValue(QStringLiteral(":fp"), fingerprint);
    return q.exec();
}

QString readFileFingerprint()
{
    QFile f(backupPath());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll()).trimmed();
}

bool writeFileFingerprint(const QString &fingerprint)
{
    // dataDir() is already created by AppPaths::ensureDirectories() in main
    QFile f(backupPath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qCritical() << "[DeviceLock] Failed to write backup file:" << backupPath();
        return false;
    }
    f.write(fingerprint.toUtf8());
    f.close();
    return true;
}

} // namespace

State check()
{
    const QString current = DeviceId::fingerprint();
    if (current.isEmpty()) {
        qWarning() << "[DeviceLock] No hardware serial — treating as unauthorized";
        return State::Unauthorized;
    }

    const QString dbFp   = readDbFingerprint();
    const QString fileFp = readFileFingerprint();
    const bool hasDb   = !dbFp.isEmpty();
    const bool hasFile = !fileFp.isEmpty();

    // First run: both stores empty → Unbound (will auto-bind)
    if (!hasDb && !hasFile)
        return State::Unbound;

    // Tamper detection: one store missing → Unauthorized (do NOT re-bind)
    // This prevents bypass by deleting just the DB row or just the file.
    if (!hasDb || !hasFile) {
        qCritical() << "[DeviceLock] Tamper detected: DB license=" << hasDb
                    << "backup file=" << hasFile << "— one store is missing";
        return State::Unauthorized;
    }

    // Both stores present: verify consistency and match current hardware
    if (dbFp != fileFp) {
        qCritical() << "[DeviceLock] Tamper detected: DB and backup file fingerprints mismatch";
        return State::Unauthorized;
    }
    
    if (dbFp != current) {
        qCritical() << "[DeviceLock] Hardware mismatch: stored fingerprint does not match current CPU serial"
                    << "— SD card likely moved to different device";
        return State::Unauthorized;
    }

    return State::Authorized;
}

bool bind()
{
    const QString fp = DeviceId::fingerprint();
    if (fp.isEmpty()) {
        qCritical() << "[DeviceLock] bind failed: empty hardware fingerprint";
        return false;
    }
    if (!writeDbFingerprint(fp)) {
        qCritical() << "[DeviceLock] bind failed: could not write DB license";
        return false;
    }
    if (!writeFileFingerprint(fp)) {
        qCritical() << "[DeviceLock] bind failed: could not write backup file";
        return false;
    }
    qInfo() << "[DeviceLock] Device bound, fingerprint" << fp.left(16) << "...";
    return true;
}

} // namespace DeviceLock
