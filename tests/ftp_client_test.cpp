#include "network/ftp/FtpClient.h"

#include <QtTest>
#include <QCoreApplication>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryFile>
#include <QSet>
#include <thread>
#include <atomic>

// Fake FTP server (RFC 959 subset) chạy trên main thread của test;
// FtpClient blocking chạy trên std::thread, main thread pump event
// bằng QTest::qWait để server xử lý socket.
class FakeFtpServer : public QTcpServer
{
    Q_OBJECT

public:
    QString expectedUser = QStringLiteral("pi");
    QString expectedPass = QStringLiteral("pi");
    QString receivedFileName;
    QByteArray receivedData;
    QStringList mkdDirs;
    QStringList cwdDirs;

    FakeFtpServer()
    {
        connect(this, &QTcpServer::newConnection,
                this, &FakeFtpServer::onNewConnection);
    }

    bool listenLocal()
    {
        return listen(QHostAddress::LocalHost, 0);
    }

private slots:
    void onNewConnection()
    {
        m_ctrl = nextPendingConnection();
        connect(m_ctrl, &QTcpSocket::readyRead, this, &FakeFtpServer::onCtrlReady);
        connect(m_ctrl, &QTcpSocket::disconnected, m_ctrl, &QTcpSocket::deleteLater);
        m_ctrl->write("220 FakeFTP ready\r\n");
    }

    void onCtrlReady()
    {
        m_ctrlBuf += m_ctrl->readAll();
        int eol = -1;
        while ((eol = m_ctrlBuf.indexOf('\n')) >= 0) {
            const QString line = QString::fromLatin1(m_ctrlBuf.left(eol)).trimmed();
            m_ctrlBuf.remove(0, eol + 1);
            if (!line.isEmpty())
                handleCommand(line);
        }
    }

    void onDataConnected()
    {
        m_data = m_dataServer->nextPendingConnection();
        connect(m_data, &QTcpSocket::readyRead, this, [this]() {
            m_receivedChunks += m_data->readAll();
        });
        connect(m_data, &QTcpSocket::disconnected, this, [this]() {
            receivedData = m_receivedChunks;
            m_ctrl->write("226 Transfer complete\r\n");
        });
    }

private:
    void handleCommand(const QString &line)
    {
        const QString cmd = line.section(QLatin1Char(' '), 0, 0).toUpper();
        const QString arg = line.section(QLatin1Char(' '), 1);
        if (cmd == QStringLiteral("USER")) {
            m_ctrl->write(arg == expectedUser ? "331 Need password\r\n"
                                              : "530 Bad user\r\n");
        } else if (cmd == QStringLiteral("PASS")) {
            m_ctrl->write(arg == expectedPass ? "230 Logged in\r\n"
                                              : "530 Login incorrect\r\n");
        } else if (cmd == QStringLiteral("TYPE")) {
            m_ctrl->write("200 Type set\r\n");
        } else if (cmd == QStringLiteral("CWD")) {
            const QString target = resolve(arg);
            if (m_dirs.contains(target)) {
                m_cwd = target;
                cwdDirs << target;
                m_ctrl->write("250 CWD ok\r\n");
            } else {
                m_ctrl->write("550 Not found\r\n");
            }
        } else if (cmd == QStringLiteral("MKD")) {
            const QString target = m_cwd == QStringLiteral("/")
                ? QStringLiteral("/") + arg
                : m_cwd + QStringLiteral("/") + arg;
            m_dirs.insert(target);
            mkdDirs << target;
            m_ctrl->write("257 Created\r\n");
        } else if (cmd == QStringLiteral("PASV")) {
            m_dataServer = new QTcpServer(this);
            m_dataServer->listen(QHostAddress::LocalHost, 0);
            const quint16 p = m_dataServer->serverPort();
            connect(m_dataServer, &QTcpServer::newConnection,
                    this, &FakeFtpServer::onDataConnected);
            m_ctrl->write(QStringLiteral("227 Entering passive (127,0,0,1,%1,%2)\r\n")
                              .arg(p / 256).arg(p % 256).toLatin1());
        } else if (cmd == QStringLiteral("STOR")) {
            receivedFileName = arg;
            m_receivedChunks.clear();
            m_ctrl->write("150 Opening data connection\r\n");
        } else if (cmd == QStringLiteral("QUIT")) {
            m_ctrl->write("221 Bye\r\n");
        } else {
            m_ctrl->write("502 Unknown\r\n");
        }
    }

    QString resolve(const QString &arg) const
    {
        if (arg.startsWith(QLatin1Char('/')))
            return arg;
        return m_cwd == QStringLiteral("/") ? QStringLiteral("/") + arg
                                            : m_cwd + QStringLiteral("/") + arg;
    }

    QTcpSocket *m_ctrl = nullptr;
    QByteArray m_ctrlBuf;
    QTcpServer *m_dataServer = nullptr;
    QTcpSocket *m_data = nullptr;
    QByteArray m_receivedChunks;
    QSet<QString> m_dirs = {QStringLiteral("/")};
    QString m_cwd = QStringLiteral("/");
};

class TestFtpClient : public QObject
{
    Q_OBJECT

private slots:
    void uploadCreatesDirsAndStoresFile()
    {
        FakeFtpServer server;
        QVERIFY(server.listenLocal());

        QTemporaryFile tmp;
        QVERIFY(tmp.open());
        tmp.write("hello-tt10");
        tmp.flush();
        const QString localPath = tmp.fileName();

        bool ok = false;
        QString error;
        std::atomic<bool> done{false};
        std::thread worker([&] {
            FtpClient client(5000);
            ok = client.upload(QStringLiteral("127.0.0.1"), server.serverPort(),
                               QStringLiteral("pi"), QStringLiteral("pi"),
                               QStringLiteral("/a/b"), localPath, &error);
            done = true;
        });
        while (!done)
            QTest::qWait(20);
        worker.join();

        QVERIFY2(ok, qPrintable(error));
        QCOMPARE(server.receivedFileName, QFileInfo(localPath).fileName());
        QCOMPARE(server.receivedData, QByteArray("hello-tt10"));
        QVERIFY(server.mkdDirs.contains(QStringLiteral("/a")));
        QVERIFY(server.mkdDirs.contains(QStringLiteral("/a/b")));
    }

    void wrongPasswordFails()
    {
        FakeFtpServer server;
        QVERIFY(server.listenLocal());

        QTemporaryFile tmp;
        QVERIFY(tmp.open());
        tmp.write("x");
        tmp.flush();

        bool ok = true;
        QString error;
        std::atomic<bool> done{false};
        std::thread worker([&] {
            FtpClient client(5000);
            ok = client.upload(QStringLiteral("127.0.0.1"), server.serverPort(),
                               QStringLiteral("pi"), QStringLiteral("sai"),
                               QStringLiteral("/"), tmp.fileName(), &error);
            done = true;
        });
        while (!done)
            QTest::qWait(20);
        worker.join();

        QVERIFY(!ok);
        QVERIFY(error.contains(QStringLiteral("login failed")));
    }

    void missingLocalFileFails()
    {
        FtpClient client(2000);
        QString error;
        const bool ok = client.upload(QStringLiteral("127.0.0.1"), 21,
                                      QStringLiteral("u"), QStringLiteral("p"),
                                      QStringLiteral("/"),
                                      QStringLiteral("/khong-ton-tai/file.txt"),
                                      &error);
        QVERIFY(!ok);
        QVERIFY(error.contains(QStringLiteral("cannot open")));
    }
};

QTEST_MAIN(TestFtpClient)
#include "ftp_client_test.moc"
