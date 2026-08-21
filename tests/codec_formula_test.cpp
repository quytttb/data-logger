#include "utils/modbus/Formula.h"
#include "utils/modbus/ModbusCodec.h"

#include <QCoreApplication>
#include <QtTest>

#include <cstring>

// Audit P2-14: codec endianness là nơi rất dễ lỗi — phủ toàn bộ kiểu dữ liệu
// và thứ tự byte; Formula phủ hệ số tuyến tính.
class TestModbusCodec : public QObject
{
    Q_OBJECT

private slots:
    void registerCount()
    {
        QCOMPARE(ModbusCodec::registerCountForDataType("uint16"), 1);
        QCOMPARE(ModbusCodec::registerCountForDataType("int16"), 1);
        QCOMPARE(ModbusCodec::registerCountForDataType("float32"), 2);
        QCOMPARE(ModbusCodec::registerCountForDataType("int32"), 2);
        QCOMPARE(ModbusCodec::registerCountForDataType("uint32"), 2);
    }

    void normalizeRegisterType()
    {
        QCOMPARE(ModbusCodec::normalizeRegisterType("Holding"), "holding");
        QCOMPARE(ModbusCodec::normalizeRegisterType("Input Register"), "input");
        QCOMPARE(ModbusCodec::normalizeRegisterType("Coil"), "coil");
        QCOMPARE(ModbusCodec::normalizeRegisterType("Discrete Input"), "discrete_input");
        QCOMPARE(ModbusCodec::toRegisterEnum("holding"), QModbusDataUnit::HoldingRegisters);
        QCOMPARE(ModbusCodec::toRegisterEnum("coil"), QModbusDataUnit::Coils);
    }

    void decode16bit()
    {
        QCOMPARE(ModbusCodec::decodeRegisters({0x00FF}, "uint16", "AB"), 255.0);
        // int16: 0xFFFF = -1
        QCOMPARE(ModbusCodec::decodeRegisters({0xFFFF}, "int16", "AB"), -1.0);
        QCOMPARE(ModbusCodec::decodeRegisters({}, "uint16", "AB"), 0.0);
    }

    void decode32bitEndianness()
    {
        // 0x00010002 = 65538; AB (big-endian word order): regs[0]=hi, regs[1]=lo.
        const QVector<quint16> hiLo{0x0001, 0x0002};
        QCOMPARE(ModbusCodec::decodeRegisters(hiLo, "uint32", "AB"), 65538.0);
        // CDAB/BA = word-swapped: 0x00020001 = 131073.
        QCOMPARE(ModbusCodec::decodeRegisters(hiLo, "uint32", "CDAB"), 131073.0);
        QCOMPARE(ModbusCodec::decodeRegisters(hiLo, "uint32", "BA"), 131073.0);
        // int32 âm: 0xFFFFFFFF với AB → regs {0xFFFF, 0xFFFF} = -1
        QCOMPARE(ModbusCodec::decodeRegisters({0xFFFF, 0xFFFF}, "int32", "AB"), -1.0);
    }

    void decodeFloat32()
    {
        const float f = 12.5f;
        quint32 bits;
        std::memcpy(&bits, &f, sizeof(bits));
        const QVector<quint16> regs{quint16(bits >> 16), quint16(bits & 0xFFFF)};
        QCOMPARE(ModbusCodec::decodeRegisters(regs, "float32", "AB"), double(f));
    }

    void formula()
    {
        QCOMPARE(Formula::applyFormula(10.0, "{}"), 10.0);
        QCOMPARE(Formula::applyFormula(10.0, ""), 10.0);
        QCOMPARE(Formula::applyFormula(10.0, R"({"a":2,"b":3})"), 23.0);
        QCOMPARE(Formula::applyFormula(10.0, R"({"a":0.5})"), 5.0);
        QCOMPARE(Formula::applyFormula(10.0, R"({"b":7})"), 17.0);
        QCOMPARE(Formula::applyFormula(10.0, "not json"), 10.0);
    }
};

QTEST_MAIN(TestModbusCodec)
#include "codec_formula_test.moc"
