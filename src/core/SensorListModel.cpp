#include "SensorListModel.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/AppConfigDao.h"
#include "data/models/AnalogDigitalLink.h"
#include <QVariant>
#include <QQmlEngine>
#include <QJSEngine>
#include <QSet>

namespace {

constexpr int kDefaultPollIntervalSec = 3;  // sensor poll interval default (seconds)
constexpr int kDefaultReportIndex     = 0;  // "no report" sentinel

bool thresholdVariantEnabled(const QVariant &v)
{
    return !v.isNull() && !v.toString().trimmed().isEmpty();
}

} // namespace

IMPLEMENT_QML_SINGLETON(SensorListModel)

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
        {DecimalsRole,         "decimals"},
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
    case DecimalsRole:        return s.decimals;
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
    m["decimals"]        = s.decimals;
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

QList<QVariantMap> SensorListModel::activeMonitorMaps() const {
    QList<QVariantMap> maps;
    for (const auto &s : m_sensors) {
        if (!s.active) continue;
        maps.append({
            {"id",          s.id},
            {"name",        s.name},
            {"unit",        s.unit},
            {"decimals",    s.decimals},
            {"sensor_type", sensorTypeToString(s.sensorType)},
        });
    }
    return maps;
}

void SensorListModel::loadFromDb() {
    beginResetModel();
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        m_sensors = dao.loadAll();
    }
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
    if (thresholdVariantEnabled(minV)) s.minThreshold = minV.toDouble();
    auto maxV = p.value("maxThreshold");
    if (thresholdVariantEnabled(maxV)) s.maxThreshold = maxV.toDouble();
    s.pollInterval   = p.value("pollInterval", kDefaultPollIntervalSec).toInt();
    s.reportIndex    = p.value("reportIndex", kDefaultReportIndex).toInt();
    s.decimals       = p.value("decimals", 4).toInt();
    s.sensorType     = sensorTypeFromString(p.value("sensorType", "ANALOG").toString());
    s.active         = p.value("active", true).toBool();
    s.diType         = p.value("diType").toString();
    return s;
}

bool SensorListModel::addSensor(const QVariantMap &props) {
    Sensor s = variantToSensor(props);
    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        ok = dao.save(s);
        if (ok) AppConfigDao(db).bumpRevision();
    }
    if (ok) {
        loadFromDb();
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Sensor added."));
    } else {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to add sensor."));
    }
    return ok;
}

bool SensorListModel::updateSensor(int id, const QVariantMap &props) {
    Sensor s = variantToSensor(props, id);
    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        ok = dao.save(s);
        if (ok) AppConfigDao(db).bumpRevision();
    }
    if (ok) {
        loadFromDb();
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Sensor updated."));
    } else {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to update sensor."));
    }
    return ok;
}

bool SensorListModel::removeSensor(int id) {
    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        ok = dao.remove(id);
        if (ok) AppConfigDao(db).bumpRevision();
    }
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

QVariantList SensorListModel::get_analog_links(int analogSensorId) const
{
    QList<AnalogDigitalLink> links;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        links = dao.linksForAnalog(analogSensorId);
    }

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
    QList<AnalogDigitalLink> links;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        links = dao.loadAllLinks();
    }

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

    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        ok = dao.saveLink(link);
    }
    if (ok) {
        emit messageSent(QStringLiteral("Success"), QStringLiteral("DI link attached."));
        emit linksChanged();
    } else {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to attach DI."));
    }
    return ok;
}

bool SensorListModel::attach_do(int analogSensorId, int doSensorId, bool trigMax, bool trigMin)
{
    AnalogDigitalLink link;
    link.analogSensorId  = analogSensorId;
    link.digitalSensorId = doSensorId;
    link.triggerOnMax    = trigMax;
    link.triggerOnMin    = trigMin;

    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        ok = dao.saveLink(link);
    }
    if (ok) {
        emit messageSent(QStringLiteral("Success"), QStringLiteral("DO link attached."));
        emit linksChanged();
    } else {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to attach DO."));
    }
    return ok;
}

bool SensorListModel::detach_link(int linkId)
{
    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        ok = dao.removeLink(linkId);
    }
    if (ok) {
        emit messageSent(QStringLiteral("Success"), QStringLiteral("Link removed."));
        emit linksChanged();
    } else {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Failed to remove link."));
    }
    return ok;
}

bool SensorListModel::update_link_di_type(int linkId, const QString &diType)
{
    bool ok = false;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        for (auto &l : dao.loadAllLinks()) {
            if (l.id == linkId) {
                l.diType = diType;
                ok = dao.saveLink(l);
                break;
            }
        }
    }
    if (ok) emit linksChanged();
    return ok;
}

bool SensorListModel::update_link_do_triggers(int linkId, bool trigMax, bool trigMin)
{
    bool ok = false;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        for (auto &l : dao.loadAllLinks()) {
            if (l.id == linkId) {
                l.triggerOnMax = trigMax;
                l.triggerOnMin = trigMin;
                ok = dao.saveLink(l);
                break;
            }
        }
    }
    if (ok) emit linksChanged();
    return ok;
}
