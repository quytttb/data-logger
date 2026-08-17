#pragma once
#include <QString>

namespace Crypto {
// AES-256-GCM (audit C1): khóa 256-bit lưu riêng ngoài DB trong file 0600
// (AppPaths::configDir()/crypto.key) — đọc file DB không còn đủ để lấy
// plaintext credential. Mật bản dạng "enc1:" + base64(iv ‖ ciphertext ‖ tag).
//
// Tương thích ngược: chuỗi chưa có tiền tố "enc1:" được coi là obfuscation
// Base64 đời cũ và giải trong suốt; lần lưu kế tiếp sẽ tái mã hóa AES-GCM.
QString encrypt(const QString &plain);
QString decrypt(const QString &cipher);

/// True nếu @p cipher đã là mật bản AES-GCM (tiền tố "enc1:").
bool isEncrypted(const QString &cipher);
}
