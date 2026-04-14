"""Core Formula — Công thức chuyển đổi giá trị cảm biến.

Hỗ trợ 2 loại công thức phổ biến trong công nghiệp:
1. Tuyến tính (linear):        y = a * x + b
2. Đa thức bậc cao (polynomial): y = a₀ + a₁x + a₂x² + ...
"""

import json
import logging

logger = logging.getLogger("datalogger.formula")


def apply_formula(raw_value: int | float, coefficient_json: str) -> float:
    """Áp dụng công thức quy đổi từ giá trị thô Modbus sang giá trị thực.

    Args:
        raw_value: Giá trị thô đọc từ thanh ghi Modbus.
        coefficient_json: Chuỗi JSON chứa hệ số công thức.
            - Tuyến tính: '{"a": 0.001, "b": 0}'    → y = 0.001x + 0
            - Đa thức:    '{"coeffs": [0, 0.1, 0.001]}' → y = 0 + 0.1x + 0.001x²
            - Rỗng/null:  '{}' → trả về raw_value nguyên bản

    Returns:
        Giá trị thực đã quy đổi.
    """
    if not coefficient_json or coefficient_json == "{}":
        return float(raw_value)

    try:
        coeff = json.loads(coefficient_json)
    except json.JSONDecodeError:
        logger.warning("JSON coefficient không hợp lệ: %s", coefficient_json)
        return float(raw_value)

    # === Dạng tuyến tính: y = a * x + b ===
    if "a" in coeff:
        a = float(coeff.get("a", 1.0))
        b = float(coeff.get("b", 0.0))
        return a * raw_value + b

    # === Dạng đa thức: y = Σ(aᵢ * xⁱ) ===
    if "coeffs" in coeff:
        coeffs = coeff["coeffs"]
        result = sum(c * (raw_value ** i) for i, c in enumerate(coeffs))
        return result

    # Fallback: trả về nguyên bản nếu không nhận diện được format
    logger.warning("Không nhận diện được format coefficient: %s", coeff)
    return float(raw_value)
