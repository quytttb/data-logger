#!/usr/bin/env python3
"""Modbus RTU slave gia lap cho Data Logger tren Raspberry Pi."""

import argparse
import logging
import math
import threading
import time

from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from pymodbus.server import StartSerialServer

# pymodbus 3.8.x dùng FramerType enum; 3.6.x dùng class ModbusRtuFramer.
try:
    from pymodbus.framer import FramerType
    RTU_FRAMER = FramerType.RTU
except ImportError:
    from pymodbus.framer import ModbusRtuFramer
    RTU_FRAMER = ModbusRtuFramer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True)
    parser.add_argument("--slave-id", type=int, default=1)
    parser.add_argument("--baudrate", type=int, default=9600)
    parser.add_argument("--value", type=float, default=25.0)
    parser.add_argument("--amplitude", type=float, default=2.0)
    parser.add_argument("--period", type=float, default=60.0)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    # Holding registers: address 0 is an int16 temperature in 0.1 C units.
    block = ModbusSequentialDataBlock(0, [0] * 128)
    # pymodbus 3.6.x accepts zero_mode in constructor; 3.8.x removed it.
    try:
        context = ModbusSlaveContext(hr=block, zero_mode=True)
    except TypeError:
        context = ModbusSlaveContext(hr=block)
        context.zero_mode = True
    server_context = ModbusServerContext(slaves={args.slave_id: context}, single=False)

    def update_value() -> None:
        value = args.value + args.amplitude * math.sin(time.time() * 2 * math.pi / args.period)
        raw = max(0, min(32767, round(value * 10)))
        # pymodbus 3.x may apply the one-based RTU offset before dispatch.
        block.setValues(0, [raw, raw])

    update_value()
    def updater() -> None:
        while True:
            update_value()
            time.sleep(1)

    threading.Thread(target=updater, daemon=True).start()
    logging.info("Gia lap slave=%d port=%s baudrate=%d holding[0]=%.1f +/- %.1f", args.slave_id, args.port, args.baudrate, args.value, args.amplitude)
    StartSerialServer(
        context=server_context,
        framer=RTU_FRAMER,
        port=args.port,
        baudrate=args.baudrate,
        bytesize=8,
        parity="N",
        stopbits=1,
        timeout=1,
    )


if __name__ == "__main__":
    main()
