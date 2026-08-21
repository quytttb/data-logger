#include <QtTest>
#include <QModbusRtuSerialClient>
#include <QModbusDataUnit>
#include <QModbusReply>
#include <QSerialPort>
#include <QProcess>
#include <QTemporaryDir>
#include <QEventLoop>
#include <QTimer>
#include <QFile>
#include <QElapsedTimer>
#include <QThread>
#include <QStandardPaths>

// Integration test: Modbus RTU master (QModbusRtuSerialClient) đọc holding
// register từ slave giả lập (pymodbus) trên cặp serial ảo do socat tạo.
// Không cần phần cứng RS-485 thật.
//
// Skip (không fail) nếu thiếu socat / python3 / pymodbus — CI cài chúng,
// máy dev thiếu vẫn build + chạy các test khác bình thường.
class TestIntegrationModbus : public QObject
{
    Q_OBJECT

    QTemporaryDir m_tmpDir;
    QProcess *m_socat = nullptr;
    QProcess *m_sim   = nullptr;
    QString m_masterPort;
    QString m_slavePort;
    QString m_python3; // python3 có pymodbus (ưu tiên /usr/bin/python3)

private slots:
    void initTestCase()
    {
        QVERIFY(m_tmpDir.isValid());

        const QString simScript = QStringLiteral(SIMULATOR_SCRIPT_PATH);
        if (!QFile::exists(simScript))
            QSKIP("modbus_rtu_simulator.py not found in source tree");

        if (QStandardPaths::findExecutable(QStringLiteral("socat")).isEmpty())
            QSKIP("socat not installed");

        // GitHub Actions prepend toolcache Python vào PATH (không có pymodbus).
        // Ưu tiên /usr/bin/python3 (system python — apt cài pymodbus vào đây).
        const QStringList candidates = {
            QStringLiteral("/usr/bin/python3"),
            QStandardPaths::findExecutable(QStringLiteral("python3")),
        };
        for (const QString &py : candidates) {
            if (py.isEmpty() || !QFile::exists(py)) continue;
            QProcess probe;
            probe.start(py, {QStringLiteral("-c"), QStringLiteral("import pymodbus")});
            if (probe.waitForFinished(10000) && probe.exitCode() == 0) {
                m_python3 = py;
                break;
            }
        }
        if (m_python3.isEmpty())
            QSKIP("python3 with pymodbus not found");

        m_masterPort = m_tmpDir.path() + QStringLiteral("/ttyV0");
        m_slavePort  = m_tmpDir.path() + QStringLiteral("/ttyV1");

        m_socat = new QProcess(this);
        m_socat->start(QStringLiteral("socat"), {
            QStringLiteral("pty,link=%1,raw,echo=0").arg(m_masterPort),
            QStringLiteral("pty,link=%1,raw,echo=0").arg(m_slavePort),
        });
        QVERIFY(m_socat->waitForStarted(5000));
        QVERIFY(waitForFile(m_masterPort, 5000));
        QVERIFY(waitForFile(m_slavePort, 5000));

        m_sim = new QProcess(this);
        m_sim->setProcessChannelMode(QProcess::ForwardedErrorChannel);
        m_sim->start(m_python3,
                     {simScript,
                      QStringLiteral("--port"), m_slavePort,
                      QStringLiteral("--slave-id"), QStringLiteral("1"),
                      QStringLiteral("--baudrate"), QStringLiteral("9600"),
                      QStringLiteral("--value"), QStringLiteral("25.0"),
                      QStringLiteral("--amplitude"), QStringLiteral("2.0")});
        QVERIFY(m_sim->waitForStarted(5000));

        QTest::qWait(3000); // slave cần thời gian mở port (CI chậm hơn local)
        QVERIFY2(m_sim->state() == QProcess::Running,
                 qPrintable(QStringLiteral("simulator exited early: %1")
                                .arg(QString::fromUtf8(m_sim->readAllStandardError()))));
    }

    void readHoldingRegister()
    {
        QModbusRtuSerialClient client;
        client.setConnectionParameter(QModbusDevice::SerialPortNameParameter, m_masterPort);
        client.setConnectionParameter(QModbusDevice::SerialBaudRateParameter, 9600);
        client.setConnectionParameter(QModbusDevice::SerialDataBitsParameter, 8);
        client.setConnectionParameter(QModbusDevice::SerialParityParameter,
                                      QSerialPort::NoParity);
        client.setConnectionParameter(QModbusDevice::SerialStopBitsParameter, 1);
        client.setTimeout(2000);
        client.setNumberOfRetries(2);
        QVERIFY(client.connectDevice());

        // Retry tối đa 3 lần — CI container đôi khi cần thêm thời gian ổn định PTY.
        double value = -1;
        QString lastError;
        for (int attempt = 0; attempt < 3 && value < 0; ++attempt) {
            if (attempt > 0) QTest::qWait(1000);

            QModbusDataUnit request(QModbusDataUnit::HoldingRegisters, 0, 1);
            QModbusReply *reply = client.sendReadRequest(request, 1);
            if (!reply) { lastError = QStringLiteral("no reply"); continue; }

            QEventLoop loop;
            connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
            QTimer::singleShot(5000, &loop, &QEventLoop::quit);
            loop.exec();

            if (!reply->isFinished()) {
                lastError = QStringLiteral("timeout (not finished)");
                reply->deleteLater();
                continue;
            }
            if (reply->error() != QModbusDevice::NoError) {
                lastError = reply->errorString();
                reply->deleteLater();
                continue;
            }

            const QModbusDataUnit unit = reply->result();
            QCOMPARE(unit.valueCount(), 1);
            value = unit.value(0) / 10.0; // int16, đơn vị 0.1 °C
            reply->deleteLater();
        }

        client.disconnectDevice();
        QVERIFY2(value >= 0, qPrintable(QStringLiteral("all retries failed: %1").arg(lastError)));
        QVERIFY2(value >= 23.0 && value <= 27.0,
                 qPrintable(QStringLiteral("value %1 out of expected range [23,27]")
                                .arg(value)));
    }

    void cleanupTestCase()
    {
        if (m_sim) {
            m_sim->terminate();
            if (!m_sim->waitForFinished(3000)) m_sim->kill();
        }
        if (m_socat) {
            m_socat->terminate();
            if (!m_socat->waitForFinished(3000)) m_socat->kill();
        }
    }

private:
    static bool waitForFile(const QString &path, int timeoutMs)
    {
        QElapsedTimer t;
        t.start();
        while (t.elapsed() < timeoutMs) {
            if (QFile::exists(path)) return true;
            QThread::msleep(50);
        }
        return QFile::exists(path);
    }
};

QTEST_MAIN(TestIntegrationModbus)
#include "integration_modbus_test.moc"
