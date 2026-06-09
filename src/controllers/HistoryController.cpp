#include "HistoryController.h"
#include "../core/Database.h"
#include "../core/dao/SensorDataDao.h"

// ── HistoryTableModel ──────────────────────────────────────────────────────

HistoryTableModel::HistoryTableModel(QObject *parent) : QAbstractTableModel(parent) {}

int HistoryTableModel::rowCount(const QModelIndex &) const { return m_rows.size(); }

QHash<int, QByteArray> HistoryTableModel::roleNames() const {
    return {
        {Qt::UserRole + ColTime,   "recordedAt"},
        {Qt::UserRole + ColValue,  "value"},
        {Qt::UserRole + ColRaw,    "rawValue"},
        {Qt::UserRole + ColStatus, "status"},
        {Qt::UserRole + ColAlarm,  "isAlarm"},
    };
}

QVariant HistoryTableModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_rows.size()) return {};
    const auto &r = m_rows[index.row()];
    int col = (role >= Qt::UserRole) ? (role - Qt::UserRole) : index.column();
    switch (col) {
    case ColTime:   return r.value("recorded_at");
    case ColValue:  return r.value("value");
    case ColRaw:    return r.value("raw_value");
    case ColStatus: return r.value("status");
    case ColAlarm:  return r.value("is_alarm");
    default:        return {};
    }
}

QVariant HistoryTableModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (role != Qt::DisplayRole || orientation != Qt::Horizontal) return {};
    switch (section) {
    case ColTime:   return "Time";
    case ColValue:  return "Value";
    case ColRaw:    return "Raw";
    case ColStatus: return "Status";
    case ColAlarm:  return "Alarm";
    default:        return {};
    }
}

void HistoryTableModel::setRows(const QList<QVariantMap> &rows) {
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}

// ── HistoryController ──────────────────────────────────────────────────────

HistoryController::HistoryController(QObject *parent)
    : QObject(parent), m_model(new HistoryTableModel(this)) {}

void HistoryController::query(int sensorId, const QDateTime &from, const QDateTime &to, int limit) {
    m_loading = true;
    emit loadingChanged();

    auto db = Database::openConnection();
    SensorDataDao dao(db);
    auto records = dao.query(sensorId, from, to, limit);
    db.close();

    QList<QVariantMap> rows;
    for (const auto &d : records) {
        rows.append({
            {"recorded_at", d.recordedAt.toString(Qt::ISODate)},
            {"value",       d.value.has_value() ? QVariant(*d.value) : QVariant()},
            {"raw_value",   d.rawValue.has_value() ? QVariant(*d.rawValue) : QVariant()},
            {"status",      d.status},
            {"is_alarm",    d.isAlarm},
        });
    }
    m_model->setRows(rows);

    m_loading = false;
    emit loadingChanged();
}

void HistoryController::clear() {
    m_model->setRows({});
}
