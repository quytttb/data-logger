#include "FtpClient.h"
#include <QTcpSocket>
#include <QFile>
#include <QFileInfo>
#include <QElapsedTimer>
#include <QRegularExpression>

namespace {

// Reads one FTP reply (single- or multi-line) from the control connection.
// Returns the 3-digit code, or -1 on timeout/disconnect. Full reply text
// (without CRLF) is appended to *out when non-null.
int readReply(QTcpSocket &sock, int timeoutMs, QString *out)
{
    QByteArray buf;
    QString code;
    QElapsedTimer timer;
    timer.start();
    for (;;) {
        buf += sock.readAll();
        // Scan complete lines for the reply terminator.
        int pos = 0;
        while (pos < buf.size()) {
            const int eol = buf.indexOf('\n', pos);
            if (eol < 0)
                break;
            const QString line = QString::fromLatin1(buf.mid(pos, eol - pos)).trimmed();
            if (code.isEmpty() && line.size() >= 4
                && line[0].isDigit() && line[1].isDigit() && line[2].isDigit()) {
                code = line.left(3);
                if (line[3] != QLatin1Char('-')) {
                    if (out)
                        *out = QString::fromLatin1(buf).trimmed();
                    return code.toInt();
                }
            } else if (!code.isEmpty()
                       && line.startsWith(code + QLatin1Char(' '))) {
                if (out)
                    *out = QString::fromLatin1(buf).trimmed();
                return code.toInt();
            }
            pos = eol + 1;
        }
        if (sock.state() != QAbstractSocket::ConnectedState)
            return -1;
        const int remain = timeoutMs - static_cast<int>(timer.elapsed());
        if (remain <= 0 || !sock.waitForReadyRead(remain))
            return -1;
    }
}

// Sends a command and reads the reply. Returns the reply code (-1 on I/O error).
int transact(QTcpSocket &sock, int timeoutMs, const QByteArray &cmd, QString *replyText)
{
    sock.write(cmd + "\r\n");
    if (!sock.waitForBytesWritten(timeoutMs))
        return -1;
    return readReply(sock, timeoutMs, replyText);
}

bool isPositive(int code) { return code >= 200 && code < 300; }

} // namespace

FtpClient::FtpClient(int timeoutMs) : m_timeoutMs(timeoutMs) {}

bool FtpClient::upload(const QString &host, int port,
                       const QString &username, const QString &password,
                       const QString &remoteDir, const QString &localPath,
                       QString *error)
{
    auto fail = [&](const QString &msg) {
        if (error)
            *error = msg;
        return false;
    };

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly))
        return fail(QStringLiteral("cannot open local file: ") + localPath);

    QTcpSocket ctrl;
    ctrl.connectToHost(host, port);
    if (!ctrl.waitForConnected(m_timeoutMs))
        return fail(QStringLiteral("connect failed: ") + ctrl.errorString());

    QString reply;
    int code = readReply(ctrl, m_timeoutMs, &reply);
    if (code != 220)
        return fail(QStringLiteral("bad greeting: ") + reply);

    code = transact(ctrl, m_timeoutMs, "USER " + username.toUtf8(), &reply);
    if (code == 331) {
        code = transact(ctrl, m_timeoutMs, "PASS " + password.toUtf8(), &reply);
        if (code != 230)
            return fail(QStringLiteral("login failed: ") + reply);
    } else if (code != 230) {
        return fail(QStringLiteral("USER rejected: ") + reply);
    }

    code = transact(ctrl, m_timeoutMs, "TYPE I", &reply);
    if (code != 200)
        return fail(QStringLiteral("TYPE I rejected: ") + reply);

    // Walk/create the remote directory (MKD -p semantics).
    QString dir = remoteDir.trimmed();
    if (!dir.startsWith(QLatin1Char('/')))
        dir.prepend(QLatin1Char('/'));
    while (dir.endsWith(QLatin1Char('/')) && dir.size() > 1)
        dir.chop(1);
    code = transact(ctrl, m_timeoutMs, "CWD /", &reply);
    if (!isPositive(code))
        return fail(QStringLiteral("CWD / failed: ") + reply);
    if (dir != QStringLiteral("/")) {
        const QStringList parts = dir.split(QLatin1Char('/'), Qt::SkipEmptyParts);
        for (const QString &part : parts) {
            code = transact(ctrl, m_timeoutMs, "CWD " + part.toUtf8(), &reply);
            if (isPositive(code))
                continue;
            // Missing — try to create it (257 created, 550 already exists).
            const int mkd = transact(ctrl, m_timeoutMs, "MKD " + part.toUtf8(), &reply);
            if (mkd != 257 && mkd != 550)
                return fail(QStringLiteral("MKD failed: ") + reply);
            code = transact(ctrl, m_timeoutMs, "CWD " + part.toUtf8(), &reply);
            if (!isPositive(code))
                return fail(QStringLiteral("CWD failed: ") + reply);
        }
    }

    // Passive data connection.
    code = transact(ctrl, m_timeoutMs, "PASV", &reply);
    if (code != 227)
        return fail(QStringLiteral("PASV rejected: ") + reply);
    static const QRegularExpression pasvRe(
        QStringLiteral(R"(\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\))"));
    const QRegularExpressionMatch m = pasvRe.match(reply);
    if (!m.hasMatch())
        return fail(QStringLiteral("cannot parse PASV reply: ") + reply);
    const QString dataHost = QStringLiteral("%1.%2.%3.%4")
        .arg(m.captured(1), m.captured(2), m.captured(3), m.captured(4));
    const quint16 dataPort = static_cast<quint16>(m.captured(5).toUInt() * 256 + m.captured(6).toUInt());

    QTcpSocket data;
    data.connectToHost(dataHost, dataPort);
    if (!data.waitForConnected(m_timeoutMs))
        return fail(QStringLiteral("data connect failed: ") + data.errorString());

    const QString fileName = QFileInfo(localPath).fileName();
    code = transact(ctrl, m_timeoutMs, "STOR " + fileName.toUtf8(), &reply);
    if (code != 125 && code != 150)
        return fail(QStringLiteral("STOR rejected: ") + reply);

    while (!file.atEnd()) {
        const QByteArray chunk = file.read(65536);
        qint64 written = 0;
        while (written < chunk.size()) {
            const qint64 n = data.write(chunk.constData() + written,
                                        chunk.size() - written);
            if (n < 0)
                return fail(QStringLiteral("data write failed: ") + data.errorString());
            written += n;
            if (!data.waitForBytesWritten(m_timeoutMs))
                return fail(QStringLiteral("data write timed out"));
        }
    }
    data.disconnectFromHost();
    if (data.state() != QAbstractSocket::UnconnectedState)
        data.waitForDisconnected(m_timeoutMs);

    code = readReply(ctrl, m_timeoutMs, &reply);
    if (code != 226 && code != 250)
        return fail(QStringLiteral("transfer not confirmed: ") + reply);

    transact(ctrl, m_timeoutMs, "QUIT", nullptr); // best effort
    return true;
}
