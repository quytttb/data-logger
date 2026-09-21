#pragma once
#include <QAbstractTableModel>
#include <QStringList>
#include <QVector>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

// Generic display-oriented table model backed by QVariant rows. Bridges
// list-shaped data (SensorListModel, ListModel, ...) into AppTableView, which
// requires a multi-column QAbstractTableModel with headerData.
//
// QML usage:
//   JsonTableModel {
//       id: table
//       Component.onCompleted: { setHeaders(["A", "B"]); setRows([["1","x"],["2","y"]]) }
//   }
// Mutating API (appendRow/setCell/clear) emits proper model signals so
// TableView stays stable (no full reset per update).
class JsonTableModel : public QAbstractTableModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY rowsChanged)
    Q_PROPERTY(int colCount READ columnCount NOTIFY rowsChanged)

public:
    explicit JsonTableModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    int columnCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation,
                        int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Bulk replace of the whole table (reset semantics).
    Q_INVOKABLE void setHeaders(const QVariantList &headers);
    Q_INVOKABLE void setRows(const QVariantList &rows);
    // Incremental updates — no full reset, TableView scroll/hover stay put.
    Q_INVOKABLE void appendRow(const QVariantList &row);
    Q_INVOKABLE void setCell(int row, int column, const QVariant &value);
    Q_INVOKABLE void clear();
    // Read access for QML (e.g. building save payloads from view state).
    Q_INVOKABLE QVariant cell(int row, int column) const;
    Q_INVOKABLE int findRow(int column, const QVariant &value) const;

signals:
    void rowsChanged();

private:
    QVector<QVariantList> m_rows;
    QStringList m_headers;
};