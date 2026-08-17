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
    QObject::connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    loop.exec();
    return reply->isFinished();
}

} // namespace ModbusWait
