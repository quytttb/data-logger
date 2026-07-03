#pragma once
#include <QString>

namespace DeviceId {

// Raw Raspberry Pi CPU serial from /proc/cpuinfo (SoC OTP, not on SD card).
// Empty on non-Linux or when the serial line is missing.
QString hardwareSerial();

// Short hardware Device ID for display/support.
// Format: "DL-" + last 8 hex characters of hardwareSerial() (uppercase).
QString stationCode();

// SHA-256 hex digest of hardwareSerial() — used for device license binding.
QString fingerprint();

} // namespace DeviceId
