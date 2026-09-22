#include "utils/modbus/ModbusPortGuard.h"

#include <QtTest>

// RAII single-owner cổng RS-485: tryLock non-blocking, unlock đúng 1 lần
// kể cả move/release thừa — chống mở chồng client Modbus lên cùng port.
class TestPortGuard : public QObject
{
    Q_OBJECT

private slots:
    void tryLockSucceedsWhenFree()
    {
        auto g = ModbusPortGuard::Guard::tryLock();
        QVERIFY(g.has_value());
        QVERIFY(g->holds());
    }

    void secondTryLockFailsWhileHeld()
    {
        auto g1 = ModbusPortGuard::Guard::tryLock();
        QVERIFY(g1.has_value());
        // Non-recursive mutex: tryLock thứ hai fail ngay, KHÔNG block.
        auto g2 = ModbusPortGuard::Guard::tryLock();
        QVERIFY(!g2.has_value());
    }

    void releaseFreesForNextOwner()
    {
        {
            auto g = ModbusPortGuard::Guard::tryLock();
            QVERIFY(g.has_value());
            g->release();
            QVERIFY(!g->holds());
            // Release thừa an toàn (không double-unlock).
            g->release();
        }
        auto g2 = ModbusPortGuard::Guard::tryLock();
        QVERIFY(g2.has_value());
    }

    void moveTransfersOwnership()
    {
        auto g1 = ModbusPortGuard::Guard::tryLock();
        QVERIFY(g1.has_value());
        auto g2 = std::move(*g1);
        QVERIFY(!g1->holds());
        QVERIFY(g2.holds());
        // Mutex vẫn khóa trong lúc move — owner thứ ba fail.
        QVERIFY(!ModbusPortGuard::Guard::tryLock().has_value());
        g2.release();
        QVERIFY(ModbusPortGuard::Guard::tryLock().has_value());
    }

    void scopeExitUnlocks()
    {
        {
            auto g = ModbusPortGuard::Guard::tryLock();
            QVERIFY(g.has_value());
        } // RAII unlock khi ra khỏi scope
        QVERIFY(ModbusPortGuard::Guard::tryLock().has_value());
    }
};

QTEST_APPLESS_MAIN(TestPortGuard)
#include "port_guard_test.moc"
