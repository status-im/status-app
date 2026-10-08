#include "StatusQ/rendersizedimage.h"

#include <QtCore/QHash>
#include <QtCore/QtMath>
#include <QtQml/QQmlContext>
#include <QtQuick/private/qquickimage_p_p.h>

namespace {

// Native sizes of decoded sources, so a cover decode of a source smaller than its box is
// requested at native size instead of upscaled.
QHash<QUrl, QSize>& nativeSizes()
{
    static QHash<QUrl, QSize> sizes;
    return sizes;
}

constexpr int maxKnownNativeSizes = 4096;

bool isRenderSizedFillMode(QQuickImage::FillMode mode)
{
    return mode == QQuickImage::PreserveAspectFit || mode == QQuickImage::PreserveAspectCrop
            || mode == QQuickImage::Stretch;
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
        if (assetDevicePixelRatio != 1.0)
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
    // both sides, lowered to native size when a cover decode would upscale a known source.
    qreal requestRatio()
    {
        qreal ratio = 0;
        if (sourcesize.width() > 0)
            ratio = qMax(ratio, qreal(decodeBox.width()) / sourcesize.width());
        if (sourcesize.height() > 0)
            ratio = qMax(ratio, qreal(decodeBox.height()) / sourcesize.height());

        const QSize native = nativeSizes().value(resolvedUrl());
        nativeKnown = !native.isEmpty();
        if (cover && nativeKnown && sourcesize.width() > 0 && sourcesize.height() > 0) {
            const qreal nativeRatio = qMin(qreal(native.width()) / sourcesize.width(),
                                           qreal(native.height()) / sourcesize.height());
            ratio = qMin(ratio, nativeRatio);
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

    QUrl resolvedUrl() const
    {
        const QQmlContext* context = qmlContext(static_cast<const QQuickItem*>(q_ptr));
        return context ? context->resolvedUrl(url) : url;
    }

    bool inLoad = false;
    bool renderSized = false;
    bool cover = false;
    bool nativeKnown = false;
    bool explicitlySized = false;
    QSize decodeBox;
};

RenderSizedImage::RenderSizedImage(QQuickItem* parent)
    : QQuickImage(*(new RenderSizedImagePrivate), parent)
{
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

bool RenderSizedImage::explicitlySized() const
{
    Q_D(const RenderSizedImage);
    return d->explicitlySized;
}

void RenderSizedImage::load()
{
    Q_D(RenderSizedImage);
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
        const bool upscaled = d->currentPix->width() > native.width()
                || d->currentPix->height() > native.height();

        auto& sizes = nativeSizes();
        if (sizes.size() >= maxKnownNativeSizes)
            sizes.clear();
        sizes.insert(d->resolvedUrl(), native);

        // Only the first cover decode of a source smaller than its box can upscale; the
        // reload is requested at native size.
        if (upscaled && !d->nativeKnown)
            QMetaObject::invokeMethod(this, &RenderSizedImage::load, Qt::QueuedConnection);

        d->updateImplicitRatio();
    }
    QQuickImage::pixmapChange();
}

void RenderSizedImage::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    Q_D(RenderSizedImage);
    QQuickImage::geometryChange(newGeometry, oldGeometry);
    const bool sized = d->widthValid() || d->heightValid();
    if (sized != d->explicitlySized) {
        d->explicitlySized = sized;
        emit explicitlySizedChanged();
    }
}
