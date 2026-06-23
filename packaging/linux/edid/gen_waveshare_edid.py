#!/usr/bin/env python3
"""Generate a minimal EDID 1.4 block advertising a single 1024x600@60 detailed
timing.

Used to force the native resolution of the Waveshare 7" Capacitive Touch LCD (C)
on a Raspberry Pi running the full KMS driver (dtoverlay=vc4-kms-v3d).

Why this is needed: that Waveshare panel ships an HDMI board that clones the EDID
of an unrelated 1920x1080 monitor (reported as "LEN L1950wD"), so the Pi drives it
at 1080p and downscales. The legacy hdmi_cvt/hdmi_group/hdmi_mode lines from the
Waveshare manual are ignored by full KMS, and a cmdline `video=...M@60` CVT mode is
rejected by the vc4 HDMI driver. Overriding the connector EDID with this clean
1024x600 timing makes vc4 accept it and run the panel natively.

Deploy:
    sudo mkdir -p /lib/firmware/edid
    sudo cp waveshare-1024x600.bin /lib/firmware/edid/
    # then append to the single line in /boot/firmware/cmdline.txt:
    #   drm.edid_firmware=HDMI-A-1:edid/waveshare-1024x600.bin,HDMI-A-2:edid/waveshare-1024x600.bin
    # (both connectors so it works regardless of which micro-HDMI port is used)
"""
import struct


def mfr(s):
    a = (ord(s[0]) - 64) & 0x1F
    b = (ord(s[1]) - 64) & 0x1F
    c = (ord(s[2]) - 64) & 0x1F
    v = (a << 10) | (b << 5) | c
    return bytes([(v >> 8) & 0xFF, v & 0xFF])


def dtd_1024x600():
    pclk = 5100  # 51.00 MHz in 10 kHz units
    hact, hbl = 1024, 320
    vact, vbl = 600, 35
    hfp, hsw = 48, 104
    vfp, vsw = 3, 6
    hmm, vmm = 154, 86
    d = bytearray(18)
    d[0] = pclk & 0xFF
    d[1] = (pclk >> 8) & 0xFF
    d[2] = hact & 0xFF
    d[3] = hbl & 0xFF
    d[4] = ((hact >> 8) << 4) | (hbl >> 8)
    d[5] = vact & 0xFF
    d[6] = vbl & 0xFF
    d[7] = ((vact >> 8) << 4) | (vbl >> 8)
    d[8] = hfp & 0xFF
    d[9] = hsw & 0xFF
    d[10] = ((vfp & 0xF) << 4) | (vsw & 0xF)
    d[11] = (((hfp >> 8) & 0x3) << 6) | (((hsw >> 8) & 0x3) << 4) | \
            (((vfp >> 4) & 0x3) << 2) | ((vsw >> 4) & 0x3)
    d[12] = hmm & 0xFF
    d[13] = vmm & 0xFF
    d[14] = ((hmm >> 8) << 4) | (vmm >> 8)
    d[17] = 0x1E  # digital separate sync, +hsync +vsync
    return d


def desc_text(tag, text):
    d = bytearray(18)
    d[3] = tag
    d[5:18] = text[:13].ljust(13, '\n').encode('ascii')
    return d


def desc_range():
    d = bytearray(18)
    d[3] = 0xFD  # monitor range limits
    d[5] = 50   # min V Hz
    d[6] = 61   # max V Hz
    d[7] = 30   # min H kHz
    d[8] = 60   # max H kHz
    d[9] = 6    # max pixel clock / 10 MHz
    d[10] = 0x0A
    for i in range(11, 18):
        d[i] = 0x20
    return d


def build():
    edid = bytearray(128)
    edid[0:8] = bytes([0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00])
    edid[8:10] = mfr("LNX")
    edid[10:12] = struct.pack('<H', 0x0600)
    edid[12:16] = struct.pack('<I', 1)
    edid[16] = 0           # week
    edid[17] = 2025 - 1990  # year
    edid[18] = 1           # EDID version 1
    edid[19] = 4           # revision .4
    edid[20] = 0x80        # digital input
    edid[21] = 15          # h size cm
    edid[22] = 9           # v size cm
    edid[23] = 0x78        # gamma 2.2
    edid[24] = 0x02        # preferred timing in first DTD
    edid[25:35] = bytes([0xEE, 0x91, 0xA3, 0x54, 0x4C, 0x99, 0x26, 0x0F, 0x50, 0x54])
    for i in range(38, 54, 2):
        edid[i] = 0x01
        edid[i + 1] = 0x01
    edid[54:72] = dtd_1024x600()
    edid[72:90] = desc_range()
    edid[90:108] = desc_text(0xFC, "WS_1024x600")
    edid[108:126] = desc_text(0x10, "")
    edid[127] = (256 - (sum(edid[0:127]) % 256)) % 256
    return edid


if __name__ == "__main__":
    data = build()
    with open("waveshare-1024x600.bin", "wb") as f:
        f.write(data)
    print("wrote waveshare-1024x600.bin (%d bytes), checksum=0x%02x" %
          (len(data), data[127]))
