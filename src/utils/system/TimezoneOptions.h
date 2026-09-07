#pragma once

#include <QList>
#include <QPair>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

// Single source of truth for the fixed UTC-offset timezone list.
//
// The same (label → IANA id) table feeds:
//   - SettingsGeneralTab dropdown model (via AppDefaultsQml::timezoneOptions)
//   - the legacy "UTC+7" → IANA migration in Database::migrate
//   - dropdown index lookup (AppDefaultsQml::timezoneIndex)
//
// IANA ids are the Etc/GMT fixed-offset zones that `timedatectl` accepts
// directly. Etc/GMT signs are inverted (UTC+7 == Etc/GMT-7) and carry no
// DST — ideal for stable logger timestamps.
namespace TimezoneOptions {

inline QList<QPair<QString, QString>> entries()
{
    return {
        {QStringLiteral("UTC-12"), QStringLiteral("Etc/GMT+12")},
        {QStringLiteral("UTC-11"), QStringLiteral("Etc/GMT+11")},
        {QStringLiteral("UTC-10"), QStringLiteral("Etc/GMT+10")},
        {QStringLiteral("UTC-9"),  QStringLiteral("Etc/GMT+9")},
        {QStringLiteral("UTC-8"),  QStringLiteral("Etc/GMT+8")},
        {QStringLiteral("UTC-7"),  QStringLiteral("Etc/GMT+7")},
        {QStringLiteral("UTC-6"),  QStringLiteral("Etc/GMT+6")},
        {QStringLiteral("UTC-5"),  QStringLiteral("Etc/GMT+5")},
        {QStringLiteral("UTC-4"),  QStringLiteral("Etc/GMT+4")},
        {QStringLiteral("UTC-3"),  QStringLiteral("Etc/GMT+3")},
        {QStringLiteral("UTC-2"),  QStringLiteral("Etc/GMT+2")},
        {QStringLiteral("UTC-1"),  QStringLiteral("Etc/GMT+1")},
        {QStringLiteral("UTC+0"),  QStringLiteral("Etc/GMT")},
        {QStringLiteral("UTC+1"),  QStringLiteral("Etc/GMT-1")},
        {QStringLiteral("UTC+2"),  QStringLiteral("Etc/GMT-2")},
        {QStringLiteral("UTC+3"),  QStringLiteral("Etc/GMT-3")},
        {QStringLiteral("UTC+4"),  QStringLiteral("Etc/GMT-4")},
        {QStringLiteral("UTC+5"),  QStringLiteral("Etc/GMT-5")},
        {QStringLiteral("UTC+5:30"), QStringLiteral("Asia/Kolkata")},
        {QStringLiteral("UTC+6"),  QStringLiteral("Etc/GMT-6")},
        {QStringLiteral("UTC+7"),  QStringLiteral("Etc/GMT-7")},
        {QStringLiteral("UTC+8"),  QStringLiteral("Etc/GMT-8")},
        {QStringLiteral("UTC+9"),  QStringLiteral("Etc/GMT-9")},
        {QStringLiteral("UTC+10"), QStringLiteral("Etc/GMT-10")},
        {QStringLiteral("UTC+11"), QStringLiteral("Etc/GMT-11")},
        {QStringLiteral("UTC+12"), QStringLiteral("Etc/GMT-12")},
    };
}

// QTimeZone may report UTC as "UTC", "Etc/UTC" or "GMT";
// the fixed-offset list uses "Etc/GMT" for UTC+0.
inline QString normalizeAlias(const QString &tz)
{
    if (tz == QStringLiteral("UTC") || tz == QStringLiteral("Etc/UTC")
        || tz == QStringLiteral("GMT"))
        return QStringLiteral("Etc/GMT");
    return tz;
}

// Index of an IANA id in entries() (-1 when absent).
inline int indexOf(const QString &iana)
{
    const QString norm = normalizeAlias(iana);
    const auto list = entries();
    for (int i = 0; i < list.size(); ++i) {
        if (list[i].second == norm)
            return i;
    }
    return -1;
}

// Dropdown model (list of {label, value} maps). A host timezone outside the
// fixed list is prepended as "System (<id>)" so it stays selectable.
inline QVariantList modelWithSystem(const QString &systemTz)
{
    QVariantList out;
    const auto list = entries();
    bool known = false;
    for (const auto &e : list) {
        if (e.second == systemTz)
            known = true;
        out.append(QVariantMap{{QStringLiteral("label"), e.first},
                               {QStringLiteral("value"), e.second}});
    }
    if (!known) {
        out.prepend(QVariantMap{
            {QStringLiteral("label"), QStringLiteral("System (%1)").arg(systemTz)},
            {QStringLiteral("value"), systemTz}});
    }
    return out;
}

} // namespace TimezoneOptions
