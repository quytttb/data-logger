#include "core/history/TrendingHistoryViewModel.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDataDao.h"
#include "utils/chart/Downsampler.h"
#include <QtConcurrent>
#include <QQmlEngine>
#include <QJSEngine>
#include <limits>

IMPLEMENT_QML_SINGLETON(TrendingHistoryViewModel)

TrendingHistoryViewModel::TrendingHistoryViewModel(QObject *parent) : QObject(parent)
{
    m_watcher = new QFutureWatcher<HistoryTrendResult>(this);
    connect(m_watcher, &QFutureWatcher<HistoryTrendResult>::finished,
            this, &TrendingHistoryViewModel::onQueryFinished);
}

TrendingHistoryViewModel::~TrendingHistoryViewModel() = default;

void TrendingHistoryViewModel::setLoading(bool v)
{
    if (m_loading == v) return;
    m_loading = v;
    emit loadingChanged();
}

void TrendingHistoryViewModel::setError(const QString &msg)
{
    if (m_lastError == msg) return;
    m_lastError = msg;
    emit lastErrorChanged();
}

void TrendingHistoryViewModel::query(const QVariantList &sensorIds,
                                     const QDateTime &from, const QDateTime &to)
{
    QList<int> ids;
    for (const QVariant &v : sensorIds) {
        const int id = v.toInt();
        if (id > 0 && !ids.contains(id))
            ids.append(id);
    }
    if (ids.isEmpty()) {
        setError(QStringLiteral("Select at least one sensor."));
        emit messageSent(QStringLiteral("Trending"), m_lastError);
        return;
    }
    if (!from.isValid() || !to.isValid() || from >= to) {
        setError(QStringLiteral("Invalid time range."));
        emit messageSent(QStringLiteral("Trending"), m_lastError);
        return;
    }
    if (m_watcher->isRunning())
        return; // query đang chạy — bỏ qua bấm trùng, tránh dồn worker

    setError({});
    setLoading(true);
    m_gen++;
    const int gen = m_gen;
    m_watcher->setFuture(QtConcurrent::run([ids, from, to, gen]() -> HistoryTrendResult {
        HistoryTrendResult result;
        result.generation = gen;
        result.xMin = double(from.toMSecsSinceEpoch());
        result.xMax = double(to.toMSecsSinceEpoch());

        double yLo = std::numeric_limits<double>::max();
        double yHi = std::numeric_limits<double>::lowest();
        bool anyPoint = false;

        ScopedDbConnection db;
        if (!db.get().isOpen()) {
            result.error = QStringLiteral("Database not open.");
            return result;
        }
        SensorDataDao dao(db);
        for (int id : ids) {
            const auto series = dao.queryRangeForChart(id, from, to);
            if (series.points.isEmpty())
                continue;
            const auto dec = Downsampler::minMax(series.points,
                                                 Downsampler::kDefaultMaxPoints,
                                                 series.isAlarm);
            QVariantList buf;
            buf.reserve(dec.size());
            for (const auto &p : dec) {
                buf.append(QVariantMap{{"x", p.x}, {"y", p.y}});
                if (p.y < yLo) yLo = p.y;
                if (p.y > yHi) yHi = p.y;
                anyPoint = true;
            }
            result.seriesPoints.insert(QString::number(id), buf);
        }

        // Trục Y: cùng quy tắc margin 10% như MonitorController::computeTrendAxes.
        if (!anyPoint) {
            yLo = 0;
            yHi = 1;
        } else if (yHi <= yLo) {
            yHi = yLo + 1;
        }
        double margin = (yHi - yLo) * 0.1;
        if (margin == 0) margin = 1;
        result.yMin = yLo - margin;
        result.yMax = yHi + margin;
        return result;
    }));
}

void TrendingHistoryViewModel::onQueryFinished()
{
    const auto result = m_watcher->result();
    setLoading(false);
    if (result.generation != m_gen)
        return; // query cũ (clear/query mới đã tăng gen) — bỏ
    if (!result.error.isEmpty()) {
        setError(result.error);
        emit messageSent(QStringLiteral("Trending"), result.error);
        return;
    }
    m_seriesPoints = result.seriesPoints;
    m_xMin = result.xMin;
    m_xMax = result.xMax;
    m_yMin = result.yMin;
    m_yMax = result.yMax;
    m_hasHistory = !m_seriesPoints.isEmpty();
    if (!m_hasHistory)
        emit messageSent(QStringLiteral("Trending"),
                         QStringLiteral("No data in the selected range."));
    emit historyChanged();
}

void TrendingHistoryViewModel::clear()
{
    m_gen++; // hủy kết quả query đang bay (nếu có)
    m_seriesPoints.clear();
    m_hasHistory = false;
    emit historyChanged();
}
