#pragma once

#include <QtQuick/private/qquickimage_p.h>

class RenderSizedImagePrivate;

/*!
    Image whose raster sourceSize is in logical pixels, like it already is for SVGs: a raster
    is decoded to fit inside sourceSize x device pixel ratio, rounded up to a step proportional
    to the size (never upscaled, capped at maxDecodeSide per side); resizing within a step
    keeps the decode. A downscaled decode reports a logical implicit size, a source
    smaller than the box keeps its native one, so binding sourceSize to the item's size
    cannot feed back into its implicit size.
*/
class RenderSizedImage : public QQuickImage
{
    Q_OBJECT

public:
    static constexpr int maxDecodeSide = 2048;

    explicit RenderSizedImage(QQuickItem* parent = nullptr);

    void setSourceSize(const QSize& size) override;

protected:
    void load() override;
    void pixmapChange() override;

private:
    Q_DECLARE_PRIVATE(RenderSizedImage)
};
