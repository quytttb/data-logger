#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QSqlDatabase>
#include <QSqlQuery>
#include "utils/system/DeviceLock.h"
#include "utils/system/DeviceId.h"
#include "data/db/Database.h"

// Mock fingerprint for testing (since we can't rely on real CPU serial in CI)
static QString g_mockFingerprint = QStringLiteral("test_fingerprint_abc123");

// Test DeviceLock state machine: Unbound → bind → Authorized → tamper → Unauthorized
class DeviceLockTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        // Create temp dir for test DB and backup file
        m_tempDir = new QTemporaryDir();
        QVERIFY(m_tempDir->isValid());
        
        m_dbPath = m_tempDir->path() + QStringLiteral("/test.db");
        m_backupPath = m_tempDir->path() + QStringLiteral("/.device_key");
        
        // Override AppPaths::dataDir to point to temp (for backup file)
        qputenv("DATALOGGER_DATA_DIR", m_tempDir->path().toUtf8());
    }

    void cleanupTestCase() {
        if (QSqlDatabase::contains(QStringLiteral("main"))) {
            QSqlDatabase::database(QStringLiteral("main")).close();
            QSqlDatabase::removeDatabase(QStringLiteral("main"));
        }
        delete m_tempDir;
    }

    void init() {
        // Clean state before each test
        QFile::remove(m_dbPath);
        QFile::remove(m_backupPath);
        
        if (QSqlDatabase::contains(QStringLiteral("main")))
            QSqlDatabase::removeDatabase(QStringLiteral("main"));
        
        // Initialize DB with schema via public API
        QVERIFY(Database::init(m_dbPath));
    }

    void cleanup() {
        if (QSqlDatabase::contains(QStringLiteral("main"))) {
            QSqlDatabase::database(QStringLiteral("main")).close();
            QSqlDatabase::removeDatabase(QStringLiteral("main"));
        }
        QFile::remove(m_dbPath);
        QFile::remove(m_backupPath);
    }

    // Test 1: First run (no DB, no file) → Unbound
    void testUnbound() {
        // No license in DB, no backup file
        DeviceLock::State state = DeviceLock::check();
        QCOMPARE(state, DeviceLock::State::Unbound);
    }

    // Test 2: Bind writes to both stores
    void testBind() {
        QVERIFY(DeviceLock::bind());
        
        // Check DB contains fingerprint
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("main"));
        QSqlQuery q(db);
        QVERIFY(q.exec(QStringLiteral("SELECT fingerprint FROM device_license LIMIT 1")));
        QVERIFY(q.next());
        QString dbFp = q.value(0).toString();
        QVERIFY(!dbFp.isEmpty());
        
        // Check backup file contains fingerprint
        QFile f(m_backupPath);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QString fileFp = QString::fromUtf8(f.readAll()).trimmed();
        QVERIFY(!fileFp.isEmpty());
        
        // Both should match
        QCOMPARE(dbFp, fileFp);
    }

    // Test 3: After bind → Authorized
    void testAuthorizedAfterBind() {
        QVERIFY(DeviceLock::bind());
        DeviceLock::State state = DeviceLock::check();
        QCOMPARE(state, DeviceLock::State::Authorized);
    }

    // Test 4: Tamper - delete DB row → Unauthorized (not Unbound)
    void testTamperDeleteDb() {
        QVERIFY(DeviceLock::bind());
        QCOMPARE(DeviceLock::check(), DeviceLock::State::Authorized);
        
        // Tamper: delete DB license
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("main"));
        QSqlQuery q(db);
        QVERIFY(q.exec(QStringLiteral("DELETE FROM device_license")));
        
        // Should be Unauthorized, NOT Unbound (prevents re-bind bypass)
        DeviceLock::State state = DeviceLock::check();
        QCOMPARE(state, DeviceLock::State::Unauthorized);
    }

    // Test 5: Tamper - delete backup file → Unauthorized
    void testTamperDeleteBackup() {
        QVERIFY(DeviceLock::bind());
        QCOMPARE(DeviceLock::check(), DeviceLock::State::Authorized);
        
        // Tamper: delete backup file
        QVERIFY(QFile::remove(m_backupPath));
        
        DeviceLock::State state = DeviceLock::check();
        QCOMPARE(state, DeviceLock::State::Unauthorized);
    }

    // Test 6: Tamper - mismatch between DB and file → Unauthorized
    void testTamperMismatch() {
        QVERIFY(DeviceLock::bind());
        QCOMPARE(DeviceLock::check(), DeviceLock::State::Authorized);
        
        // Tamper: overwrite backup file with wrong fingerprint
        QFile f(m_backupPath);
        QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
        f.write("wrong_fingerprint_xyz");
        f.close();
        
        DeviceLock::State state = DeviceLock::check();
        QCOMPARE(state, DeviceLock::State::Unauthorized);
    }

    // Test 7: Hardware change simulation - write different fingerprint → Unauthorized
    void testHardwareChange() {
        QVERIFY(DeviceLock::bind());
        
        // Simulate moving SD card: write a different "device" fingerprint
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("main"));
        QSqlQuery q(db);
        QVERIFY(q.exec(QStringLiteral("UPDATE device_license SET fingerprint='different_device_fp'")));
        
        // Also update backup to match (simulates cloned SD card with its own backup)
        QFile f(m_backupPath);
        QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
        f.write("different_device_fp");
        f.close();
        
        // Now check() will compare against current hardware (which hasn't changed in this process)
        // Since the stored fp differs from DeviceId::fingerprint(), should be Unauthorized.
        // Note: In real scenario, current CPU serial would differ; in test, fingerprint is consistent
        // within same process, so this test checks the logic path.
        DeviceLock::State state = DeviceLock::check();
        
        // If DeviceId::fingerprint() returns consistent value in this process,
        // and we wrote "different_device_fp", the check should fail.
        // This depends on whether DeviceId is mockable; if not, we skip this test.
        if (DeviceId::fingerprint().isEmpty()) {
            QSKIP("DeviceId::fingerprint() returns empty in test environment");
        }
        
        // The stored fingerprint differs from current → Unauthorized
        QCOMPARE(state, DeviceLock::State::Unauthorized);
    }

private:
    QTemporaryDir *m_tempDir = nullptr;
    QString m_dbPath;
    QString m_backupPath;
};

QTEST_MAIN(DeviceLockTest)
#include "device_lock_test.moc"
