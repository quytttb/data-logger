#pragma once
#include <QObject>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"

// QML singleton: TT10 Bảng 34 symbol suggestions + display label helper.
class SensorSymbols : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QStringList symbols READ symbols CONSTANT)

public:
    explicit SensorSymbols(QObject *parent = nullptr);

    DECLARE_QML_SINGLETON(SensorSymbols)

    QStringList symbols() const;

    Q_INVOKABLE static QString displayLabel(const QString &sensorSymbol, const QString &name);
};
