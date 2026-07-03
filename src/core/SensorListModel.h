#pragma once
#include <QAbstractListModel>
#include <QList>
#include <QtQmlIntegration/qqmlintegration.h>
#include "data/models/Sensor.h"
#include "utils/qml/QmlSingleton.h"

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
        DecimalsRole,
        SensorTypeRole,
        ActiveRole,
        DiTypeRole,
        SensorSymbolRole,
        DisplayNameRole,
        TransmitEnabledRole,
    };

    explicit SensorListModel(QObject *parent);

    DECLARE_QML_SINGLETON(SensorListModel)

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool addSensor(const QVariantMap &props);

    // Returns monitor-ready maps for active sensors from the in-memory cache —
    // no extra DB round-trip needed when MonitorController refreshes after a save.
    QList<QVariantMap> activeMonitorMaps() const;
    Q_INVOKABLE bool updateSensor(int id, const QVariantMap &props);
    Q_INVOKABLE bool removeSensor(int id);
    Q_INVOKABLE QVariantMap sensorAt(int row) const;

    Q_INVOKABLE QVariantList get_analog_links(int analogSensorId) const;
    Q_INVOKABLE QVariantList list_di_sensors() const;
    Q_INVOKABLE QVariantList list_do_sensors(int analogSensorId) const;
    Q_INVOKABLE bool attach_di(int analogSensorId, int diSensorId, const QString &diType);
    Q_INVOKABLE bool attach_do(int analogSensorId, int doSensorId, bool trigMax, bool trigMin);
    Q_INVOKABLE bool detach_link(int linkId);
    Q_INVOKABLE bool update_link_di_type(int linkId, const QString &diType);
    Q_INVOKABLE bool update_link_do_triggers(int linkId, bool trigMax, bool trigMin);

    Q_INVOKABLE QVariantList transmissionRows() const;
    Q_INVOKABLE bool saveTransmission(const QVariantList &rows);
    Q_INVOKABLE bool setAllTransmitEnabled(bool enabled);
    Q_INVOKABLE bool removeFromTransmission(const QVariantList &sensorIds);

signals:
    void countChanged();
    void messageSent(QString title, QString body);
    // Emitted after any DI/DO link add/update/remove so that MonitorController
    // and other observers can refresh their link-derived state (diLegend, etc.).
    void linksChanged();

private:
    void loadFromDb();
    Sensor variantToSensor(const QVariantMap &props, int existingId = 0) const;
    QVariantMap sensorToVariant(const Sensor &s) const;
    const Sensor *findSensorById(int id) const;

    QList<Sensor> m_sensors;
};
