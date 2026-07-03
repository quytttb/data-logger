#pragma once

namespace DeviceLock {

enum class State {
    Unbound,        // First run — no license stored yet
    Authorized,     // Hardware matches stored fingerprint
    Unauthorized,   // Hardware mismatch or tampered storage
};

// Inspect DB + backup file against the current hardware fingerprint.
State check();

// Persist the current hardware fingerprint (first-run auto-bind).
bool bind();

} // namespace DeviceLock
