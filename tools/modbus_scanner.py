import argparse
from pymodbus.client import ModbusSerialClient


def scan_modbus(port):
    baudrates = [9600, 19200, 38400, 115200, 4800]
    parities = ["N", "E", "O"]
    slave_ids = list(range(1, 10))

    print(f"Bắt đầu dò Modbus trên cổng {port}...")

    for baud in baudrates:
        for parity in parities:
            print(f"Đang thử Baudrate: {baud}, Parity: {parity}...")
            client = ModbusSerialClient(
                port=port, baudrate=baud, parity=parity, stopbits=1, bytesize=8, timeout=0.2
            )

            if not client.connect():
                print(f"  -> Không thể mở cổng {port}.")
                return

            try:
                for slave_id in slave_ids:
                    # Helper cho parameter compatibility giống core/modbus.py
                    kwargs = {}
                    try:
                        import inspect

                        sig = inspect.signature(client.read_holding_registers)
                        if "device_id" in sig.parameters:
                            kwargs["device_id"] = slave_id
                        elif "slave" in sig.parameters:
                            kwargs["slave"] = slave_id
                        else:
                            kwargs["unit"] = slave_id
                    except Exception:
                        kwargs["slave"] = slave_id

                    # Try reading holding register 0
                    result = client.read_holding_registers(address=0, count=1, **kwargs)
                    found = False
                    if not result.isError():
                        print("\n[+] TÌM THẤY THIẾT BỊ!")
                        print(f"  - Cổng: {port}")
                        print(f"  - Baudrate: {baud}")
                        print(f"  - Parity: {parity}")
                        print(f"  - Slave ID: {slave_id}")
                        print(f"  - Phản hồi từ Holding Register 0: {result.registers}")
                        found = True
                    elif hasattr(result, "exception_code"):
                        print("\n[+] TÌM THẤY THIẾT BỊ (Nhưng báo lỗi Exception)!")
                        print(f"  - Cổng: {port}")
                        print(f"  - Baudrate: {baud}")
                        print(f"  - Parity: {parity}")
                        print(f"  - Slave ID: {slave_id}")
                        print(f"  - Mã lỗi Exception: {result.exception_code}")
                        found = True

                    if found:
                        print("  => Đang quét thêm các thanh ghi Holding (0-500)...")
                        for addr in range(0, 500, 10):
                            res = client.read_holding_registers(address=addr, count=10, **kwargs)
                            if not res.isError() and not hasattr(res, "exception_code"):
                                print(
                                    f"     -> [Tìm thấy dải Holding] Từ addr {addr}: {res.registers}"
                                )
                                # Tìm chi tiết
                                for a in range(addr, addr + 10):
                                    r = client.read_holding_registers(address=a, count=1, **kwargs)
                                    if not r.isError() and not hasattr(r, "exception_code"):
                                        print(f"        * Holding Register {a}: {r.registers}")

                        print("  => Đang quét thêm các thanh ghi Input (0-500)...")
                        for addr in range(0, 500, 10):
                            try:
                                sig_input = inspect.signature(client.read_input_registers)
                                kwargs_input = {}
                                if "device_id" in sig_input.parameters:
                                    kwargs_input["device_id"] = slave_id
                                elif "slave" in sig_input.parameters:
                                    kwargs_input["slave"] = slave_id
                                else:
                                    kwargs_input["unit"] = slave_id
                            except Exception:
                                kwargs_input = {"slave": slave_id}
                            res = client.read_input_registers(
                                address=addr, count=10, **kwargs_input
                            )
                            if not res.isError() and not hasattr(res, "exception_code"):
                                print(
                                    f"     -> [Tìm thấy dải Input] Từ addr {addr}: {res.registers}"
                                )
                                # Tìm chi tiết
                                for a in range(addr, addr + 10):
                                    r = client.read_input_registers(
                                        address=a, count=1, **kwargs_input
                                    )
                                    if not r.isError() and not hasattr(r, "exception_code"):
                                        print(f"        * Input Register {a}: {r.registers}")
                        return

            finally:
                client.close()

    print("\n[-] Không tìm thấy thiết bị nào phản hồi với các tham số phổ biến.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Quét thiết bị Modbus RTU")
    parser.add_argument("--port", default="/dev/ttyACM0", help="Cổng Serial (vd: /dev/ttyACM0)")
    args = parser.parse_args()

    scan_modbus(args.port)
