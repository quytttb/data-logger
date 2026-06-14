#pragma once
#include <QAbstractListModel>
#include <QList>
#include <QtQmlIntegration/qqmlintegration.h>
#include "data/models/Sensor.h"

class QJSEngine;
class QQmlEngine;

// Exposes the sensor list (from DB) to QML for the Settings sensor table.
class SensorListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        SensorIdRole = Qt::UserRole + 1,
        NameRole,
        UnitRole,
        SlaveIdRole,
        RegisterAddressRole,
        RegisterTypeRole,
        DataTypeRole,
        DataFormatRole,
        CoefficientRole,
        MinThresholdRole,
        MaxThresholdRole,
        PollIntervalRole,
        ReportIndexRole,
        SensorTypeRole,
        ActiveRole,
        DiTypeRole,
    };

    explicit SensorListModel(QObject *parent);

    static SensorListModel *instance();
    static void setInstance(SensorListModel *model);
    static SensorListModel *create(QQmlEngine *, QJSEngine *);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool addSensor(const QVariantMap &props);
    Q_INVOKABLE bool updateSensor(int id, const QVariantMap &props);
    Q_INVOKABLE bool removeSensor(int id);
    Q_INVOKABLE QVariantMap sensorAt(int row) const;

    // Python-era QML wrappers (delegate to camelCase implementations)
    Q_INVOKABLE QVariantMap get_sensor(int row) const { return sensorAt(row); }
    Q_INVOKABLE bool remove_sensor(int id) { return removeSensor(id); }
    Q_INVOKABLE bool add_sensor(const QString &name, const QString &unit, int slaveId,
                                int registerAddress, const QString &registerType,
                                const QString &dataType, const QString &dataFormat,
                                const QString &coefficient, int pollInterval, int reportIndex,
                                bool active, const QVariant &minThreshold,
                                const QVariant &maxThreshold,
                                const QString &sensorType = QStringLiteral("ANALOG"));
    Q_INVOKABLE bool update_sensor(int id, const QString &name, const QString &unit,
                                   int slaveId, int registerAddress,
                                   const QString &registerType, const QString &dataType,
                                   const QString &dataFormat, const QString &coefficient,
                                   int pollInterval, int reportIndex, bool active,
                                   const QVariant &minThreshold, const QVariant &maxThreshold,
                                   const QString &sensorType = QStringLiteral("ANALOG"));

    Q_INVOKABLE QVariantList get_analog_links(int analogSensorId) const;
    Q_INVOKABLE QVariantList list_di_sensors() const;
    Q_INVOKABLE QVariantList list_do_sensors(int analogSensorId) const;
    Q_INVOKABLE bool attach_di(int analogSensorId, int diSensorId, const QString &diType);
    Q_INVOKABLE bool attach_do(int analogSensorId, int doSensorId, bool trigMax, bool trigMin);
    Q_INVOKABLE bool detach_link(int linkId);
    Q_INVOKABLE bool update_link_di_type(int linkId, const QString &diType);
    Q_INVOKABLE bool update_link_do_triggers(int linkId, bool trigMax, bool trigMin);

signals:
    void countChanged();
    void messageSent(QString title, QString body);

private:
    void loadFromDb();
    Sensor variantToSensor(const QVariantMap &props, int existingId = 0) const;
    QVariantMap sensorToVariant(const Sensor &s) const;
    const Sensor *findSensorById(int id) const;

    QList<Sensor> m_sensors;
};
