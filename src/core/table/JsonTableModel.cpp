#include "core/table/JsonTableModel.h"

#include <algorithm>

namespace {

QVariant cellAt(const QVariantList &row, int column)
{
    return (column >= 0 && column < row.size()) ? row.at(column) : QVariant();
}

QStringList normalizedHeaders(const QVariantList &headers)
{
    QStringList out;
    out.reserve(headers.size());
    for (const auto &h : headers)
        out << h.toString();
    return out;
}

} // namespace

JsonTableModel::JsonTableModel(QObject *parent) : QAbstractTableModel(parent) {}

int JsonTableModel::rowCount(const QModelIndex &) const { return m_rows.size(); }

int JsonTableModel::columnCount(const QModelIndex &) const
{
    // Headers win, but rows may be wider (a table is still readable if the
    // host forgot setHeaders — otherwise its indices would be invalid).
    int cols = m_headers.size();
    for (const auto &row : m_rows)
        cols = std::max(cols, int(row.size()));
    return cols;
}

QVariant JsonTableModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    if (role != Qt::DisplayRole && role != Qt::EditRole && role != Qt::UserRole)
        return {};
    return cellAt(m_rows.at(index.row()), index.column());
}

QVariant JsonTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (role != Qt::DisplayRole || orientation != Qt::Horizontal)
        return {};
    if (section < 0 || section >= m_headers.size())
        return {};
    return m_headers.at(section);
}

QHash<int, QByteArray> JsonTableModel::roleNames() const
{
    return {{Qt::DisplayRole, "display"}};
}

void JsonTableModel::setHeaders(const QVariantList &headers)
{
    if (normalizedHeaders(headers) == m_headers)
        return;
    beginResetModel();
    m_headers = normalizedHeaders(headers);
    endResetModel();
    emit rowsChanged();
}

void JsonTableModel::setRows(const QVariantList &rows)
{
    beginResetModel();
    m_rows.clear();
    m_rows.reserve(rows.size());
    for (const auto &r : rows)
        m_rows.append(r.toList());
    endResetModel();
    emit rowsChanged();
}

void JsonTableModel::appendRow(const QVariantList &row)
{
    const int count = m_rows.size();
    beginInsertRows({}, count, count);
    m_rows.append(row);
    endInsertRows();
    emit rowsChanged();
}

void JsonTableModel::setCell(int row, int column, const QVariant &value)
{
    if (row < 0 || row >= m_rows.size() || column < 0)
        return;
    QVariantList &r = m_rows[row];
    while (r.size() <= column)
        r.append(QVariant());
    if (r.at(column) == value)
        return;
    r[column] = value;
    emit dataChanged(index(row, column), index(row, column), {Qt::DisplayRole});
}

void JsonTableModel::clear()
{
    if (m_rows.isEmpty())
        return;
    beginResetModel();
    m_rows.clear();
    endResetModel();
    emit rowsChanged();
}

QVariant JsonTableModel::cell(int row, int column) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    return cellAt(m_rows.at(row), column);
}

int JsonTableModel::findRow(int column, const QVariant &value) const
{
    for (int i = 0; i < m_rows.size(); ++i) {
        if (cellAt(m_rows.at(i), column) == value)
            return i;
    }
    return -1;
}