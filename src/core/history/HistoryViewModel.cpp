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

void HistoryViewModel::setError(const QString &msg)
{
    if (m_lastError == msg) return;
    m_lastError = msg;
    emit lastErrorChanged();
}

void HistoryViewModel::reloadFilters()
{
    ScopedDbConnection db;
    SensorDao sensorDao(db);
    const auto sensors = sensorDao.loadAll(/*activeOnly=*/true);

    QList<QVariantMap> maps;
    maps.reserve(sensors.size());
    for (const auto &s : sensors)
        maps.append({{"id", s.id}, {"name", s.name}});
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
    if (m_watcher->isRunning()) {
        m_watcher->cancel();
        m_watcher->waitForFinished();
    }
    setLoading(true);
    m_watcher->setFuture(QtConcurrent::run([sensorId, from, to]() -> HistorySearchResult {
        HistorySearchResult result;
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
    setLoading(false);
    const auto result = m_watcher->result();
    if (!result.error.isEmpty()) {
        setError(result.error);
        emit messageSent(QStringLiteral("History"), result.error);
        return;
    }
    m_model.setRows(result.rows);
    m_searchedOnce = true;
    emit searchedOnceChanged();
    emit recordCountChanged();
}

void HistoryViewModel::clear()
{
    m_model.setRows({});
    emit recordCountChanged();
}

static QString csvEscape(const QString &s)
{
    if (s.contains(QLatin1Char('"')) || s.contains(QLatin1Char(','))
                                      || s.contains(QLatin1Char('\n')))
        return QLatin1Char('"') + QString(s).replace(QLatin1Char('"'), QStringLiteral("\"\""))
               + QLatin1Char('"');
    return s;
}

void HistoryViewModel::exportCsv(const QUrl &fileUrl)
{
    const QString path = fileUrl.toLocalFile();
    const auto &rows   = m_model.rows();

    if (rows.isEmpty()) {
        emit exportFinished(false, tr("No data to export."));
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        emit exportFinished(false, tr("Cannot open file: %1").arg(file.errorString()));
        return;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << "\xEF\xBB\xBF";
    out << "Time,Sensor,Unit,Value,Raw,Status\n";

    for (const auto &r : rows) {
        out << csvEscape(r.recordedAt.toLocalTime()
                              .toString(QStringLiteral("dd/MM/yyyy HH:mm:ss"))) << ','
            << csvEscape(r.sensorName) << ','
            << csvEscape(r.unit) << ','
            << csvEscape(r.valueText) << ','
            << csvEscape(r.rawValueText) << ','
            << csvEscape(r.status) << '\n';
    }

    file.close();
    emit exportFinished(true, path);
}
