#pragma once

#include <QByteArray>
#include <QSize>

class QImage;

// Prepares an image Attachment for sending, following the same rules as status-go's
// chat image pipeline (internal/images) so that status-go can pass the result through
// untouched (see docs/adr/0008-client-side-image-preparation.md):
//  - long side at most longSide px, EXIF orientation applied to the pixels,
//  - transparent images as PNG (flattened onto white JPEG when over maxBytes),
//  - other images as JPEG at the highest quality on the maxQuality..minQuality ladder
//    (step 2) under idealBytes, else minQuality when under maxBytes, else shrunk to 95%
//    and retried,
//  - animated GIF/WebP and images that already fit are sent as they are,
//  - SVG rasterised (to PNG, keeping transparency).
// Thread-safe: no shared state, meant to run on a worker thread.
namespace ImagePreparation {

struct Limits
{
    qint64 idealBytes = 50000;
    qint64 maxBytes = 350000;
    int longSide = 2000;
    int maxQuality = 80;
    int minQuality = 50;
};

struct Result
{
    enum class Kind {
        Original, // send the source as it is (status-go strips its metadata)
        Prepared, // send `data` (a JPEG or PNG, see `suffix`)
        Rejected, // can't be sent, see `reason`
    };
    enum class Reason {
        None,
        AnimationTooLarge, // animated image over maxBytes or longSide
        Unreadable,        // e.g. SVG without a renderer
    };

    Kind kind = Kind::Original;
    QByteArray data;
    QByteArray suffix; // "jpg" or "png" when Prepared, otherwise the source format if known
    Reason reason = Reason::None;
    QSize size;        // size of the image that will be sent, when known
};

Result prepare(const QByteArray& source, const Limits& limits = {});

// Exposed for tests.
bool hasTransparentPixel(const QImage& image);
QByteArray encodeJpegToLimits(const QImage& image, const Limits& limits);

} // namespace ImagePreparation
