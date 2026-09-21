#include "core/history/HistoryViewModel.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDataDao.h"
#include "data/repositories/SensorDao.h"
#include <QtConcurrent>
#include <QQmlEngine>
#include <QJSEngine>
#include <QFile>
#include <QTextStream>

IMPLEMENT_QML_SINGLETON(HistoryViewModel)

HistoryViewModel::HistoryViewModel(QObject *parent) : QObject(parent)
{
    m_watcher = new QFutureWatcher<HistorySearchResult>(this);
    connect(m_watcher, &QFutureWatcher<HistorySearchResult>::finished,
            this, &HistoryViewModel::onSearchFinished);
    m_filterWatcher = new QFutureWatcher<QList<QVariantMap>>(this);
    connect(m_filterWatcher, &QFutureWatcher<QList<QVariantMap>>::finished,
            this, &HistoryViewModel::onFiltersFinished);
    reloadFilters();
}

HistoryViewModel::~HistoryViewModel() = default;

QDateTime HistoryViewModel::parseDateString(const QString &s, bool endOfDay)
{
    QDate d = QDate::fromString(s.trimmed(), QStringLiteral("dd/MM/yyyy"));
    if (!d.isValid())
        d = QDate::fromString(s.trimmed(), Qt::ISODate);
    if (!d.isValid())
        return {};
    return endOfDay ? d.endOfDay() : d.startOfDay();
}

void HistoryViewModel::setLoading(bool v)
{
    if (m_loading == v) return;
    m_loading = v;
    emit loadingChanged();
}

void HistoryViewModel::setFiltersLoading(bool v)
{
    if (m_filtersLoading == v) return;
    m_filtersLoading = v;
    emit filtersLoadingChanged();
}

void HistoryViewModel::setError(const QString &msg)
{
    if (m_lastError == msg) return;
    m_lastError = msg;
    emit lastErrorChanged();
}

void HistoryViewModel::reloadFilters()
{
    if (m_filterWatcher->isRunning()) return; // một lần đang chạy là đủ

    setFiltersLoading(true);
    m_filterWatcher->setFuture(QtConcurrent::run([]() -> QList<QVariantMap> {
        QList<QVariantMap> maps;
        ScopedDbConnection db;
        if (!db.get().isOpen())
            return maps;
        SensorDao sensorDao(db);
        const auto sensors = sensorDao.loadAll(/*activeOnly=*/true);
        maps.reserve(sensors.size());
        for (const auto &s : sensors)
            maps.append({{"id", s.id}, {"name", s.name}});
        return maps;
    }));
}

void HistoryViewModel::onFiltersFinished()
{
    setFiltersLoading(false);
    const auto maps = m_filterWatcher->result();
    if (maps.isEmpty()) {
        // Không có sensor → vẫn giữ "All sensors" default, không emit lại
        return;
    }
    reloadFiltersFromMaps(maps);
}

void HistoryViewModel::reloadFiltersFromMaps(const QList<QVariantMap> &maps)
{
    m_sensorNames = {QStringLiteral("All sensors")};
    m_sensorIds   = {0};
    for (const auto &m : maps) {
        m_sensorNames.append(m.value(QStringLiteral("name")).toString());
        m_sensorIds.append(m.value(QStringLiteral("id")));
    }
    emit sensorFiltersChanged();
}

