#pragma once
#include <QMutex>

// Single-owner vật lý cho cổng RS-485 dùng chung giữa ModbusWorker
// (monitoring) và TesterWorker (tester thủ công). Cả hai worker chạy trên
// thread riêng và từng mở QModbusRtuSerialClient chồng lên cùng port —
// race này gây SEGV (core 19:13 Pi .15, Tester Connect).
//
// Quy ước: worker nào giữ guard mới được connectDevice(); tryLock() thất
// bại thì báo "Port busy" thay vì mở chồng. Non-blocking nên không bao giờ
// treo UI thread (AGENTS rule). utils là layer đáy nên network/core đều
// include được.
namespace ModbusPortGuard {

inline QMutex &mutex()
{
    static QMutex m;
    return m;
}

} // namespace ModbusPortGuard
