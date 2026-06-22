#include "ProvisionQr.h"
#include "third_party/qrcodegen.hpp"
#include <QBuffer>
#include <QImage>

using qrcodegen::QrCode;
using qrcodegen::QrSegment;

namespace ProvisionQr {

QByteArray pngBytes(const QString &payload, int pixelSize)
{
    const QByteArray utf8 = payload.toUtf8();
    const QrCode qr = QrCode::encodeText(utf8.constData(), QrCode::Ecc::MEDIUM);
    const int size = qr.getSize();
    const int border = 4;
    const int dim = (size + border * 2) * pixelSize;

    QImage img(dim, dim, QImage::Format_RGB32);
    img.fill(Qt::white);

    for (int y = 0; y < size; ++y) {
        for (int x = 0; x < size; ++x) {
            if (!qr.getModule(x, y))
                continue;
            const int px = (x + border) * pixelSize;
            const int py = (y + border) * pixelSize;
            for (int dy = 0; dy < pixelSize; ++dy) {
                for (int dx = 0; dx < pixelSize; ++dx)
                    img.setPixel(px + dx, py + dy, qRgb(0, 0, 0));
            }
        }
    }

    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, "PNG");
    return bytes;
}

QString pngBase64(const QString &payload, int pixelSize)
{
    return QString::fromLatin1(pngBytes(payload, pixelSize).toBase64());
}

} // namespace ProvisionQr
