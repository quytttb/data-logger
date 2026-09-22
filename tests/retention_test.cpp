#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QSqlDatabase>
#include <QSqlQuery>
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/SensorDataDao.h"
#include "data/models/Sensor.h"
#include "data/models/SensorData.h"

// Chính sách retention: sensor_data giữ tối đa 30 ngày, đồng bộ với file
// TXT báo cáo gửi Sở (kReportKeepDays). Test khóa hành vi xóa theo cutoff
// của deleteOlderThanChunked (cơ chế RetentionWorker dùng để purge).
class RetentionTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        m_tempDir = new QTemporaryDir();
        QVERIFY(m_tempDir->isValid());
        m_dbPath = m_tempDir->path() + QStringLiteral("/test.db");
    }

    void cleanupTestCase() {
        closeDb();
        delete m_tempDir;
    }

    void init() {
        QFile::remove(m_dbPath);
        closeDb();
        QVERIFY(Database::init(m_dbPath));

        // 1 sensor cha (FK sensor_data.sensor_id bắt buộc).
        ScopedDbConnection db;
        SensorDao sDao(db);
        Sensor s;
        s.name = QStringLiteral("retention-test");
        s.sensorSymbol = QStringLiteral("TEST");
        s.unit = QStringLiteral("C");
        QVERIFY(sDao.save(s));
        m_sensorId = s.id;
        QVERIFY(m_sensorId > 0);
    }

    void cleanup() {
        closeDb();
        QFile::remove(m_dbPath);
    }

    // Cutoff 30 ngày: bản 31 ngày bị xóa, bản 29 ngày + hôm nay giữ lại.
    void cutoff30Days() {
        const QDateTime now = QDateTime::currentDateTime();
        QVERIFY(insertReading(now.addDays(-31), 1.0));
        QVERIFY(insertReading(now.addDays(-29), 2.0));
        QVERIFY(insertReading(now, 3.0));

        ScopedDbConnection db;
        SensorDataDao dao(db);
        const int deleted = dao.deleteOlderThanChunked(now.addDays(-30), 50000);
        QCOMPARE(deleted, 1);
        QCOMPARE(rowCount(), 2);
    }

    // Chia chunk nhỏ (1 dòng/lần) vẫn xóa hết bản quá hạn qua nhiều vòng.
    void chunkedDeletesAllExpired() {
        const QDateTime now = QDateTime::currentDateTime();
        QVERIFY(insertReading(now.addDays(-40), 1.0));
        QVERIFY(insertReading(now.addDays(-35), 2.0));
        QVERIFY(insertReading(now, 3.0));

        ScopedDbConnection db;
        SensorDataDao dao(db);
        const int deleted = dao.deleteOlderThanChunked(now.addDays(-30), 1);
        QCOMPARE(deleted, 2);
        QCOMPARE(rowCount(), 1);
    }

    // Không có bản quá hạn: không xóa gì.
    void nothingExpired() {
        const QDateTime now = QDateTime::currentDateTime();
        QVERIFY(insertReading(now.addDays(-10), 1.0));

        ScopedDbConnection db;
        SensorDataDao dao(db);
        QCOMPARE(dao.deleteOlderThanChunked(now.addDays(-30), 50000), 0);
        QCOMPARE(rowCount(), 1);
    }

private:
    QTemporaryDir *m_tempDir = nullptr;
    QString m_dbPath;
    int m_sensorId = 0;

    void closeDb() {
        for (const QString &name : QSqlDatabase::connectionNames()) {
            QSqlDatabase::database(name).close();
            QSqlDatabase::removeDatabase(name);
        }
    }

    bool insertReading(const QDateTime &at, double value) {
        ScopedDbConnection db;
        SensorDataDao dao(db);
        SensorData d;
        d.sensorId = m_sensorId;
        d.value = value;
        d.recordedAt = at;
        return dao.insertBatch({d});
    }

    int rowCount() {
        ScopedDbConnection db;
        QSqlQuery q(db);
        q.exec(QStringLiteral("SELECT COUNT(*) FROM sensor_data"));
        return q.next() ? q.value(0).toInt() : -1;
    }
};

QTEST_MAIN(RetentionTest)
#include "retention_test.moc"
