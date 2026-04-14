"""Core Crypto — Mã hóa/giải mã AES cho mật khẩu FTP.

Sử dụng Fernet (symmetric encryption) từ thư viện `cryptography`.
Key được sinh tự động lần đầu và lưu tại `config/secret.key`.
"""

from cryptography.fernet import Fernet

from core._paths import CONFIG_DIR

_KEY_FILE = CONFIG_DIR / "secret.key"


def _load_or_create_key() -> bytes:
    """Đọc key từ file, nếu chưa có thì sinh mới và lưu lại."""
    if _KEY_FILE.exists():
        return _KEY_FILE.read_bytes()

    key = Fernet.generate_key()
    _KEY_FILE.write_bytes(key)
    return key


# Singleton Fernet instance
_fernet = Fernet(_load_or_create_key())


def encrypt(plaintext: str) -> str:
    """Mã hóa chuỗi plaintext → chuỗi base64 đã mã hóa.

    Args:
        plaintext: Chuỗi gốc cần mã hóa (VD: mật khẩu FTP).

    Returns:
        Chuỗi đã mã hóa dạng base64 (lưu vào DB an toàn).
    """
    return _fernet.encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt(token: str) -> str:
    """Giải mã chuỗi base64 đã mã hóa → plaintext gốc.

    Args:
        token: Chuỗi đã mã hóa (đọc từ DB).

    Returns:
        Chuỗi plaintext gốc.

    Raises:
        cryptography.fernet.InvalidToken: Nếu token không hợp lệ hoặc key sai.
    """
    return _fernet.decrypt(token.encode("utf-8")).decode("utf-8")
