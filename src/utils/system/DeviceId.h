#pragma once
#include <QString>

namespace DeviceId {

// Returns a short station code derived from the hardware machine ID.
// On Linux/Raspberry Pi this reads /etc/machine-id via QSysInfo.
// Format: "DL-" + first 8 hex characters (uppercase), e.g. "DL-A1B2C3D4".
// Falls back to "DL-00000000" on platforms where the machine ID is unavailable.
QString stationCode();

} // namespace DeviceId
