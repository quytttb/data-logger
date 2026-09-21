#include <QtTest>
#include <QTimeZone>
#include "core/history/HistoryTableModel.h"
#include "core/history/HistoryRow.h"

static HistoryRow makeRow(const QString &name, const QString &value)
{
    HistoryRow r;
    r.recordedAt = QDateTime(QDate(2026, 9, 21), QTime(10, 0, 0), QTimeZone::utc());
    r.sensorName = name;
    r.unit = QStringLiteral("°C");
    r.valueText = value;
    r.rawValueText = value;
    r.status = QStringLiteral("OK");
    r.isAlarm = false;
    return r;
}

class HistoryTableModelTest : public QObject {
    Q_OBJECT

private slots:
    void setRowsReplaces();
    void appendRowsInsertsIncrementally();
    void appendEmptyIsNoop();
};

void HistoryTableModelTest::setRowsReplaces()
{
    HistoryTableModel m;
    m.setRows({makeRow(QStringLiteral("T1"), QStringLiteral("25"))});
    QCOMPARE(m.rowCount(), 1);
    QCOMPARE(m.data(m.index(0, 1)).toString(), QString("T1"));

    m.setRows({makeRow(QStringLiteral("T2"), QStringLiteral("26")),
               makeRow(QStringLiteral("T3"), QStringLiteral("27"))});
    QCOMPARE(m.rowCount(), 2);
    QCOMPARE(m.data(m.index(0, 1)).toString(), QString("T2"));
    QCOMPARE(m.data(m.index(1, 3)).toString(), QString("27"));
}

void HistoryTableModelTest::appendRowsInsertsIncrementally()
{
    HistoryTableModel m;
    QSignalSpy countSpy(&m, &HistoryTableModel::countChanged);
    m.setRows({makeRow(QStringLiteral("T1"), QStringLiteral("25"))});
    QCOMPARE(m.rowCount(), 1);

    // Chunk 1: rowsAdded giữ nguyên row cũ, không reset.
    m.appendRows({makeRow(QStringLiteral("T2"), QStringLiteral("26")),
                  makeRow(QStringLiteral("T3"), QStringLiteral("27"))});
    QCOMPARE(m.rowCount(), 3);
    QCOMPARE(m.data(m.index(0, 1)).toString(), QString("T1"));
    QCOMPARE(m.data(m.index(1, 1)).toString(), QString("T2"));
    QCOMPARE(m.data(m.index(2, 3)).toString(), QString("27"));
    QCOMPARE(m.data(m.index(2, 4)).toString(), QString("27"));
    QVERIFY(countSpy.count() >= 2);

    // Chunk 2: nối tiếp cuối danh sách.
    m.appendRows({makeRow(QStringLiteral("T4"), QStringLiteral("28"))});
    QCOMPARE(m.rowCount(), 4);
    QCOMPARE(m.data(m.index(3, 1)).toString(), QString("T4"));
}

void HistoryTableModelTest::appendEmptyIsNoop()
{
    HistoryTableModel m;
    m.setRows({makeRow(QStringLiteral("T1"), QStringLiteral("25"))});
    QSignalSpy countSpy(&m, &HistoryTableModel::countChanged);
    m.appendRows({});
    QCOMPARE(m.rowCount(), 1);
    QCOMPARE(countSpy.count(), 0);
}

QTEST_MAIN(HistoryTableModelTest)
#include "history_table_model_test.moc"
