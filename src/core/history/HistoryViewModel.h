#pragma once
#include <QObject>
#include <QDateTime>
#include <QStringList>
#include <QVariantList>
#include <QUrl>
#include <QFutureWatcher>
#include <QtQmlIntegration/qqmlintegration.h>
#include "core/history/HistoryTableModel.h"

class QJSEngine;
class QQmlEngine;

struct HistorySearchResult {
    QList<HistoryRow> rows;
    QString error;
};

class HistoryViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(HistoryTableModel* tableModel READ tableModel CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool isLoading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int recordCount READ recordCount NOTIFY recordCountChanged)
    Q_PROPERTY(bool searchedOnce READ searchedOnce NOTIFY searchedOnceChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QStringList sensorNames READ sensorNames NOTIFY sensorFiltersChanged)
    Q_PROPERTY(QVariantList sensorIds READ sensorIds NOTIFY sensorFiltersChanged)

public:
    explicit HistoryViewModel(QObject *parent = nullptr);
    ~HistoryViewModel() override;

    static HistoryViewModel *instance();
    static void setInstance(HistoryViewModel *vm);
    static HistoryViewModel *create(QQmlEngine *, QJSEngine *);

    HistoryTableModel *tableModel() { return &m_model; }
    bool loading() const { return m_loading; }
    int recordCount() const { return m_model.rowCount(); }
    bool searchedOnce() const { return m_searchedOnce; }
    QString lastError() const { return m_lastError; }
    QStringList sensorNames() const { return m_sensorNames; }
    QVariantList sensorIds() const { return m_sensorIds; }

public slots:
    Q_INVOKABLE void search(const QString &fromDate, const QString &toDate, int sensorId);
    Q_INVOKABLE void load_sensors() { reloadFilters(); }
    Q_INVOKABLE void reloadFilters();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void exportCsv(const QUrl &fileUrl);

signals:
    void loadingChanged();
    void recordCountChanged();
    void searchedOnceChanged();
    void lastErrorChanged();
    void sensorFiltersChanged();
    void messageSent(QString title, QString body);
    void exportFinished(bool ok, const QString &message);

private slots:
    void onSearchFinished();

private:
    static QDateTime parseDateString(const QString &s, bool endOfDay);
    void setLoading(bool v);
    void setError(const QString &msg);

    HistoryTableModel m_model;
    QFutureWatcher<HistorySearchResult> *m_watcher = nullptr;
    bool         m_loading = false;
    bool         m_searchedOnce = false;
    QString      m_lastError;
    QStringList  m_sensorNames;
    QVariantList m_sensorIds;
};
