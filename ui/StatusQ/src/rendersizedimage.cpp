#include "StatusQ/rendersizedimage.h"

#include <QtCore/QCache>
#include <QtCore/QMimeDatabase>
#include <QtCore/QtMath>
#include <QtGui/QImageReader>
#include <QtQml/QQmlFile>
#include <QtQml/QQmlContext>
#include <QtQuick/private/qquickimage_p_p.h>
#include <QtQuickLayouts/private/qquicklayout_p.h>

namespace {

// Native sizes of decoded sources, so a cover decode of a source smaller than its box is
// requested at native size instead of upscaled. Keyed by the URL's hash to keep entries
// small; only touched on the GUI thread (load() and pixmapChange()).
QCache<size_t, QSize>& nativeSizes()
{
    static QCache<size_t, QSize> sizes(RenderSizedImage::maxKnownNativeSizes);
    return sizes;
}

bool isRenderSizedFillMode(QQuickImage::FillMode mode)
{
    return mode == QQuickImage::PreserveAspectFit || mode == QQuickImage::PreserveAspectCrop
            || mode == QQuickImage::Stretch;
}

// By file name only: no file access, case-insensitive globs
bool isVectorFileName(const QString& fileName)
{
    const QMimeType mime = QMimeDatabase().mimeTypeForFile(fileName, QMimeDatabase::MatchExtension);
    return mime.inherits(QStringLiteral("image/svg+xml"))
            || mime.inherits(QStringLiteral("image/svg+xml-compressed"));
}

} // namespace

class RenderSizedImagePrivate : public QQuickImagePrivate
{
public:
    // Private Qt hook, verified against Qt 6.11.0 (tested), 6.11.1 and 6.12.0 (source);
    // tst_StatusImage::test_privateDprHookActive fails if it stops being called.
    // Called by QQuickImageBase::load() when sourceSize is valid or the source is scalable,
    // and again by QQuickImageBase::itemChange() after a DPR change reload.
    bool updateDevicePixelRatio(qreal targetDevicePixelRatio) override
    {
        providerOptions.setPreserveAspectRatioFit(fillMode == QQuickImage::PreserveAspectFit);
        providerOptions.setPreserveAspectRatioCrop(fillMode == QQuickImage::PreserveAspectCrop);

        if (!inLoad)
            return QQuickImagePrivate::updateDevicePixelRatio(targetDevicePixelRatio);
        if (QQuickImagePrivate::updateDevicePixelRatio(targetDevicePixelRatio))
            return true;

        if (!sourcesize.isValid() || !isRenderSizedFillMode(fillMode))
            return false;

        // Bundled "@Nx" assets: let Qt pick the variant, which keeps sourceSize logical too.
        QUrl unused;
        qreal assetDevicePixelRatio = 1.0;
        QQuickImageBase::resolve2xLocalFile(resolvedUrl(), targetDevicePixelRatio, &unused,
                                            &assetDevicePixelRatio);
        if (!qFuzzyCompare(assetDevicePixelRatio, 1.0))
            return false;

        // Without the flags Qt fits the decode inside the requested box; with the crop flag
        // it covers the box, which Stretch needs too so neither axis is magnified.
        cover = fillMode != QQuickImage::PreserveAspectFit;
        providerOptions.setPreserveAspectRatioFit(false);
        providerOptions.setPreserveAspectRatioCrop(cover);

        decodeBox = decodeBoxFor(sourcesize, targetDevicePixelRatio);
        devicePixelRatio = requestRatio();
        renderSized = true;
        return true;
    }

    // Each side in device px, rounded up to the next decode step boundary so resizing within
    // a step reuses the decode. Boundaries are 16 device px apart up to 128, then 1/8 of the
    // size apart (at most ~27% extra pixels), capped at maxDecodeSide.
    static int decodeBucket(qreal devicePx)
    {
        int boundary = 0;
        while (boundary < devicePx && boundary < RenderSizedImage::maxDecodeSide)
            boundary += qMax(16, qCeil(boundary / 8.0));
        return qMin(boundary, int(RenderSizedImage::maxDecodeSide));
    }

    static QSize decodeBoxFor(const QSize& logical, qreal targetDevicePixelRatio)
    {
        const auto side = [targetDevicePixelRatio](int length) {
            return length > 0 ? decodeBucket(length * targetDevicePixelRatio) : 0;
        };
        return { side(logical.width()), side(logical.height()) };
    }

