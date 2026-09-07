#include "SensorListModel.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/AppConfigDao.h"
#include "data/models/AnalogDigitalLink.h"
#include "tt10/SensorSymbols.h"
#include <cmath>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QVariant>
#include <QQmlEngine>
#include <QJSEngine>

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
        {SensorSymbolRole,     "sensorSymbol"},
        {DisplayNameRole,      "displayName"},
        {TransmitEnabledRole,  "transmitEnabled"},
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
    case SensorSymbolRole:    return s.sensorSymbol;
    case DisplayNameRole:     return SensorSymbols::displayLabel(s.sensorSymbol, s.name);
    case TransmitEnabledRole: return s.transmitEnabled;
    default:                  return {};
    }
}

QVariantMap SensorListModel::sensorToVariant(const Sensor &s) const {
    QVariantMap m;
    m["sensorId"]        = s.id;
    m["name"]            = s.name;
    m["sensorSymbol"]    = s.sensorSymbol;
    m["displayName"]     = SensorSymbols::displayLabel(s.sensorSymbol, s.name);
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
    m["transmitEnabled"] = s.transmitEnabled;
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
            {"sensor_symbol", s.sensorSymbol},
            {"display_name", SensorSymbols::displayLabel(s.sensorSymbol, s.name)},
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
    s.sensorSymbol   = p.value("sensorSymbol").toString();
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
    if (p.contains(QStringLiteral("transmitEnabled")))
        s.transmitEnabled = p.value("transmitEnabled").toBool();
    return s;
}

bool SensorListModel::commitSensorWrite(const QString &okMsg, const QString &failMsg,
                                           const std::function<bool(SensorDao &, AppConfigDao &)> &op)
{
    bool ok;
    {
        ScopedDbConnection db;
        SensorDao dao(db);
        AppConfigDao cfgDao(db);
        ok = op(dao, cfgDao);
        if (ok)
            cfgDao.bumpRevision();
    }
    if (ok) {
        loadFromDb();
        emit messageSent(QStringLiteral("Success"), okMsg);
    } else {
        emit messageSent(QStringLiteral("Error"), failMsg);
    }
    return ok;
}

bool SensorListModel::addSensor(const QVariantMap &props) {
    Sensor s = variantToSensor(props);
    return commitSensorWrite(QStringLiteral("Sensor added."),
                             QStringLiteral("Failed to add sensor."),
                             [&](SensorDao &dao, AppConfigDao &cfgDao) {
        if (s.sensorType == SensorType::Analog) {
            const AppConfig cfg = cfgDao.load();
            if (cfg.autoAddTransmit)
                s.transmitEnabled = true;
        }
        return dao.save(s);
    });
}

bool SensorListModel::updateSensor(int id, const QVariantMap &props) {
    Sensor s = variantToSensor(props, id);
    return commitSensorWrite(QStringLiteral("Sensor updated."),
                             QStringLiteral("Failed to update sensor."),
                             [&](SensorDao &dao, AppConfigDao &) {
        const Sensor existing = dao.loadById(id);
        if (existing.id != 0 && !props.contains(QStringLiteral("transmitEnabled")))
            s.transmitEnabled = existing.transmitEnabled;
        return dao.save(s);
    });
}

