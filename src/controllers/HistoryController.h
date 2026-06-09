#pragma once
#include <QObject>
#include <QAbstractTableModel>
#include <QList>
#include <QDateTime>
#include <QVariantMap>

// Table model for HistoryView — wraps a QList<QVariantMap> of sensor_data rows.
class HistoryTableModel : public QAbstractTableModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Col { ColTime=0, ColValue, ColRaw, ColStatus, ColAlarm, ColCount };
    explicit HistoryTableModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &p = {}) const override;
    int columnCount(const QModelIndex &p = {}) const override { Q_UNUSED(p) return ColCount; }
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setRows(const QList<QVariantMap> &rows);
signals:
    void countChanged();
private:
    QList<QVariantMap> m_rows;
};

// Controller — queries sensor_data and exposes HistoryTableModel to QML.
class HistoryController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* tableModel READ tableModel CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    explicit HistoryController(QObject *parent = nullptr);
    QObject *tableModel() { return m_model; }
    bool loading() const  { return m_loading; }

public slots:
    Q_INVOKABLE void query(int sensorId,
                           const QDateTime &from,
                           const QDateTime &to,
                           int limit = 2000);
    Q_INVOKABLE void clear();

signals:
    void loadingChanged();
    void messageSent(QString title, QString body);

private:
    HistoryTableModel *m_model;
    bool               m_loading = false;
};
