#pragma once

#include <QList>
#include <QPair>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

// Single source of truth for the application-level UI locale list (vi/en).
//
// The same (label → code) table feeds:
//   - SettingsGeneralTab dropdown model (via AppDefaultsQml::localeOptions)
//   - default fallback in AppConfig / DAO
//   - dropdown index lookup (AppDefaultsQml::localeIndex)
//
// The edge runs as a Vietnam-only kiosk, so the boot/system default is "vi".
// The stored value is applied at boot via QLocale::setDefault().
namespace LocaleOptions {

inline QList<QPair<QString, QString>> entries()
{
    return {
        {QStringLiteral("Tiếng Việt"), QStringLiteral("vi")},
        {QStringLiteral("English"),    QStringLiteral("en")},
    };
}

// Index of a locale code in entries() (-1 when absent).
inline int indexOf(const QString &code)
{
    const auto list = entries();
    for (int i = 0; i < list.size(); ++i) {
        if (list[i].second == code)
            return i;
    }
    return -1;
}

// Dropdown model (list of {label, value} maps).
inline QVariantList model()
{
    QVariantList out;
    for (const auto &e : entries())
        out.append(QVariantMap{{QStringLiteral("label"), e.first},
                               {QStringLiteral("value"), e.second}});
    return out;
}

} // namespace LocaleOptions
