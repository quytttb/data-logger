#pragma once
#include <QByteArray>
#include <QString>

// Băm mật khẩu một chiều bằng PBKDF2-HMAC-SHA256.
//
// Chọn PBKDF2 thay vì Argon2id ở giai đoạn đầu vì chỉ dùng QtCore (không thêm
// dependency native cho Pi/ARM64). Chuỗi băm có tiền tố thuật toán + tham số
// nên có thể chuyển sang Argon2id sau này bằng cách thêm tiền tố mới và
// rehash khi người dùng đăng nhập thành công (xem verify(..., needsRehash)).
//
// Định dạng: pbkdf2-sha256$<iterations>$<base64(salt)>$<base64(key)>
// - Salt riêng cho từng mật khẩu, sinh bằng CSPRNG của hệ điều hành.
// - Không log, không lưu plaintext; mật khẩu được chuẩn hóa NFC trước khi băm.
// - So sánh kết quả theo thời gian hằng (constant-time).
namespace PasswordHasher {

struct Params {
    int iterations = 600000;  // OWASP 2023 cho PBKDF2-HMAC-SHA256
    int saltBytes  = 16;
    int keyBytes   = 32;
};

// Trả chuỗi rỗng nếu tham số không hợp lệ hoặc không đủ bộ nhớ.
QString hash(const QString &password, const Params &params = {});

// Trả false với mọi chuỗi băm hỏng/không đúng định dạng (không ném exception).
// Nếu @p needsRehash khác null: true khi tham số lưu trong chuỗi yếu hơn
// Params mặc định hiện tại — caller nên băm lại sau khi xác thực thành công.
bool verify(const QString &password, const QString &encoded, bool *needsRehash = nullptr);

// PBKDF2 thô, tách riêng để test vector RFC/tài liệu. Không dùng trực tiếp
// cho lưu mật khẩu (hãy dùng hash() để có salt + định dạng chuẩn).
QByteArray deriveKey(const QByteArray &password, const QByteArray &salt,
                     int iterations, int keyBytes);

} // namespace PasswordHasher
