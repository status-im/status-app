#include "StatusQ/imagepreparation.h"

#include <QBuffer>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QPainter>

namespace ImagePreparation {

namespace {

QByteArray encode(const QImage& image, const char* format, int quality = -1)
{
    QByteArray data;
    QBuffer buffer(&data);
    buffer.open(QIODevice::WriteOnly);
    QImageWriter writer(&buffer, format);
    if (quality >= 0)
        writer.setQuality(quality);
    if (!writer.write(image))
        return {};
    return data;
}

QImage flattenOnWhite(const QImage& image)
{
    QImage out(image.size(), QImage::Format_RGB32);
    out.fill(Qt::white);
    QPainter painter(&out);
    painter.drawImage(0, 0, image);
    painter.end();
    return out;
}

bool looksLikeSvg(const QByteArray& data)
{
    const auto head = data.left(1024).trimmed();
    return head.startsWith('<') && head.contains("<svg");
}

bool fits(QSize size, int longSide)
{
    return size.isValid() && size.width() <= longSide && size.height() <= longSide;
}

} // namespace

bool hasTransparentPixel(const QImage& image)
{
    if (!image.hasAlphaChannel())
        return false;
    const auto argb = image.convertToFormat(QImage::Format_ARGB32);
    for (int y = 0; y < argb.height(); ++y) {
        const auto line = reinterpret_cast<const QRgb*>(argb.constScanLine(y));
        for (int x = 0; x < argb.width(); ++x) {
            if (qAlpha(line[x]) != 255)
                return true;
        }
    }
    return false;
}

// Same choice as status-go's EncodeToLimits: the highest quality on the ladder whose output
// is under idealBytes, else minQuality if that is under maxBytes, else empty. The size grows
// with the quality, so it tries maxQuality first and then binary-searches the rest.
QByteArray encodeJpegToLimits(const QImage& image, const Limits& limits)
{
    QList<int> ladder;
    for (int q = limits.maxQuality; q >= limits.minQuality; q -= 2)
        ladder.append(q);
    if (ladder.isEmpty())
        return {};

    const auto rgb = image.convertToFormat(QImage::Format_RGB32);
    QHash<int, QByteArray> encoded;
    auto encodeAt = [&](int i) -> const QByteArray& {
        auto it = encoded.find(i);
        if (it == encoded.end())
            it = encoded.insert(i, encode(rgb, "jpeg", ladder[i]));
        return *it;
    };
    auto underIdeal = [&](const QByteArray& data) {
        return !data.isEmpty() && limits.idealBytes > data.size();
    };

    if (underIdeal(encodeAt(0)))
        return encoded[0];

    int lo = 1, hi = ladder.size() - 1, best = -1;
    while (lo <= hi) {
        const int mid = (lo + hi) / 2;
        if (underIdeal(encodeAt(mid))) {
            best = mid;
            hi = mid - 1;
        } else {
            lo = mid + 1;
        }
    }
    if (best >= 0)
        return encoded[best];

    const auto& lowest = encodeAt(ladder.size() - 1);
    if (!lowest.isEmpty() && limits.maxBytes > lowest.size())
        return lowest;
    return {};
}

Result prepare(const QByteArray& source, const Limits& limits)
{
    Result result;

    QBuffer probeBuffer;
    probeBuffer.setData(source);
    probeBuffer.open(QIODevice::ReadOnly);
    QImageReader probe(&probeBuffer);
    const auto format = probe.format().toLower();
    result.suffix = format;

    if (format.isEmpty()) {
        if (looksLikeSvg(source)) {
            // no SVG renderer available: status-go can't decode SVG either
            result.kind = Result::Kind::Rejected;
            result.reason = Result::Reason::Unreadable;
        }
        // anything else: let status-go decide (and report) as before
        return result;
    }

    const bool isSvg = format == "svg" || format == "svgz";
    const bool sendable = format == "jpeg" || format == "png" || format == "gif" || format == "webp";
    const auto storedSize = probe.size();

    // Animations are sent as they are (re-encoding would keep a single frame).
    if (!isSvg && probe.supportsAnimation() && probe.imageCount() > 1) {
        result.size = storedSize;
        if (source.size() <= limits.maxBytes && fits(storedSize, limits.longSide))
            return result;
        result.kind = Result::Kind::Rejected;
        result.reason = Result::Reason::AnimationTooLarge;
        return result;
    }

    // Already fits and displays upright without its EXIF: status-go passes it through.
    if (sendable && source.size() <= limits.maxBytes && fits(storedSize, limits.longSide)
        && probe.transformation() == QImageIOHandler::TransformationNone) {
        result.size = storedSize;
        return result;
    }

    QBuffer buffer;
    buffer.setData(source);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer, format);
    reader.setAutoTransform(true);
    if (storedSize.isValid() && !fits(storedSize, limits.longSide)) {
        // Decoding straight at the target size is much cheaper for JPEG (libjpeg DCT scaling).
        reader.setScaledSize(storedSize.scaled(limits.longSide, limits.longSide, Qt::KeepAspectRatio));
    }
    QImage image = reader.read();
    if (image.isNull()) {
        if (isSvg) {
            result.kind = Result::Kind::Rejected;
            result.reason = Result::Reason::Unreadable;
        }
        return result; // undecodable here: let status-go try
    }

    if (hasTransparentPixel(image)) {
        auto png = encode(image, "png");
        if (!png.isEmpty() && png.size() <= limits.maxBytes) {
            result.kind = Result::Kind::Prepared;
            result.data = std::move(png);
            result.suffix = "png";
            result.size = image.size();
            return result;
        }
        image = flattenOnWhite(image); // JPEG has no alpha
    }

    // Same rescale loop as status-go: shrink to 95% until it fits (bounded, unlike there).
    for (int round = 0; round < 60 && !image.isNull() && image.width() > 0 && image.height() > 0; ++round) {
        auto jpeg = encodeJpegToLimits(image, limits);
        if (!jpeg.isEmpty()) {
            result.kind = Result::Kind::Prepared;
            result.data = std::move(jpeg);
            result.suffix = "jpg";
            result.size = image.size();
            return result;
        }
        image = image.scaled(image.width() * 95 / 100, image.height() * 95 / 100,
                             Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    }
    return result; // give up preparing: let status-go handle the original
}

} // namespace ImagePreparation
