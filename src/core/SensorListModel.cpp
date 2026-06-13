#include "SensorListModel.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include <QVariant>

SensorListModel::SensorListModel(QObject *parent) : QAbstractListModel(parent) {
    loadFromDb();
}

int SensorListModel::rowCount(const QModelIndex &) const {
    return m_sensors.size();
}

QHash<int, QByteArray> SensorListModel::roleNames() const {
    return {
        {SensorIdRole,         "sensorId"},
        {NameRole,             "name"},
        {UnitRole,             "unit"},
        {SlaveIdRole,          "slaveId"},
        {RegisterAddressRole,  "registerAddress"},
        {RegisterTypeRole,     "registerType"},
        {DataTypeRole,         "dataType"},
        {DataFormatRole,       "dataFormat"},
        {CoefficientRole,      "coefficient"},
        {MinThresholdRole,     "minThreshold"},
        {MaxThresholdRole,     "maxThreshold"},
        {PollIntervalRole,     "pollInterval"},
        {ReportIndexRole,      "reportIndex"},
        {SensorTypeRole,       "sensorType"},
        {ActiveRole,           "active"},
        {DiTypeRole,           "diType"},
    };
}

QVariant SensorListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_sensors.size()) return {};
    const Sensor &s = m_sensors[index.row()];
    switch (role) {
    case SensorIdRole:        return s.id;
    case NameRole:            return s.name;
    case UnitRole:            return s.unit;
    case SlaveIdRole:         return s.slaveId;
    case RegisterAddressRole: return s.registerAddress;
    case RegisterTypeRole:    return s.registerType;
    case DataTypeRole:        return s.dataType;
    case DataFormatRole:      return s.dataFormat;
    case CoefficientRole:     return s.coefficient;
    case MinThresholdRole:    return s.minThreshold.has_value() ? QVariant(*s.minThreshold) : QVariant();
    case MaxThresholdRole:    return s.maxThreshold.has_value() ? QVariant(*s.maxThreshold) : QVariant();
    case PollIntervalRole:    return s.pollInterval;
    case ReportIndexRole:     return s.reportIndex;
    case SensorTypeRole:      return sensorTypeToString(s.sensorType);
    case ActiveRole:          return s.active;
    case DiTypeRole:          return s.diType;
    default:                  return {};
    }
}

QVariantMap SensorListModel::sensorToVariant(const Sensor &s) const {
    QVariantMap m;
    m["sensorId"]        = s.id;
    m["name"]            = s.name;
    m["unit"]            = s.unit;
    m["slaveId"]         = s.slaveId;
    m["registerAddress"] = s.registerAddress;
    m["registerType"]    = s.registerType;
    m["dataType"]        = s.dataType;
    m["dataFormat"]      = s.dataFormat;
    m["coefficient"]     = s.coefficient;
    m["minThreshold"]    = s.minThreshold.has_value() ? QVariant(*s.minThreshold) : QVariant();
    m["maxThreshold"]    = s.maxThreshold.has_value() ? QVariant(*s.maxThreshold) : QVariant();
    m["pollInterval"]    = s.pollInterval;
    m["reportIndex"]     = s.reportIndex;
    m["sensorType"]      = sensorTypeToString(s.sensorType);
    m["active"]          = s.active;
    m["diType"]          = s.diType;
    return m;
}

QVariantMap SensorListModel::sensorAt(int row) const {
    if (row < 0 || row >= m_sensors.size()) return {};
    return sensorToVariant(m_sensors[row]);
}

void SensorListModel::refresh() {
    loadFromDb();
}

void SensorListModel::loadFromDb() {
    beginResetModel();
    auto db = Database::openConnection();
    SensorDao dao(db);
    m_sensors = dao.loadAll();
    db.close();
    endResetModel();
    emit countChanged();
}

Sensor SensorListModel::variantToSensor(const QVariantMap &p, int existingId) const {
    Sensor s;
    s.id             = existingId;
    s.name           = p.value("name").toString();
    s.unit           = p.value("unit").toString();
    s.slaveId        = p.value("slaveId", 1).toInt();
    s.registerAddress= p.value("registerAddress", 0).toInt();
    s.registerType   = p.value("registerType", "holding").toString();
    s.dataType       = p.value("dataType", "int16").toString();
    s.dataFormat     = p.value("dataFormat", "AB").toString();
    s.coefficient    = p.value("coefficient", "{}").toString();
    auto minV = p.value("minThreshold");
    if (!minV.isNull()) s.minThreshold = minV.toDouble();
    auto maxV = p.value("maxThreshold");
    if (!maxV.isNull()) s.maxThreshold = maxV.toDouble();
    s.pollInterval   = p.value("pollInterval", 3).toInt();
    s.reportIndex    = p.value("reportIndex", 0).toInt();
    s.sensorType     = sensorTypeFromString(p.value("sensorType", "ANALOG").toString());
    s.active         = p.value("active", true).toBool();
    s.diType         = p.value("diType").toString();
    return s;
}

bool SensorListModel::addSensor(const QVariantMap &props) {
    Sensor s = variantToSensor(props);
    auto db = Database::openConnection();
    SensorDao dao(db);
    bool ok = dao.save(s);
    db.close();
    if (ok) loadFromDb();
    return ok;
}

bool SensorListModel::updateSensor(int id, const QVariantMap &props) {
    Sensor s = variantToSensor(props, id);
    auto db = Database::openConnection();
    SensorDao dao(db);
    bool ok = dao.save(s);
    db.close();
    if (ok) loadFromDb();
    return ok;
}

bool SensorListModel::removeSensor(int id) {
    auto db = Database::openConnection();
    SensorDao dao(db);
    bool ok = dao.remove(id);
    db.close();
    if (ok) loadFromDb();
    return ok;
}
