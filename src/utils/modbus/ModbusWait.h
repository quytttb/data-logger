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

} // namespace ModbusWait
