#pragma once
#include <QEventLoop>
#include <QModbusReply>
#include <QObject>
#include <QTimer>

// Chờ reply Modbus hoàn tất với timeout (AGENTS: mọi chờ I/O phải có timeout).
// Trả về true nếu reply đã finished, false nếu timeout. Người gọi vẫn phải
// deleteLater() reply trong cả hai trường hợp (khi timeout, coi như poll lỗi).
namespace ModbusWait {

inline bool waitForReply(QModbusReply *reply, int timeoutMs) {
    if (!reply) return false;
    if (reply->isFinished()) return true;

    QEventLoop loop;
    const QMetaObject::Connection cFinished =
        QObject::connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    QTimer timer;
    timer.setSingleShot(true);
    const QMetaObject::Connection cTimeout =
        QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();
    // Ngắt kết nối sau khi chờ xong để slot quit() treo không bao giờ kích
    // hoạt trễ trên loop đã thoát (flakiness khi timeout).
    QObject::disconnect(cFinished);
    QObject::disconnect(cTimeout);
    return reply->isFinished();
}

// Biến thể abortable cho worker có stop() đồng bộ trên cùng thread
// (ModbusWorker::stop bắn abortWaitRequested để thoát nested loop trước khi
// disconnectDevice — tránh reply treo → use-after-free). Typed template,
// không dùng SIGNAL()/SLOT() macro cũ.
template <typename Sender>
inline bool waitForReplyWithAbort(QModbusReply *reply, int timeoutMs,
                                  const Sender *aborter,
                                  void (Sender::*abortSignal)()) {
    if (!reply) return false;
    if (reply->isFinished()) return true;

    QEventLoop loop;
    const QMetaObject::Connection cFinished =
        QObject::connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    QMetaObject::Connection cAbort{};
    if (aborter && abortSignal)
        cAbort = QObject::connect(aborter, abortSignal, &loop, &QEventLoop::quit);
    QTimer timer;
    timer.setSingleShot(true);
    const QMetaObject::Connection cTimeout =
        QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();
    QObject::disconnect(cFinished);
    if (cAbort)
        QObject::disconnect(cAbort);
    QObject::disconnect(cTimeout);
    return reply->isFinished();
}

} // namespace ModbusWait
