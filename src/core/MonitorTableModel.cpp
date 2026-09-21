#include "core/MonitorTableModel.h"

MonitorTableModel::MonitorTableModel(QObject *parent) : QAbstractTableModel(parent) {}

void MonitorTableModel::setSourceModel(QAbstractItemModel *source)
{
    if (m_source == source)
        return;
    if (m_source)
        m_source->disconnect(this);
    m_source = source;
    if (m_source) {
        // Snapshot lại với mọi thay đổi của source (vài dòng nên reset rẻ).
        connect(m_source, &QAbstractItemModel::modelReset, this, &MonitorTableModel::rebuild);
        connect(m_source, &QAbstractItemModel::dataChanged, this, &MonitorTableModel::rebuild);
        connect(m_source, &QAbstractItemModel::rowsInserted, this, &MonitorTableModel::rebuild);
        connect(m_source, &QAbstractItemModel::rowsRemoved, this, &MonitorTableModel::rebuild);
        connect(m_source, &QAbstractItemModel::layoutChanged, this, &MonitorTableModel::rebuild);
    }
    emit sourceModelChanged();
    rebuild();
}

void MonitorTableModel::setShowDigitalIO(bool v)
{
    if (m_showDigitalIO == v)
        return;
    m_showDigitalIO = v;
    emit showDigitalIOChanged();
    rebuild();
}

int MonitorTableModel::rowCount(const QModelIndex &) const { return m_rows.size(); }

QHash<int, QByteArray> MonitorTableModel::roleNames() const
{
    return {
        {Qt::DisplayRole,  "display"},
        {DisplayNameRole,  "displayName"},
        {ValueRole,        "value"},
        {UnitRole,         "unit"},
        {SensorTypeRole,   "sensorType"},
        {IsAlarmRole,      "isAlarm"},
        {AlarmTypeRole,    "alarmType"},
        {DiStatesRole,     "diStates"},
    };
}

QVariant MonitorTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const auto &r = m_rows[index.row()];
    switch (role) {
    case DisplayNameRole: return r.value(QStringLiteral("displayName"));
    case ValueRole:       return r.value(QStringLiteral("value"));
    case UnitRole:        return r.value(QStringLiteral("unit"));
    case SensorTypeRole:  return r.value(QStringLiteral("sensorType"));
    case IsAlarmRole:     return r.value(QStringLiteral("isAlarm"));
    case AlarmTypeRole:   return r.value(QStringLiteral("alarmType"));
    case DiStatesRole:    return r.value(QStringLiteral("diStates"));
    default:              return {};
    }
}

QVariant MonitorTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (role != Qt::DisplayRole || orientation != Qt::Horizontal)
        return {};
    switch (section) {
    case ColSensor: return QStringLiteral("Sensor");
    case ColValue:  return QStringLiteral("Value");
    case ColUnit:   return QStringLiteral("Unit");
    case ColStatus: return QStringLiteral("Status");
    default:        return {};
    }
}

void MonitorTableModel::rebuild()
{
    beginResetModel();
    m_rows.clear();
    if (m_source) {
        // Map role name -> role id 1 lần để không phụ thuộc enum của source.
        const auto names = m_source->roleNames();
        QHash<QByteArray, int> byName;
        for (auto it = names.constBegin(); it != names.constEnd(); ++it)
            byName.insert(it.value(), it.key());
        const int rDisplayName = byName.value("displayName", -1);
        const int rValue       = byName.value("value", -1);
        const int rUnit        = byName.value("unit", -1);
        const int rSensorType  = byName.value("sensorType", -1);
        const int rIsAlarm     = byName.value("isAlarm", -1);
        const int rAlarmType   = byName.value("alarmType", -1);
        const int rDiStates    = byName.value("diStates", -1);
        const int n = m_source->rowCount();
        for (int r = 0; r < n; ++r) {
            const QModelIndex idx = m_source->index(r, 0);
            const QString sensorType = (rSensorType >= 0)
                ? m_source->data(idx, rSensorType).toString() : QString();
            if (!m_showDigitalIO && (sensorType == QStringLiteral("DI")
                                     || sensorType == QStringLiteral("DO")))
                continue;
            QVariantMap row;
            row.insert(QStringLiteral("displayName"),
                       rDisplayName >= 0 ? m_source->data(idx, rDisplayName) : QVariant());
            row.insert(QStringLiteral("value"),
                       rValue >= 0 ? m_source->data(idx, rValue) : QVariant());
            row.insert(QStringLiteral("unit"),
                       rUnit >= 0 ? m_source->data(idx, rUnit) : QVariant());
            row.insert(QStringLiteral("sensorType"), sensorType);
            row.insert(QStringLiteral("isAlarm"),
                       rIsAlarm >= 0 ? m_source->data(idx, rIsAlarm) : false);
            row.insert(QStringLiteral("alarmType"),
                       rAlarmType >= 0 ? m_source->data(idx, rAlarmType) : QVariant());
            row.insert(QStringLiteral("diStates"),
                       rDiStates >= 0 ? m_source->data(idx, rDiStates) : QVariantList());
            m_rows.append(row);
        }
    }
    endResetModel();
    emit countChanged();
}
