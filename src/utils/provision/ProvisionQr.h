#pragma once
#include <QString>

namespace ProvisionQr {

/// Encode @p payload as PNG bytes (QR, ECC medium).
QByteArray pngBytes(const QString &payload, int pixelSize = 8);

/// Base64-encoded PNG suitable for QML `data:image/png;base64,...`.
QString pngBase64(const QString &payload, int pixelSize = 8);

} // namespace ProvisionQr
