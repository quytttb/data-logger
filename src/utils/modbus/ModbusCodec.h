#pragma once
#include <QString>
#include <QStringList>
#include <QList>
#include <QVector>
#include <QModbusDataUnit>

// Shared Modbus encoding/decoding utilities used by both the polling worker
// (network/modbus) and the manual tester worker (network/workers). Keeping
// these helpers in one place avoids the register parsing/decoding logic from
// drifting between the two call sites.
namespace ModbusCodec {

QList<int> supportedBaudrates();
QStringList supportedDataTypes();
QStringList supportedDataFormats();
bool isSupportedBaudrate(int baudrate);

// Normalise a UI register-type label (e.g. "Input Register (3x)") into one of
// the canonical tokens: "input", "holding", "coil", "discrete_input".
QString normalizeRegisterType(const QString &uiLabel);

// Number of 16-bit registers required to hold a value of the given data type.
int registerCountForDataType(const QString &dataType);

// Decode a sequence of raw 16-bit registers into a numeric value according to
// the data type ("int16"/"uint16"/"int32"/"uint32"/"float32") and byte/word
// order format ("AB"/"BA"/"ABCD"/"CDAB"/"BADC"/"DCBA").
double decodeRegisters(const QVector<quint16> &regs,
                       const QString &dataType,
                       const QString &dataFormat);

// Encode a numeric value into 16-bit registers according to dataType/format.
// Đối xứng với decodeRegisters — dùng cho Tester write. Trả rỗng nếu value
// NaN/Inf hoặc ngoài range của dataType.
QVector<quint16> encodeRegisters(double value,
                                const QString &dataType,
                                const QString &dataFormat);

// Validate tổ hợp register_type / data_type / data_format.
// Trả rỗng nếu hợp lệ, ngược lại trả message lỗi.
QString validateSensorModbusConfig(const QString &registerType,
                                   const QString &dataType,
                                   const QString &dataFormat);

// Map a normalised register-type token to the corresponding Qt enum.
QModbusDataUnit::RegisterType toRegisterEnum(const QString &normalized);

} // namespace ModbusCodec
