#pragma once
#include <QAbstractListModel>
#include <QList>
#include <QHash>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"

// Live sensor card model for MonitorView.
class MonitorModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        SensorIdRole  = Qt::UserRole + 1,
        NameRole, UnitRole, ValueRole, RawValueRole,
        StatusRole, LastUpdateRole, IsAlarmRole, AlarmTypeRole,
        DiStatesRole, SensorTypeRole,
    };

    explicit MonitorModel(QObject *parent);

    DECLARE_QML_SINGLETON(MonitorModel)

    int      rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void loadSensors(const QList<QVariantMap> &sensors);
    void updateValue(int sensorId, double value, double rawValue,
                     const QString &recordedAt, bool isAlarm = false,
                     const QString &alarmType = {},
                     const QVariantList &diStates = {});
    void setSensorStatus(int sensorId, const QString &status);
    void setAllStatus(const QString &status);

signals:
    void countChanged();

private:
    struct Item {
        int     sensorId = 0;
        int     decimals = 4;
        QString name, unit, sensorType;
        QString value = "---", rawValue = "---";
        QString status = "WAIT", lastUpdate;
        bool    isAlarm = false;
        QString alarmType;
        QVariantList diStates;
    };

    QList<Item>      m_items;
    QHash<int, int>  m_idToRow;
};
