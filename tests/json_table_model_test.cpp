#include <QtTest>
#include <QtQml>
#include "core/table/JsonTableModel.h"

class JsonTableModelTest : public QObject {
    Q_OBJECT

private slots:
    void headersAndCells();
    void setRowsReplacesAndSignals();
    void appendRowAndSetCell();
    void findRowMatchesFirstOccurrence();
    void findRowMissing();
    void clearEmpty();
};

void JsonTableModelTest::headersAndCells()
{
    JsonTableModel m;
    m.setHeaders(QVariantList{"Name", "Unit", "Active"});
    QCOMPARE(m.columnCount(), 3);
    QCOMPARE(m.headerData(0, Qt::Horizontal), QVariant("Name"));
    QCOMPARE(m.headerData(2, Qt::Horizontal), QVariant("Active"));
    QCOMPARE(m.headerData(3, Qt::Horizontal), QVariant());

    m.setRows(QVariantList{
        QVariantList{"T1", "°C", true},
        QVariantList{"DO1", "", false},
    });
    QCOMPARE(m.rowCount(), 2);
    QCOMPARE(m.data(m.index(0, 0), Qt::DisplayRole).toString(), QString("T1"));
    QCOMPARE(m.data(m.index(0, 1), Qt::DisplayRole).toString(), QString("°C"));
    QCOMPARE(m.data(m.index(0, 2), Qt::DisplayRole).toBool(), true);
    QCOMPARE(m.data(m.index(1, 2), Qt::DisplayRole).toBool(), false);
    QCOMPARE(m.data(m.index(1, 3), Qt::DisplayRole), QVariant());
    QCOMPARE(m.data(QModelIndex(), Qt::DisplayRole), QVariant());
}


void JsonTableModelTest::setRowsReplacesAndSignals()
{
    JsonTableModel m;
    QSignalSpy rowsSpy(&m, &JsonTableModel::rowsChanged);
    m.setRows(QVariantList{QVariantList{"a"}});
    QCOMPARE(rowsSpy.count(), 1);
    QCOMPARE(m.rowCount(), 1);

    m.setRows(QVariantList{QVariantList{"x"}, QVariantList{"y"}, QVariantList{"z"}});
    QCOMPARE(rowsSpy.count(), 2);
    QCOMPARE(m.rowCount(), 3);
    QCOMPARE(m.data(m.index(2, 0)).toString(), QString("z"));
}


void JsonTableModelTest::appendRowAndSetCell()
{
    JsonTableModel m;
    m.setHeaders(QVariantList{"Address", "Value"});
    m.appendRow(QVariantList{100, "12.5"});
    m.appendRow(QVariantList{101, "0"});
    QCOMPARE(m.rowCount(), 2);
    QCOMPARE(m.data(m.index(0, 0)).toInt(), 100);
    QCOMPARE(m.data(m.index(1, 1)).toString(), QString("0"));

    QSignalSpy dataSpy(&m, &QAbstractItemModel::dataChanged);
    m.setCell(0, 1, "13.0");
    QCOMPARE(dataSpy.count(), 1);
    QCOMPARE(m.data(m.index(0, 1)).toString(), QString("13.0"));
    QCOMPARE(m.rowCount(), 2);

    // Growing a short row via setCell appends the missing cells and widens
    // the column count (rows are wider than the declared headers).
    m.setCell(1, 3, "pad");
    QCOMPARE(m.columnCount(), 4);
    QCOMPARE(m.cell(1, 3).toString(), QString("pad"));

    // No-op setCell must not emit.
    dataSpy.clear();
    m.setCell(0, 1, "13.0");
    QCOMPARE(dataSpy.count(), 0);

    // Out-of-range setCell is a no-op.
    m.setCell(99, 0, "x");
    m.setCell(0, -1, "x");
    QCOMPARE(m.rowCount(), 2);
}

void JsonTableModelTest::findRowMatchesFirstOccurrence()
{
    JsonTableModel m;
    m.setRows(QVariantList{
        QVariantList{100, "a"},
        QVariantList{200, "b"},
        QVariantList{200, "c"},
    });
    QCOMPARE(m.findRow(0, 200), 1);
    QCOMPARE(m.findRow(1, "b"), 1);
}

void JsonTableModelTest::findRowMissing()
{
    JsonTableModel m;
    m.setRows(QVariantList{QVariantList{100, "a"}});
    QCOMPARE(m.findRow(0, 999), -1);
    QCOMPARE(m.findRow(5, 100), -1);
}

void JsonTableModelTest::clearEmpty()
{
    JsonTableModel m;
    m.setRows(QVariantList{QVariantList{"a"}});
    QSignalSpy rowsSpy(&m, &JsonTableModel::rowsChanged);
    m.clear();
    QCOMPARE(m.rowCount(), 0);
    QCOMPARE(rowsSpy.count(), 1);
    rowsSpy.clear();
    m.clear(); // clearing an already-empty model must not emit
    QCOMPARE(rowsSpy.count(), 0);
}

QTEST_MAIN(JsonTableModelTest)
#include "json_table_model_test.moc"