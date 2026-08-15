#include "mockimageprovider.h"

#include <QColor>
#include <QCryptographicHash>
#include <QImage>
#include <QPainter>

namespace {
constexpr int DefaultSize = 64;

quint32 hashOf(const QString& id)
{
    const QByteArray digest = QCryptographicHash::hash(id.toUtf8(), QCryptographicHash::Md5);
    return (static_cast<quint8>(digest[0]) << 24) | (static_cast<quint8>(digest[1]) << 16)
            | (static_cast<quint8>(digest[2]) << 8) | static_cast<quint8>(digest[3]);
}
} // namespace

MockImageProvider::MockImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage MockImageProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize)
{
    const int width = requestedSize.width() > 0 ? requestedSize.width() : DefaultSize;
    const int height = requestedSize.height() > 0 ? requestedSize.height() : DefaultSize;

    if (size)
        *size = QSize(width, height);

    const quint32 h = hashOf(id);
    const QColor background = QColor::fromHsv(static_cast<int>(h % 360), 160 + (h >> 9) % 80,
                                              150 + (h >> 17) % 90);
    const QColor foreground = QColor::fromHsv(static_cast<int>((h / 7 + 180) % 360), 200, 240);

    QImage image(width, height, QImage::Format_ARGB32_Premultiplied);
    image.fill(background);

    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setPen(Qt::NoPen);
    painter.setBrush(foreground);

    // A few shapes keyed off the hash: enough per-image variation that the
    // encoder/decoder cannot short-circuit and every tile is a distinct bitmap.
    const int cells = 4;
    const qreal cellW = qreal(width) / cells;
    const qreal cellH = qreal(height) / cells;
    for (int y = 0; y < cells; ++y) {
        for (int x = 0; x < cells; ++x) {
            if (!((h >> ((y * cells + x) % 32)) & 1u))
                continue;
            painter.drawEllipse(QRectF(x * cellW, y * cellH, cellW, cellH));
        }
    }
    painter.end();

    return image;
}