    // Qt requests sourcesize x devicePixelRatio: the ratio that reaches the decode box on
    // both sides, lowered for a known source so a cover decode neither upscales it nor
    // exceeds maxDecodeSide.
    qreal requestRatio()
    {
        qreal ratio = 0;
        if (sourcesize.width() > 0)
            ratio = qMax(ratio, qreal(decodeBox.width()) / sourcesize.width());
        if (sourcesize.height() > 0)
            ratio = qMax(ratio, qreal(decodeBox.height()) / sourcesize.height());

        // A cover decode is at least the request, so keep the request within maxDecodeSide
        if (cover)
            ratio = qMin(ratio, qreal(RenderSizedImage::maxDecodeSide)
                                    / qMax(sourcesize.width(), sourcesize.height()));

        const QSize* known = nativeSizes().object(qHash(resolvedUrl()));
        QSize native = known ? *known : QSize();
        if (cover && native.isEmpty())
            native = probeNativeSize(1.0, nullptr);
        nativeKnown = !native.isEmpty();
        if (cover && nativeKnown) {
            // Qt scales a cover decode by ratio x coverScale
            qreal coverScale = 0;
            if (sourcesize.width() > 0)
                coverScale = qMax(coverScale, qreal(sourcesize.width()) / native.width());
            if (sourcesize.height() > 0)
                coverScale = qMax(coverScale, qreal(sourcesize.height()) / native.height());
            const qreal maxScale = qMin(1.0, qreal(RenderSizedImage::maxDecodeSide)
                                                 / qMax(native.width(), native.height()));
            if (coverScale > 0)
                ratio = qMin(ratio, maxScale / coverScale);
        }
        return ratio > 0 ? ratio : 1.0;
    }

    // Logical implicit size: the decode fitted into the logical box, or the native size
    // when the source was decoded as is because it is smaller than the decode box.
    void updateImplicitRatio()
    {
        const QSize pix(currentPix->width(), currentPix->height());
        const QSize native = currentPix->implicitSize();
        const QSize requested = sourcesize * devicePixelRatio;
        const bool fitsBox = pix != native
                || (requested.width() > 0 && pix.width() >= requested.width())
                || (requested.height() > 0 && pix.height() >= requested.height());
        qreal ratio = 0;
        if (fitsBox) {
            if (sourcesize.width() > 0)
                ratio = qMax(ratio, qreal(pix.width()) / sourcesize.width());
            if (sourcesize.height() > 0)
                ratio = qMax(ratio, qreal(pix.height()) / sourcesize.height());
        }
        devicePixelRatio = ratio > 0 ? ratio : 1.0;
    }

    // Layout.preferredWidth/Height when in a layout that already attached them; read
    // without creating an attached object. An unsized item only gets its geometry at the
    // layout's polish, after the first load.
    QSize layoutPreferredSize() const
    {
        const auto item = static_cast<QQuickItem*>(q_ptr);
        if (!qobject_cast<QQuickLayout*>(item->parentItem()))
            return {};
        const auto attached = qobject_cast<QQuickLayoutAttached*>(
                qmlAttachedPropertiesObject<QQuickLayout>(item, false));
        if (!attached)
            return {};
        return { attached->isPreferredWidthSet() ? qCeil(attached->preferredWidth()) : 0,
                 attached->isPreferredHeightSet() ? qCeil(attached->preferredHeight()) : 0 };
    }

    // Native size of a local source from its header alone, recorded in nativeSizes();
    // empty when the source isn't a readable local raster. assetDevicePixelRatio is that of
    // the "@Nx" variant Qt would pick for targetDevicePixelRatio.
    QSize probeNativeSize(qreal targetDevicePixelRatio, qreal* assetDevicePixelRatio)
    {
        const QUrl resolved = resolvedUrl();
        QUrl file = resolved;
        qreal fileDevicePixelRatio = 1.0;
        QQuickImageBase::resolve2xLocalFile(resolved, targetDevicePixelRatio, &file,
                                            &fileDevicePixelRatio);
        const QString path = QQmlFile::urlToLocalFileOrQrc(file);
        if (vector || path.isEmpty())
            return {};

        QImageReader reader(path);
        const QSize native = reader.size();
        if (native.isEmpty())
            return {};
        if (file == resolved && !nativeSizes().contains(qHash(resolved)))
            nativeSizes().insert(qHash(resolved), new QSize(native));
        if (assetDevicePixelRatio)
            *assetDevicePixelRatio = fileDevicePixelRatio;
        return native;
    }

    QUrl resolvedUrl() const
    {
        const QQmlContext* context = qmlContext(static_cast<const QQuickItem*>(q_ptr));
        return context ? context->resolvedUrl(url) : url;
    }

    bool inLoad = false;
    bool deferredLoad = false;
    bool renderSized = false;
    bool cover = false;
    bool nativeKnown = false;
    bool explicitlySized = false;
    bool vector = false;
    QSize decodeBox;
};

