#pragma once
#include <QMutex>
#include <optional>

// Single-owner vật lý cho cổng RS-485 dùng chung giữa ModbusWorker
// (monitoring) và TesterWorker (tester thủ công) trong cùng process.
// Cả hai worker chạy trên thread riêng — mở chồng QModbusRtuSerialClient
// lên cùng port sẽ race → SEGV. tryLock() thất bại thì báo "Port busy"
// thay vì mở chồng. Non-blocking nên không bao giờ treo UI thread.
// utils là layer đáy nên network/core đều include được.
namespace ModbusPortGuard {

inline QMutex &mutex()
{
    static QMutex m;
    return m;
}

// RAII guard: giữ mutex từ tryLock() tới hết lifetime (kể cả move).
// Hủy/move-gán sẽ unlock đúng 1 lần — không bao giờ double-unlock.
class Guard {
public:
    Guard() = default;
    Guard(const Guard &) = delete;
    Guard &operator=(const Guard &) = delete;
    Guard(Guard &&other) noexcept : m_locked(other.m_locked)
    {
        other.m_locked = false;
    }
    Guard &operator=(Guard &&other) noexcept
    {
        if (this != &other) {
            release();
            m_locked = other.m_locked;
            other.m_locked = false;
        }
        return *this;
    }
    ~Guard() { release(); }

    // Giành quyền sở hữu cổng, non-blocking. Trả nullopt khi đang bận.
    static std::optional<Guard> tryLock()
    {
        if (!mutex().tryLock())
            return std::nullopt;
        Guard g;
        g.m_locked = true;
        return g;
    }

    bool holds() const { return m_locked; }

    void release()
    {
        if (m_locked) {
            m_locked = false;
            mutex().unlock();
        }
    }

private:
    bool m_locked = false;
};

} // namespace ModbusPortGuard
