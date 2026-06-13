#pragma once
#include <QObject>
#include <QString>
#include <QDateTime>

// Generates TXT report files (Phụ lục 15 format) and logs them for FTP.
class ReportController : public QObject {
    Q_OBJECT

public:
    explicit ReportController(QObject *parent = nullptr);

public slots:
    Q_INVOKABLE void generateReport(const QDateTime &from, const QDateTime &to);

signals:
    void messageSent(QString title, QString body);
    void reportGenerated(QString filePath);
};
