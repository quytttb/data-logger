#pragma once
#include <QObject>
#include <QDateTime>
#include <QStringList>
#include <QVariantList>
#include <QUrl>
#include <QFutureWatcher>
#include <QTimer>
#include <QtQmlIntegration/qqmlintegration.h>
#include "core/history/HistoryTableModel.h"
#include "utils/qml/QmlSingleton.h"

struct HistorySearchResult {
    QList<HistoryRow> rows;
    QString error;
    int generation = 0;
};

class HistoryViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(HistoryTableModel* tableModel READ tableModel CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool isLoading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool filtersLoading READ filtersLoading NOTIFY filtersLoadingChanged)
    Q_PROPERTY(int recordCount READ recordCount NOTIFY recordCountChanged)
    Q_PROPERTY(bool searchedOnce READ searchedOnce NOTIFY searchedOnceChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QStringList sensorNames READ sensorNames NOTIFY sensorFiltersChanged)
    Q_PROPERTY(QVariantList sensorIds READ sensorIds NOTIFY sensorFiltersChanged)

public:
    explicit HistoryViewModel(QObject *parent = nullptr);
    ~HistoryViewModel() override;

    DECLARE_QML_SINGLETON(HistoryViewModel)

    HistoryTableModel *tableModel() { return &m_model; }
    bool loading() const { return m_loading; }
    bool filtersLoading() const { return m_filtersLoading; }
    int recordCount() const { return m_model.rowCount(); }
    bool searchedOnce() const { return m_searchedOnce; }
    QString lastError() const { return m_lastError; }
    QStringList sensorNames() const { return m_sensorNames; }
    QVariantList sensorIds() const { return m_sensorIds; }

public slots:
    Q_INVOKABLE void search(const QString &fromDate, const QString &toDate, int sensorId);
    Q_INVOKABLE void load_sensors() { reloadFilters(); }
    // Load sensor filter list from DB asynchronously (worker thread). The
    // caller that already holds a fresh in-memory map (main.cpp after
    // SensorListModel::modelReset) should use reloadFiltersFromMaps() instead —
    // it skips the DB round-trip entirely.
    Q_INVOKABLE void reloadFilters();
    // No-DB overload: build sensor filter list from pre-loaded maps (avoids a
    // redundant DB round-trip when called from main.cpp after SensorListModel changes).
    void reloadFiltersFromMaps(const QList<QVariantMap> &maps);
    Q_INVOKABLE void clear();

signals:
    void loadingChanged();
    void filtersLoadingChanged();
    void recordCountChanged();
    void searchedOnceChanged();
    void lastErrorChanged();
    void sensorFiltersChanged();
    void messageSent(QString title, QString body);

private slots:
    void onSearchFinished();
    void onFiltersFinished();

private:
    // Đổ 1 batch rows vào model rồi hẹn batch tiếp qua event loop — mỗi batch
    // chỉ vài ms, UI kịp repaint + BusyIndicator quay, không khựng như setRows
    // 1 lần 2000 rows. gen để hủy chuỗi cũ khi có search mới/clear.
    void pushChunk(int gen);
    static constexpr int kChunkRows = 500;
    static QDateTime parseDateString(const QString &s, bool endOfDay);
    void setLoading(bool v);
    void setFiltersLoading(bool v);
    void setError(const QString &msg);

    HistoryTableModel m_model;
    QFutureWatcher<HistorySearchResult> *m_watcher = nullptr;
    QFutureWatcher<QList<QVariantMap>> *m_filterWatcher = nullptr;
    bool         m_loading = false;
    bool         m_filtersLoading = false;
    bool         m_searchedOnce = false;
    QString      m_lastError;
    QStringList  m_sensorNames{QStringLiteral("All sensors")};
    QVariantList m_sensorIds{0};
    int          m_searchGen = 0;
    int          m_chunkGen = 0;
    QList<HistoryRow> m_pendingRows;
    bool         m_hasPending = false;
    QString      m_pendingFromDate;
    QString      m_pendingToDate;
    int          m_pendingSensorId = 0;
};
