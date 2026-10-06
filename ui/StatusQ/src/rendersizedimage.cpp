#include "StatusQ/rendersizedimage.h"

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

        const int longestSide = qMax(sourcesize.width(), sourcesize.height());
        devicePixelRatio = longestSide > 0
                ? qMin(targetDevicePixelRatio, qreal(RenderSizedImage::maxDecodeSide) / longestSide)
                : targetDevicePixelRatio;
        renderSized = true;
        return true;
    }

    bool renderSized = false;
};

RenderSizedImage::RenderSizedImage(QQuickItem* parent)
    : QQuickImage(*(new RenderSizedImagePrivate), parent)
{
}

void RenderSizedImage::load()
{
    Q_D(RenderSizedImage);
    d->renderSized = false;
    QQuickImage::load();
}

void RenderSizedImage::pixmapChange()
{
    Q_D(RenderSizedImage);
    if (d->renderSized && !d->currentPix->isNull()) {
        const QSize requested = d->sourcesize * d->devicePixelRatio;
        const bool downscaled = (requested.width() > 0 && d->currentPix->width() >= requested.width())
                || (requested.height() > 0 && d->currentPix->height() >= requested.height());
        // A source smaller than the box was decoded as is: treat it as a 1x asset.
        if (!downscaled)
            d->devicePixelRatio = 1.0;
    }
    QQuickImage::pixmapChange();
}
