#pragma once
#include <QObject>
#include <QDateTime>
#include <QVariantList>
#include <QVariantMap>
#include <QFutureWatcher>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"

// Kết quả query trending lịch sử (chạy trên worker thread).
struct HistoryTrendResult {
    QVariantMap seriesPoints; // key: sensorId (string) → QVariantList of {x, y}
    double xMin = 0;
    double xMax = 0;
    double yMin = 0;
    double yMax = 1;
    QString error;
    int generation = 0;
};

// Query sensor_data theo khoảng thời gian cho trending graph lịch sử.
// Chạy trên QtConcurrent (không block UI), downsample min-max về ~800
// điểm/sensor rồi phát về QML qua seriesPoints + trục history*.
// Realtime (5 phút) vẫn do MonitorController giữ — class này chỉ lo history.
class TrendingHistoryViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasHistory READ hasHistory NOTIFY historyChanged)
    Q_PROPERTY(QVariantMap seriesPoints READ seriesPoints NOTIFY historyChanged)
    Q_PROPERTY(double historyXMin READ historyXMin NOTIFY historyChanged)
    Q_PROPERTY(double historyXMax READ historyXMax NOTIFY historyChanged)
    Q_PROPERTY(double historyYMin READ historyYMin NOTIFY historyChanged)
    Q_PROPERTY(double historyYMax READ historyYMax NOTIFY historyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit TrendingHistoryViewModel(QObject *parent = nullptr);
    ~TrendingHistoryViewModel() override;

    DECLARE_QML_SINGLETON(TrendingHistoryViewModel)

    bool loading() const { return m_loading; }
    bool hasHistory() const { return m_hasHistory; }
    QVariantMap seriesPoints() const { return m_seriesPoints; }
    double historyXMin() const { return m_xMin; }
    double historyXMax() const { return m_xMax; }
    double historyYMin() const { return m_yMin; }
    double historyYMax() const { return m_yMax; }
    QString lastError() const { return m_lastError; }

public slots:
    // sensorIds: QVariantList int (>0 và tồn tại). from/to: QDateTime hợp lệ.
    Q_INVOKABLE void query(const QVariantList &sensorIds,
                           const QDateTime &from, const QDateTime &to);
    // Xóa history, trả TrendingView về realtime.
    Q_INVOKABLE void clear();

signals:
    void loadingChanged();
    void historyChanged();
    void lastErrorChanged();
    void messageSent(QString title, QString body);

private slots:
    void onQueryFinished();

private:
    void setLoading(bool v);
    void setError(const QString &msg);

    QFutureWatcher<HistoryTrendResult> *m_watcher = nullptr;
    bool m_loading = false;
    bool m_hasHistory = false;
    QVariantMap m_seriesPoints;
    double m_xMin = 0;
    double m_xMax = 0;
    double m_yMin = 0;
    double m_yMax = 1;
    QString m_lastError;
    int m_gen = 0;
};
