#pragma once

#include <QtQuick/private/qquickimage_p.h>

class RenderSizedImagePrivate;

/*!
    Image whose raster sourceSize is in logical pixels, like it already is for SVGs. For the
    PreserveAspectFit, PreserveAspectCrop and Stretch fill modes a raster is decoded for
    sourceSize x device pixel ratio, rounded up to a step proportional to the size and capped
    at maxDecodeSide per side, and never above its native size; resizing within a step keeps
    the decode. A downscaled decode reports a logical implicit size, a source decoded at its
    native size keeps it, so binding sourceSize to the item's size cannot feed back into its
    implicit size. maxDecodeDevicePixelRatio, when above 0, decodes for at most that device
    pixel ratio (defaultMaxDecodeDevicePixelRatio unless set; 0 or less means no cap); it
    does not apply to sources Qt scales itself (SVG, image providers) or to bundled "@Nx"
    assets. A device pixel ratio change that keeps the decode does not reload. explicitlySized tells whether the item's size is set rather than taken
    from its implicit size; vector whether the source is an SVG (svg or svgz) by its MIME type.

    A remote (http/https) source that failed to load is remembered for failedSourceRetryMs:
    Qt warns about the first failure only, and until then any item showing that source goes
    to Error without requesting it again. A dead logo URL in a list of delegates is then one
    request and one log line instead of one per delegate and per re-creation.
*/
class RenderSizedImage : public QQuickImage
{
    Q_OBJECT
    Q_PROPERTY(bool explicitlySized READ explicitlySized NOTIFY explicitlySizedChanged)
    Q_PROPERTY(bool vector READ isVector NOTIFY vectorChanged)
    Q_PROPERTY(qreal maxDecodeDevicePixelRatio READ maxDecodeDevicePixelRatio
               WRITE setMaxDecodeDevicePixelRatio NOTIFY maxDecodeDevicePixelRatioChanged)

public:
    static constexpr int maxDecodeSide = 2048;
    // Initial maxDecodeDevicePixelRatio: photos decoded above 2x look the same on 3x+
    // screens and cost 2.25x the memory. 0 disables the default cap.
    static constexpr qreal defaultMaxDecodeDevicePixelRatio = 2.0;
    // Bound of the process-wide, GUI-thread-only LRU of native source sizes (~80 B each)
    static constexpr int maxKnownNativeSizes = 512;
    // Bound of the process-wide, GUI-thread-only LRU of failed remote sources (~40 B each)
    static constexpr int maxKnownFailedSources = 512;
    // How long a failed remote source is not requested again; long enough to stop the
    // repeats, short enough that an image missing because the network was down comes back
    static constexpr int failedSourceRetryMs = 5 * 60 * 1000;

    explicit RenderSizedImage(QQuickItem* parent = nullptr);

    void setSourceSize(const QSize& size) override;
    bool explicitlySized() const;
    bool isVector() const;
    qreal maxDecodeDevicePixelRatio() const;
    void setMaxDecodeDevicePixelRatio(qreal ratio);

    static int knownNativeSizeCount();
    static int knownFailedSourceCount();

signals:
    void explicitlySizedChanged();
    void vectorChanged();
    void maxDecodeDevicePixelRatioChanged();

protected:
    void load() override;
    void requestFinished() override;
    void pixmapChange() override;
    void updatePolish() override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;

private:
    void finishRequest();

    Q_DECLARE_PRIVATE(RenderSizedImage)
};
