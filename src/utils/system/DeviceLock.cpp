#include "DeviceLock.h"
#include "DeviceId.h"
#include <QFile>
#include <QDir>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QtDebug>

namespace DeviceLock {

namespace {

constexpr auto kBackupPath = "/var/lib/datalogger/.device_key";

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
    QFile f(QString::fromLatin1(kBackupPath));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll()).trimmed();
}

bool writeFileFingerprint(const QString &fingerprint)
{
    QDir().mkpath(QStringLiteral("/var/lib/datalogger"));
    QFile f(QString::fromLatin1(kBackupPath));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return false;
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

    if (!hasDb && !hasFile)
        return State::Unbound;

    if (!hasDb || !hasFile)
        return State::Unauthorized;

    if (dbFp != fileFp || dbFp != current)
        return State::Unauthorized;

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
