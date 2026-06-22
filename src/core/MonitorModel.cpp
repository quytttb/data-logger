#include "MonitorModel.h"
#include <QDateTime>
#include <QQmlEngine>
#include <QJSEngine>

IMPLEMENT_QML_SINGLETON(MonitorModel)

MonitorModel::MonitorModel(QObject *parent) : QAbstractListModel(parent) {}

int MonitorModel::rowCount(const QModelIndex &) const { return m_items.size(); }

QHash<int, QByteArray> MonitorModel::roleNames() const {
    return {
        {SensorIdRole,  "sensorId"},
        {NameRole,      "name"},
        {UnitRole,      "unit"},
        {ValueRole,     "value"},
        {RawValueRole,  "rawValue"},
        {StatusRole,    "status"},
        {LastUpdateRole,"lastUpdate"},
        {IsAlarmRole,   "isAlarm"},
        {AlarmTypeRole, "alarmType"},
        {DiStatesRole,  "diStates"},
        {SensorTypeRole,"sensorType"},
    };
}

QVariant MonitorModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size()) return {};
    const Item &it = m_items[index.row()];
    switch (role) {
    case SensorIdRole:   return it.sensorId;
    case NameRole:       return it.name;
    case UnitRole:       return it.unit;
    case ValueRole:      return it.value;
    case RawValueRole:   return it.rawValue;
    case StatusRole:     return it.status;
    case LastUpdateRole: return it.lastUpdate;
    case IsAlarmRole:    return it.isAlarm;
    case AlarmTypeRole:  return it.alarmType;
    case DiStatesRole:   return it.diStates;
    case SensorTypeRole: return it.sensorType;
    default:             return {};
    }
}

void MonitorModel::loadSensors(const QList<QVariantMap> &sensors) {
    beginResetModel();
    m_items.clear();
    m_idToRow.clear();
    for (int i = 0; i < sensors.size(); ++i) {
        const auto &s = sensors[i];
        Item it;
        it.sensorId   = s["id"].toInt();
        it.name       = s["name"].toString();
        it.unit       = s["unit"].toString();
        it.decimals   = s.value("decimals", 4).toInt();
        it.sensorType = s.value("sensor_type", "ANALOG").toString();
        m_items.append(it);
        m_idToRow[it.sensorId] = i;
    }
    endResetModel();
    emit countChanged();
}

void MonitorModel::updateValue(int sensorId, double value, double rawValue,
                                const QString &recordedAt, bool isAlarm,
                                const QString &alarmType, const QVariantList &diStates) {
    auto rowIt = m_idToRow.find(sensorId);
    if (rowIt == m_idToRow.end()) return;
    int row = rowIt.value();
    Item &it = m_items[row];

    if (it.sensorType == "DI" || it.sensorType == "DO") {
        bool on = value >= 0.5;
        it.value    = on ? "1" : "0";
        it.rawValue = it.value;
        it.status   = on ? "ON" : "OFF";
        it.isAlarm  = false;
        it.alarmType.clear();
    } else {
        it.value    = QString::number(value, 'f', it.decimals);
        // RAW is the unscaled register reading — show it faithfully (no rounding):
        // integer register types as integers, float32 at full single-precision.
        const qint64 rawAsInt = static_cast<qint64>(rawValue);
        it.rawValue = (static_cast<double>(rawAsInt) == rawValue)
                          ? QString::number(rawAsInt)
                          : QString::number(rawValue, 'g', 7);
        it.status   = isAlarm ? "ALARM" : "OK";
        it.isAlarm  = isAlarm;
        it.alarmType= alarmType;
    }

    if (!diStates.isEmpty()) it.diStates = diStates;

    // Parse time component
    QDateTime dt = QDateTime::fromString(recordedAt, Qt::ISODate);
    it.lastUpdate = dt.isValid() ? dt.toString("HH:mm:ss") : recordedAt;

    auto idx = index(row, 0);
    emit dataChanged(idx, idx, {});
}

void MonitorModel::setSensorStatus(int sensorId, const QString &status) {
    auto rowIt = m_idToRow.find(sensorId);
    if (rowIt == m_idToRow.end()) return;
    int row = rowIt.value();
    m_items[row].status = status;
    auto idx = index(row, 0);
    emit dataChanged(idx, idx, {StatusRole});
}

void MonitorModel::setAllStatus(const QString &status) {
    if (m_items.isEmpty()) return;
    for (auto &it : m_items) it.status = status;
    emit dataChanged(index(0, 0), index(m_items.size() - 1, 0), {StatusRole});
}
