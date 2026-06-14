#include "SensorListModel.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/models/AnalogDigitalLink.h"
#include <QVariant>
#include <QQmlEngine>
#include <QJSEngine>
#include <QSet>

static SensorListModel *g_sensorListInstance = nullptr;

SensorListModel *SensorListModel::instance() { return g_sensorListInstance; }

void SensorListModel::setInstance(SensorListModel *model)
{
    g_sensorListInstance = model;
}

SensorListModel *SensorListModel::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(g_sensorListInstance);
    QQmlEngine::setObjectOwnership(g_sensorListInstance, QQmlEngine::CppOwnership);
    return g_sensorListInstance;
}

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
    if (ok) {
        loadFromDb();
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Sensor deleted."));
    } else {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to delete sensor."));
    }
    return ok;
}

const Sensor *SensorListModel::findSensorById(int id) const
{
    for (const auto &s : m_sensors) {
        if (s.id == id)
            return &s;
    }
    return nullptr;
}

static QVariantMap sensorBrief(const Sensor &s)
{
    return {
        {QStringLiteral("id"),       s.id},
        {QStringLiteral("name"),     s.name},
        {QStringLiteral("slaveId"),  s.slaveId},
        {QStringLiteral("address"),  s.registerAddress},
    };
}

bool SensorListModel::add_sensor(const QString &name, const QString &unit, int slaveId,
                                 int registerAddress, const QString &registerType,
                                 const QString &dataType, const QString &dataFormat,
                                 const QString &coefficient, int pollInterval, int reportIndex,
                                 bool active, const QVariant &minThreshold,
                                 const QVariant &maxThreshold, const QString &sensorType)
{
    QVariantMap props{
        {QStringLiteral("name"),            name},
        {QStringLiteral("unit"),            unit},
        {QStringLiteral("slaveId"),         slaveId},
        {QStringLiteral("registerAddress"), registerAddress},
        {QStringLiteral("registerType"),    registerType},
        {QStringLiteral("dataType"),        dataType},
        {QStringLiteral("dataFormat"),      dataFormat},
        {QStringLiteral("coefficient"),     coefficient},
        {QStringLiteral("pollInterval"),    pollInterval},
        {QStringLiteral("reportIndex"),     reportIndex},
        {QStringLiteral("active"),          active},
        {QStringLiteral("sensorType"),      sensorType},
    };
    if (!minThreshold.isNull()) props[QStringLiteral("minThreshold")] = minThreshold;
    if (!maxThreshold.isNull()) props[QStringLiteral("maxThreshold")] = maxThreshold;
    const bool ok = addSensor(props);
    if (ok)
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Sensor added."));
    else
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to add sensor."));
    return ok;
}

bool SensorListModel::update_sensor(int id, const QString &name, const QString &unit,
                                    int slaveId, int registerAddress,
                                    const QString &registerType, const QString &dataType,
                                    const QString &dataFormat, const QString &coefficient,
                                    int pollInterval, int reportIndex, bool active,
                                    const QVariant &minThreshold, const QVariant &maxThreshold,
                                    const QString &sensorType)
{
    QVariantMap props{
        {QStringLiteral("name"),            name},
        {QStringLiteral("unit"),            unit},
        {QStringLiteral("slaveId"),         slaveId},
        {QStringLiteral("registerAddress"), registerAddress},
        {QStringLiteral("registerType"),    registerType},
        {QStringLiteral("dataType"),        dataType},
        {QStringLiteral("dataFormat"),      dataFormat},
        {QStringLiteral("coefficient"),     coefficient},
        {QStringLiteral("pollInterval"),    pollInterval},
        {QStringLiteral("reportIndex"),     reportIndex},
        {QStringLiteral("active"),          active},
        {QStringLiteral("sensorType"),      sensorType},
    };
    if (!minThreshold.isNull()) props[QStringLiteral("minThreshold")] = minThreshold;
    if (!maxThreshold.isNull()) props[QStringLiteral("maxThreshold")] = maxThreshold;
    const bool ok = updateSensor(id, props);
    if (ok)
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Sensor updated."));
    else
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to update sensor."));
    return ok;
}

