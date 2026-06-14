#include "core/history/HistoryTableModel.h"

HistoryTableModel::HistoryTableModel(QObject *parent) : QAbstractTableModel(parent) {}

int HistoryTableModel::rowCount(const QModelIndex &) const { return m_rows.size(); }

QHash<int, QByteArray> HistoryTableModel::roleNames() const {
    const int base = static_cast<int>(Qt::UserRole);
    return {
        {Qt::DisplayRole,                         "display"},
        {base + static_cast<int>(ColTime),       "recordedAt"},
        {base + static_cast<int>(ColSensorName), "sensorName"},
        {base + static_cast<int>(ColUnit),       "unit"},
        {base + static_cast<int>(ColValue),      "value"},
        {base + static_cast<int>(ColRaw),        "rawValue"},
    };
}

QVariant HistoryTableModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_rows.size()) return {};
    const auto &r = m_rows[index.row()];
    if (role == Qt::DisplayRole)
        role = static_cast<int>(Qt::UserRole) + index.column();
    int col = (role >= Qt::UserRole) ? (role - Qt::UserRole) : index.column();
    switch (col) {
    case ColTime:       return r.recordedAt.toLocalTime()
                                .toString(QStringLiteral("dd/MM/yyyy HH:mm:ss"));
    case ColSensorName: return r.sensorName;
    case ColUnit:       return r.unit;
    case ColValue:      return r.valueText;
    case ColRaw:        return r.rawValueText;
    default:            return {};
    }
}

QVariant HistoryTableModel::headerData(int section, Qt::Orientation orientation, int role) const {
    if (role != Qt::DisplayRole || orientation != Qt::Horizontal) return {};
    switch (section) {
    case ColTime:       return "Time";
    case ColSensorName: return "Sensor";
    case ColUnit:       return "Unit";
    case ColValue:      return "Value";
    case ColRaw:        return "Raw value";
    default:            return {};
    }
}

void HistoryTableModel::setRows(const QList<HistoryRow> &rows) {
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}
