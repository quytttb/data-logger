#pragma once
#include <QAbstractListModel>
#include <QList>
#include "../models/Sensor.h"

// Exposes the sensor list (from DB) to QML for the Settings sensor table.
class SensorListModel : public QAbstractListModel {
    Q_OBJECT
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

    explicit SensorListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool addSensor(const QVariantMap &props);
    Q_INVOKABLE bool updateSensor(int id, const QVariantMap &props);
    Q_INVOKABLE bool removeSensor(int id);
    Q_INVOKABLE QVariantMap sensorAt(int row) const;

signals:
    void countChanged();

private:
    void loadFromDb();
    Sensor variantToSensor(const QVariantMap &props, int existingId = 0) const;
    QVariantMap sensorToVariant(const Sensor &s) const;

    QList<Sensor> m_sensors;
};