RenderSizedImage::RenderSizedImage(QQuickItem* parent)
    : QQuickImage(*(new RenderSizedImagePrivate), parent)
{
    connect(this, &QQuickImageBase::sourceChanged, this, [this](const QUrl& source) {
        Q_D(RenderSizedImage);
        const bool vector = isVectorFileName(source.fileName());
        if (vector != d->vector) {
            d->vector = vector;
            emit vectorChanged();
        }
    });
}

void RenderSizedImage::setSourceSize(const QSize& size)
{
    Q_D(RenderSizedImage);
    const bool sameDecode = d->renderSized && isComponentComplete() && d->status == Ready
            && size.isValid() && size != d->sourcesize
            && RenderSizedImagePrivate::decodeBoxFor(size, d->effectiveDevicePixelRatio())
               == d->decodeBox;
    if (!sameDecode) {
        QQuickImage::setSourceSize(size);
        return;
    }

    d->sourcesize = size;
    emit sourceSizeChanged();
    pixmapChange();
}

int RenderSizedImage::knownNativeSizeCount()
{
    return nativeSizes().size();
}

bool RenderSizedImage::explicitlySized() const
{
    Q_D(const RenderSizedImage);
    return d->explicitlySized;
}

bool RenderSizedImage::isVector() const
{
    Q_D(const RenderSizedImage);
    return d->vector;
}

void RenderSizedImage::load()
{
    Q_D(RenderSizedImage);
    if (!d->sourcesize.isValid() && isRenderSizedFillMode(d->fillMode)) {
        const QSize preferred = d->layoutPreferredSize();
        if (preferred.width() > 0 || preferred.height() > 0) {
            d->sourcesize = preferred;
            emit sourceSizeChanged();
        }
    }

    // Not sized yet and nothing preferred: give the layout the header's natural size and
    // decode once it has settled, in this frame's polish pass.
    if (!d->sourcesize.isValid() && isRenderSizedFillMode(d->fillMode) && !d->explicitlySized
            && window() && window()->isVisible()) {
        qreal assetDevicePixelRatio = 1.0;
        QSize native = d->probeNativeSize(d->effectiveDevicePixelRatio(), &assetDevicePixelRatio);
        if (!native.isEmpty()) {
            if (autoTransform()) {
                QImageReader reader(QQmlFile::urlToLocalFileOrQrc(d->resolvedUrl()));
                if (reader.transformation() & QImageIOHandler::TransformationRotate90)
                    native.transpose();
            }
            d->deferredLoad = true;
            setImplicitSize(native.width() / assetDevicePixelRatio,
                            native.height() / assetDevicePixelRatio);
            polish();
            return;
        }
    }

    d->deferredLoad = false;
    d->renderSized = false;
    d->inLoad = true;
    QQuickImage::load();
    d->inLoad = false;
}

void RenderSizedImage::pixmapChange()
{
    Q_D(RenderSizedImage);
    if (d->renderSized && !d->currentPix->isNull()) {
        const QSize native = d->currentPix->implicitSize();
        const bool overLimit = d->currentPix->width() > qMin(native.width(), maxDecodeSide)
                || d->currentPix->height() > qMin(native.height(), maxDecodeSide);

        const size_t key = qHash(d->resolvedUrl());
        const QSize* known = nativeSizes().object(key);
        if (!known || *known != native)
            nativeSizes().insert(key, new QSize(native));

        // Only the first cover decode, before the native size is known, can upscale or
        // exceed maxDecodeSide; the reload is requested within both.
        if (overLimit && !d->nativeKnown)
            QMetaObject::invokeMethod(this, &RenderSizedImage::load, Qt::QueuedConnection);

        d->updateImplicitRatio();
    }
    QQuickImage::pixmapChange();
}

void RenderSizedImage::updatePolish()
{
    Q_D(RenderSizedImage);
    QQuickImage::updatePolish();
    // A layout still to polish sizes this item, which loads it through sourceSize
    const auto layout = qobject_cast<QQuickLayout*>(parentItem());
    if (d->deferredLoad && !(layout && QQuickItemPrivate::get(layout)->polishScheduled)) {
        d->deferredLoad = false;
        d->renderSized = false;
        d->inLoad = true;
        QQuickImage::load();
        d->inLoad = false;
    }
}

void RenderSizedImage::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    Q_D(RenderSizedImage);
    // QQuickImage would reset the probed implicit size to the empty pixmap's
    if (d->deferredLoad)
        QQuickImageBase::geometryChange(newGeometry, oldGeometry);
    else
        QQuickImage::geometryChange(newGeometry, oldGeometry);
    const bool sized = d->widthValid() || d->heightValid();
    if (sized != d->explicitlySized) {
        d->explicitlySized = sized;
        emit explicitlySizedChanged();
    }
}
