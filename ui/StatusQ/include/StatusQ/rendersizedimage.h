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
    implicit size. explicitlySized tells whether the item's size is set rather than taken
    from its implicit size.
*/
class RenderSizedImage : public QQuickImage
{
    Q_OBJECT
    Q_PROPERTY(bool explicitlySized READ explicitlySized NOTIFY explicitlySizedChanged)

public:
    static constexpr int maxDecodeSide = 2048;

    explicit RenderSizedImage(QQuickItem* parent = nullptr);

    void setSourceSize(const QSize& size) override;
    bool explicitlySized() const;

signals:
    void explicitlySizedChanged();

protected:
    void load() override;
    void pixmapChange() override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;

private:
    Q_DECLARE_PRIVATE(RenderSizedImage)
};
