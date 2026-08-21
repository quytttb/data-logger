#pragma once
#include <QObject>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"

// QML singleton: tập các giá trị mặc định/danh sách dùng chung giữa UI và C++
// (AppConfig struct + Database schema + REST validation). Tên QML: `AppDefaults`.
class AppDefaultsQml : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(AppDefaults)
    QML_SINGLETON

    Q_PROPERTY(int modbusTcpPort READ modbusTcpPort CONSTANT)
    Q_PROPERTY(int restApiPort READ restApiPort CONSTANT)
    Q_PROPERTY(QString bindAny READ bindAny CONSTANT)
    Q_PROPERTY(QString timezone READ timezone CONSTANT)
    Q_PROPERTY(QString timeFormat READ timeFormat CONSTANT)
    Q_PROPERTY(QString dateFormat READ dateFormat CONSTANT)
    Q_PROPERTY(QStringList baudrates READ baudrates CONSTANT)
    Q_PROPERTY(QStringList dataTypes READ dataTypes CONSTANT)
    Q_PROPERTY(QStringList byteOrders READ byteOrders CONSTANT)
    Q_PROPERTY(QStringList parityOptions READ parityOptions CONSTANT)

public:
    explicit AppDefaultsQml(QObject *parent = nullptr);

    DECLARE_QML_SINGLETON(AppDefaultsQml)

    int modbusTcpPort() const;
    int restApiPort() const;
    QString bindAny() const;
    QString timezone() const;
    QString timeFormat() const;
    QString dateFormat() const;
    QStringList baudrates() const;
    QStringList dataTypes() const;
    QStringList byteOrders() const;
    QStringList parityOptions() const;
};