QVariantList SensorListModel::get_analog_links(int analogSensorId) const
{
    auto db = Database::openConnection();
    SensorDao dao(db);
    const auto links = dao.linksForAnalog(analogSensorId);
    db.close();

    QVariantList out;
    for (const auto &l : links) {
        const Sensor *digital = findSensorById(l.digitalSensorId);
        if (!digital)
            continue;
        const bool isDi = digital->sensorType == SensorType::DI;
        out.append(QVariantMap{
            {QStringLiteral("id"),            l.id},
            {QStringLiteral("ioType"),        isDi ? QStringLiteral("DI") : QStringLiteral("DO")},
            {QStringLiteral("label"),         digital->name},
            {QStringLiteral("slaveId"),       digital->slaveId},
            {QStringLiteral("address"),       digital->registerAddress},
            {QStringLiteral("diType"),        l.diType},
            {QStringLiteral("triggerOnMax"),  l.triggerOnMax},
            {QStringLiteral("triggerOnMin"),  l.triggerOnMin},
        });
    }
    return out;
}

QVariantList SensorListModel::list_di_sensors() const
{
    QVariantList out;
    for (const auto &s : m_sensors) {
        if (s.sensorType == SensorType::DI)
            out.append(sensorBrief(s));
    }
    return out;
}

QVariantList SensorListModel::list_do_sensors(int analogSensorId) const
{
    auto db = Database::openConnection();
    SensorDao dao(db);
    const auto links = dao.loadAllLinks();
    db.close();

    QSet<int> linkedElsewhere;
    for (const auto &l : links) {
        if (l.analogSensorId != analogSensorId)
            linkedElsewhere.insert(l.digitalSensorId);
    }

    QVariantList out;
    for (const auto &s : m_sensors) {
        if (s.sensorType == SensorType::DO && !linkedElsewhere.contains(s.id))
            out.append(sensorBrief(s));
    }
    return out;
}

bool SensorListModel::attach_di(int analogSensorId, int diSensorId, const QString &diType)
{
    AnalogDigitalLink link;
    link.analogSensorId  = analogSensorId;
    link.digitalSensorId = diSensorId;
    link.diType          = diType;
    link.triggerOnMax    = false;
    link.triggerOnMin    = false;

    auto db = Database::openConnection();
    SensorDao dao(db);
    const bool ok = dao.saveLink(link);
    db.close();
    if (ok)
        emit messageSent(QStringLiteral("Success"), QStringLiteral("DI link attached."));
    else
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to attach DI."));
    return ok;
}

bool SensorListModel::attach_do(int analogSensorId, int doSensorId, bool trigMax, bool trigMin)
{
    AnalogDigitalLink link;
    link.analogSensorId  = analogSensorId;
    link.digitalSensorId = doSensorId;
    link.triggerOnMax    = trigMax;
    link.triggerOnMin    = trigMin;

    auto db = Database::openConnection();
    SensorDao dao(db);
    const bool ok = dao.saveLink(link);
    db.close();
    if (ok)
        emit messageSent(QStringLiteral("Success"), QStringLiteral("DO link attached."));
    else
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to attach DO."));
    return ok;
}

bool SensorListModel::detach_link(int linkId)
{
    auto db = Database::openConnection();
    SensorDao dao(db);
    const bool ok = dao.removeLink(linkId);
    db.close();
    if (ok)
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Link removed."));
    else
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to remove link."));
    return ok;
}

bool SensorListModel::update_link_di_type(int linkId, const QString &diType)
{
    auto db = Database::openConnection();
    SensorDao dao(db);
    bool ok = false;
    for (auto &l : dao.loadAllLinks()) {
        if (l.id == linkId) {
            l.diType = diType;
            ok = dao.saveLink(l);
            break;
        }
    }
    db.close();
    return ok;
}

bool SensorListModel::update_link_do_triggers(int linkId, bool trigMax, bool trigMin)
{
    auto db = Database::openConnection();
    SensorDao dao(db);
    bool ok = false;
    for (auto &l : dao.loadAllLinks()) {
        if (l.id == linkId) {
            l.triggerOnMax = trigMax;
            l.triggerOnMin = trigMin;
            ok = dao.saveLink(l);
            break;
        }
    }
    db.close();
    return ok;
}