void HistoryViewModel::search(const QString &fromDate, const QString &toDate, int sensorId)
{
    const QDateTime from = parseDateString(fromDate, false);
    const QDateTime to   = parseDateString(toDate, true);
    if (!from.isValid() || !to.isValid()) {
        setError(QStringLiteral("Invalid date format (use dd/MM/yyyy)."));
        emit messageSent(QStringLiteral("History"), m_lastError);
        return;
    }
    if (from > to) {
        setError(QStringLiteral("From date must be before To date."));
        emit messageSent(QStringLiteral("History"), m_lastError);
        return;
    }

    setError({});
    // Đã có kết quả cho đúng bộ lọc này → bỏ qua, không query lại.
    if (m_searchedOnce && !m_watcher->isRunning() && m_lastError.isEmpty()
        && fromDate == m_lastFromDate && toDate == m_lastToDate
        && sensorId == m_lastSensorId)
        return;
    if (m_watcher->isRunning()) {
        // Gộp request: chỉ nhớ pending, chạy khi search hiện tại xong.
        m_hasPending = true;
        m_pendingFromDate = fromDate;
        m_pendingToDate = toDate;
        m_pendingSensorId = sensorId;
        qDebug() << "HistoryViewModel: search in progress — queued pending request";
        return;
    }
    setLoading(true);
    m_searchGen++;
    m_chunkGen++; // hủy chuỗi chunk cũ (nếu search chồng lên nhau)
    m_lastFromDate = fromDate;
    m_lastToDate = toDate;
    m_lastSensorId = sensorId;
    const int gen = m_searchGen;
    m_watcher->setFuture(QtConcurrent::run([sensorId, from, to, gen]() -> HistorySearchResult {
        HistorySearchResult result;
        result.generation = gen;
        ScopedDbConnection db;
        if (!db.get().isOpen()) {
            result.error = QStringLiteral("Database not open.");
            return result;
        }
        SensorDataDao dataDao(db);
        SensorDao sensorDao(db);
        QHash<int, QPair<QString, QString>> sensorMeta;
        for (const auto &s : sensorDao.loadAll(false))
            sensorMeta.insert(s.id, {s.name, s.unit});

        const auto records = dataDao.query(sensorId, from, to, 2000);

        result.rows.reserve(records.size());
        for (const auto &d : records) {
            const auto meta = sensorMeta.value(d.sensorId);
            HistoryRow row;
            row.recordedAt = d.recordedAt;
            row.sensorName = meta.first;
            row.unit = meta.second;
            row.valueText = d.value.has_value()
                ? QString::number(*d.value, 'g', 6) : QStringLiteral("---");
            row.rawValueText = d.rawValue.has_value()
                ? QString::number(*d.rawValue, 'g', 6) : QStringLiteral("---");
            row.status = d.status;
            row.isAlarm = d.isAlarm;
            result.rows.append(row);
        }
        return result;
    }));
}

void HistoryViewModel::onSearchFinished()
{
    const auto result = m_watcher->result();
    Q_UNUSED(result.generation)
    m_searchGen = result.generation;
    if (m_hasPending) {
        // Có request mới trong lúc search — chạy ngay, không tắt loading
        m_hasPending = false;
        const QString pFrom = m_pendingFromDate;
        const QString pTo = m_pendingToDate;
        const int pId = m_pendingSensorId;
        search(pFrom, pTo, pId);
        return;
    }
    setLoading(false);
    if (!result.error.isEmpty()) {
        setError(result.error);
        emit messageSent(QStringLiteral("History"), result.error);
        return;
    }
    // Đổ rows theo từng batch 500 qua event loop thay vì setRows 1 lần 2000 rows:
    // mỗi batch chỉ vài ms, overlay loading vẫn hiện + BusyIndicator quay mượt.
    m_chunkGen++;
    m_pendingRows = result.rows;
    m_model.setRows({});
    emit recordCountChanged();
    if (m_pendingRows.isEmpty()) {
        m_searchedOnce = true;
        emit searchedOnceChanged();
        return;
    }
    setLoading(true);
    const int chunkGen = m_chunkGen;
    QTimer::singleShot(0, this, [this, chunkGen]() { pushChunk(chunkGen); });
}

void HistoryViewModel::pushChunk(int gen)
{
    if (gen != m_chunkGen)
        return; // search mới/clear đã hủy chuỗi này
    if (m_pendingRows.isEmpty()) {
        setLoading(false);
        m_searchedOnce = true;
        emit searchedOnceChanged();
        emit recordCountChanged();
        return;
    }
    const auto chunk = m_pendingRows.mid(0, kChunkRows);
    m_pendingRows = m_pendingRows.mid(chunk.size());
    m_model.appendRows(chunk);
    emit recordCountChanged();
    QTimer::singleShot(0, this, [this, gen]() { pushChunk(gen); });
}

void HistoryViewModel::clear()
{
    m_chunkGen++; // hủy chuỗi chunk đang chạy (nếu có)
    m_pendingRows.clear();
    m_model.setRows({});
    // Reset để lần bấm tab tới search lại từ đầu (guard searchedOnce).
    if (m_searchedOnce) {
        m_searchedOnce = false;
        emit searchedOnceChanged();
    }
    emit recordCountChanged();
}