bool SensorListModel::removeSensor(int id) {
    return commitSensorWrite(QStringLiteral("Sensor deleted."),
                             QStringLiteral("Failed to delete sensor."),
                             [&](SensorDao &dao, AppConfigDao &) {
        return dao.remove(id);
    });
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

QVariantList SensorListModel::transmissionRows() const
{
    QVariantList out;
    int idx = 1;
    for (const auto &s : m_sensors) {
        if (!s.active || s.sensorType != SensorType::Analog)
            continue;
        out.append(QVariantMap{
            {QStringLiteral("stt"), idx++},
            {QStringLiteral("sensorId"), s.id},
            {QStringLiteral("name"), s.name},
            {QStringLiteral("sensorSymbol"), s.sensorSymbol},
            {QStringLiteral("transmitEnabled"), s.transmitEnabled},
        });
    }
    return out;
}

bool SensorListModel::applyTransmission(const QVariantList &rows)
{
    return commitSensorWrite(QStringLiteral("Transmission settings saved."),
                             QStringLiteral("Failed to save transmission settings."),
                             [&](SensorDao &dao, AppConfigDao &) {
        for (const auto &item : rows) {
            const QVariantMap row = item.toMap();
            const int id = row.value(QStringLiteral("sensorId")).toInt();
            if (id <= 0)
                continue;
            if (!dao.updateTransmission(id,
                                        row.value(QStringLiteral("sensorSymbol")).toString(),
                                        row.value(QStringLiteral("transmitEnabled")).toBool()))
                return false;
        }
        return true;
    });
}

QString SensorListModel::validateSensorProps(const QVariantMap &props)
{
    if (props.value(QStringLiteral("name")).toString().trimmed().isEmpty())
        return QStringLiteral("Sensor name is required.");
    const int slave = props.value(QStringLiteral("slaveId"), 0).toInt();
    if (slave < 1 || slave > 247)
        return QStringLiteral("Slave ID must be between 1 and 247.");
    const int addr = props.value(QStringLiteral("registerAddress"), -1).toInt();
    if (addr < 0 || addr > 65535)
        return QStringLiteral("Register address must be between 0 and 65535.");
    const int poll = props.value(QStringLiteral("pollInterval"), 0).toInt();
    if (poll < 1)
        return QStringLiteral("Poll interval must be at least 1 second.");
    return {};
}

bool SensorListModel::saveSensorForm(const QVariantMap &form, bool isAddMode, int editSensorId)
{
    const QString fieldError = validateSensorProps(form);
    if (!fieldError.isEmpty()) {
        emit messageSent(QStringLiteral("Validation error"), fieldError);
        return false;
    }
    const int mode = form.value(QStringLiteral("scalingModeIndex"), 0).toInt();
    QString coeffError;
    const QString coeff = buildCoefficientJson(
        mode, form.value(QStringLiteral("coeffJson")).toString(),
        mode == 1 ? form.value(QStringLiteral("linearA")).toString()
                  : form.value(QStringLiteral("rawMin")).toString(),
        mode == 1 ? form.value(QStringLiteral("linearB")).toString()
                  : form.value(QStringLiteral("rawMax")).toString(),
        form.value(QStringLiteral("scaleMin")).toString(),
        form.value(QStringLiteral("scaleMax")).toString(),
        &coeffError);
    if (coeff.isEmpty()) {
        emit messageSent(QStringLiteral("Validation error"),
                         coeffError.isEmpty() ? QStringLiteral("Invalid coefficient.")
                                              : coeffError);
        return false;
    }
    QVariantMap props = form;
    props[QStringLiteral("coefficient")] = coeff;
    if (isAddMode)
        return addSensor(props);
    return updateSensor(editSensorId, props);
}

QVariantMap SensorListModel::coefficientUiState(const QString &coeffJson) {
    QVariantMap blank {
        {"mode", 0}, {"linearA", "1"}, {"linearB", "0"},
        {"rawMin", "4000"}, {"rawMax", "20000"},
        {"scaleMin", "4"}, {"scaleMax", "20"}, {"legacyJson", "{}"}
    };

    QString raw = coeffJson.trimmed().isEmpty() ? "{}" : coeffJson.trimmed();
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        blank["mode"] = 3; blank["legacyJson"] = raw; return blank;
    }
    QJsonObject obj = doc.object();
    if (obj.isEmpty()) return blank;
    if (obj.contains("coeffs")) { blank["mode"] = 3; blank["legacyJson"] = raw; return blank; }
    if (obj.contains("a")) {
        double a = obj["a"].toDouble(1.0), b = obj["b"].toDouble(0.0);
        if (!std::isfinite(a) || !std::isfinite(b)) { blank["mode"] = 3; blank["legacyJson"] = raw; return blank; }
        return {{"mode", 1}, {"linearA", QString::number(a)}, {"linearB", QString::number(b)},
                {"rawMin", "4000"}, {"rawMax", "20000"}, {"scaleMin", "4"}, {"scaleMax", "20"}, {"legacyJson", "{}"}};
    }
    blank["mode"] = 3; blank["legacyJson"] = raw; return blank;
}

QString SensorListModel::buildCoefficientJson(int mode, const QString &legacyJson,
                                                   const QString &s0, const QString &s1,
                                                   const QString &s2, const QString &s3,
                                                   QString *error) {
    auto fail = [&](const QString &msg) {
        if (error)
            *error = msg;
        return QString();
    };
    auto parseDouble = [&](const QString &label, const QString &s) -> std::pair<double, QString> {
        QString t = s.trimmed().replace(',', '.');
        if (t.isEmpty()) return {0, label + " is required."};
        bool ok; double v = t.toDouble(&ok);
        if (!ok || !std::isfinite(v)) return {0, label + ": invalid number."};
        return {v, {}};
    };

    if (mode == 0) return "{}";
    if (mode == 1) {
        auto [a, ea] = parseDouble("Gain (a)", s0);
        auto [b, eb] = parseDouble("Offset (b)", s1);
        if (!ea.isEmpty()) return fail(ea);
        if (!eb.isEmpty()) return fail(eb);
        return QStringLiteral("{\"a\":%1,\"b\":%2}").arg(a).arg(b);
    }
    if (mode == 2) {
        auto [r0, e0] = parseDouble("Raw Min", s0);
        auto [r1, e1] = parseDouble("Raw Max", s1);
        auto [y0, e2] = parseDouble("Scale Min", s2);
        auto [y1, e3] = parseDouble("Scale Max", s3);
        for (const auto &e : {e0, e1, e2, e3})
            if (!e.isEmpty()) return fail(e);
        double denom = r1 - r0;
        if (denom == 0) return fail("Raw Max must differ from Raw Min.");
        double a = (y1 - y0) / denom, b = y0 - a * r0;
        return QStringLiteral("{\"a\":%1,\"b\":%2}").arg(a).arg(b);
    }
    if (mode == 3) {
        QString t = legacyJson.trimmed().isEmpty() ? "{}" : legacyJson.trimmed();
        QJsonParseError err;
        QJsonDocument::fromJson(t.toUtf8(), &err);
        if (err.error != QJsonParseError::NoError) return fail("Invalid JSON: " + err.errorString());
        return t;
    }
    return fail("Unknown scaling mode.");
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
