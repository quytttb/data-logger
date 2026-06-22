#pragma once
#include <QAbstractTableModel>
#include <QList>
#include <QtQmlIntegration/qqmlintegration.h>
#include "core/history/HistoryRow.h"

class HistoryTableModel : public QAbstractTableModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use HistoryViewModel.tableModel")
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int rowsSize READ rowCount NOTIFY countChanged)

public:
    enum Col { ColTime=0, ColSensorName, ColUnit, ColValue, ColRaw, ColCount };
    explicit HistoryTableModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &p = {}) const override;
    int columnCount(const QModelIndex &p = {}) const override { Q_UNUSED(p) return ColCount; }
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setRows(const QList<HistoryRow> &rows);
    const QList<HistoryRow> &rows() const { return m_rows; }

signals:
    void countChanged();

private:
    QList<HistoryRow> m_rows;
};
