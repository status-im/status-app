#pragma once

#include "StatusQ/roundedimagebase.h"

#include <QtQuick/private/qquickanimatedimage_p.h>

/*!
    An animated image (AnimatedImage, with its whole API) with rounded
    corners, a border and a background (RoundedImageBase). Each frame is
    drawn by the same node as a still RoundedRenderSizedImage.
*/
class RoundedAnimatedImage : public QQuickAnimatedImage, public RoundedImageBase
{
    Q_OBJECT
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY shapeChanged)
    Q_PROPERTY(qreal topLeftRadius READ topLeftRadius WRITE setTopLeftRadius
               RESET resetTopLeftRadius NOTIFY shapeChanged)
    Q_PROPERTY(qreal topRightRadius READ topRightRadius WRITE setTopRightRadius
               RESET resetTopRightRadius NOTIFY shapeChanged)
    Q_PROPERTY(qreal bottomRightRadius READ bottomRightRadius WRITE setBottomRightRadius
               RESET resetBottomRightRadius NOTIFY shapeChanged)
    Q_PROPERTY(qreal bottomLeftRadius READ bottomLeftRadius WRITE setBottomLeftRadius
               RESET resetBottomLeftRadius NOTIFY shapeChanged)
    Q_PROPERTY(RoundedImageBorder* border READ border CONSTANT)
    Q_PROPERTY(qreal unsetBorderWidth READ unsetBorderWidth WRITE setUnsetBorderWidth
               NOTIFY shapeChanged)
    Q_PROPERTY(QColor backgroundColor READ backgroundColor WRITE setBackgroundColor
               NOTIFY shapeChanged)
    Q_PROPERTY(QPointF cutoutCenter READ cutoutCenter WRITE setCutoutCenter NOTIFY shapeChanged)
    Q_PROPERTY(qreal cutoutRadius READ cutoutRadius WRITE setCutoutRadius NOTIFY shapeChanged)
    Q_PROPERTY(RoundedArea roundedArea READ roundedArea WRITE setRoundedArea NOTIFY shapeChanged)

public:
    enum RoundedArea { PaintedArea = RoundedImageBase::PaintedArea, ItemArea = RoundedImageBase::ItemArea };
    Q_ENUM(RoundedArea)

    explicit RoundedAnimatedImage(QQuickItem* parent = nullptr);

    RoundedArea roundedArea() const;
    void setRoundedArea(RoundedArea area);

signals:
    // any of the rounding's properties
    void shapeChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData* data) override;
    void notifyShapeChanged() override;
};
