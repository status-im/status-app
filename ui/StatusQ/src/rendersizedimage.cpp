#include "StatusQ/rendersizedimage.h"

#include <QtCore/QtMath>
#include <QtQml/QQmlContext>
#include <QtQuick/private/qquickimage_p_p.h>

class RenderSizedImagePrivate : public QQuickImagePrivate
{
public:
    // Private Qt hook, verified against Qt 6.11.0 (tested), 6.11.1 and 6.12.0 (source);
    // tst_StatusImage::test_privateDprHookActive fails if it stops being called.
    // Called by QQuickImageBase::load() when sourceSize is valid or the source is scalable.
    bool updateDevicePixelRatio(qreal targetDevicePixelRatio) override
    {
        providerOptions.setPreserveAspectRatioFit(fillMode == QQuickImage::PreserveAspectFit);

        if (QQuickImagePrivate::updateDevicePixelRatio(targetDevicePixelRatio))
            return true;

        if (!sourcesize.isValid())
            return false;

        // Bundled "@Nx" assets: let Qt pick the variant, which keeps sourceSize logical too.
        const QQmlContext* context = qmlContext(static_cast<QQuickItem*>(q_ptr));
        QUrl unused;
        qreal assetDevicePixelRatio = 1.0;
        QQuickImageBase::resolve2xLocalFile(context ? context->resolvedUrl(url) : url,
                                            targetDevicePixelRatio, &unused,
                                            &assetDevicePixelRatio);
        if (assetDevicePixelRatio != 1.0)
            return false;

        // Without the flag Qt fits the decode inside the requested box and never upscales;
        // with it, it covers the box and upscales small sources.
        providerOptions.setPreserveAspectRatioFit(false);

        // Qt requests sourcesize x devicePixelRatio: request the quantised device-px box
        // directly. RenderSizedImage::load() restores the logical size right after.
        logicalSize = sourcesize;
        decodeBox = decodeBoxFor(sourcesize, targetDevicePixelRatio);
        sourcesize = decodeBox;
        devicePixelRatio = 1.0;
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

    // Logical implicit size: the decode fitted into the logical box, or the native size
    // when the source was smaller than the decode box.
    void updateImplicitRatio()
    {
        const QSize pix(currentPix->width(), currentPix->height());
        const bool downscaled = (decodeBox.width() > 0 && pix.width() >= decodeBox.width())
                || (decodeBox.height() > 0 && pix.height() >= decodeBox.height());
        qreal ratio = 0.0;
        if (downscaled) {
            if (logicalSize.width() > 0)
                ratio = qMax(ratio, qreal(pix.width()) / logicalSize.width());
            if (logicalSize.height() > 0)
                ratio = qMax(ratio, qreal(pix.height()) / logicalSize.height());
        }
        devicePixelRatio = ratio > 0 ? ratio : 1.0;
    }

    bool renderSized = false;
    QSize logicalSize;
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
    d->logicalSize = size;
    emit sourceSizeChanged();
    pixmapChange();
}

void RenderSizedImage::load()
{
    Q_D(RenderSizedImage);
    d->renderSized = false;
    QQuickImage::load();
    if (d->renderSized)
        d->sourcesize = d->logicalSize;
}

void RenderSizedImage::pixmapChange()
{
    Q_D(RenderSizedImage);
    if (d->renderSized && !d->currentPix->isNull())
        d->updateImplicitRatio();
    QQuickImage::pixmapChange();
}
