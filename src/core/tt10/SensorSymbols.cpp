#include "SensorSymbols.h"
#include "utils/tt10/SensorSymbolCatalog.h"
#include "utils/qml/QmlSingleton.h"

IMPLEMENT_QML_SINGLETON(SensorSymbols)

SensorSymbols::SensorSymbols(QObject *parent) : QObject(parent) {}

QStringList SensorSymbols::symbols() const
{
    return SensorSymbolCatalog::allSymbols();
}

QString SensorSymbols::displayLabel(const QString &sensorSymbol, const QString &name)
{
    const QString sym = sensorSymbol.trimmed();
    if (sym.isEmpty())
        return name;
    if (name.trimmed().isEmpty())
        return sym;
    return sym + QStringLiteral(" - ") + name;
}
