#include "StatusQ/roundedanimatedimage.h"

RoundedAnimatedImage::RoundedAnimatedImage(QQuickItem* parent)
    : QQuickAnimatedImage(parent)
    , RoundedImageBase(this)
{
}

RoundedAnimatedImage::RoundedArea RoundedAnimatedImage::roundedArea() const
{
    return static_cast<RoundedArea>(area());
}

void RoundedAnimatedImage::setRoundedArea(RoundedArea area)
{
    setArea(static_cast<Area>(area));
}

QSGNode* RoundedAnimatedImage::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData* data)
{
    return updateRoundedNode(oldNode, [this, data](QSGNode* node) {
        return QQuickAnimatedImage::updatePaintNode(node, data);
    });
}

void RoundedAnimatedImage::notifyShapeChanged()
{
    emit shapeChanged();
}
