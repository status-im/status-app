#include "StatusQ/roundedrendersizedimage.h"

RoundedRenderSizedImage::RoundedRenderSizedImage(QQuickItem* parent)
    : RenderSizedImage(parent)
    , RoundedImageBase(this)
{
}

RoundedRenderSizedImage::RoundedArea RoundedRenderSizedImage::roundedArea() const
{
    return static_cast<RoundedArea>(area());
}

void RoundedRenderSizedImage::setRoundedArea(RoundedArea area)
{
    setArea(static_cast<Area>(area));
}

QSGNode* RoundedRenderSizedImage::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData* data)
{
    return updateRoundedNode(oldNode, [this, data](QSGNode* node) {
        return RenderSizedImage::updatePaintNode(node, data);
    });
}

void RoundedRenderSizedImage::notifyShapeChanged()
{
    emit shapeChanged();
}
