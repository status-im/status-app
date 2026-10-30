#pragma once

#include <QtCore/QObject>
#include <QtCore/QPointF>
#include <QtCore/QRectF>
#include <QtGui/QColor>

#include <array>
#include <functional>

class QQuickImage;
class QSGGeometry;
class QSGNode;

/*!
    The border of a rounded image, a grouped property as Rectangle's:
    \c width and \c color, black by default, and as Rectangle's pen it is
    drawn only once either is set, with a visible colour and a width that
    rounds to at least 1. Until its width is set it is the image's
    \c unsetBorderWidth, which still counts.
*/
class RoundedImageBorder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qreal width READ width WRITE setWidth NOTIFY changed)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY changed)

public:
    using QObject::QObject;

    qreal width() const { return m_widthSet ? m_width : m_unsetWidth; }
    void setWidth(qreal width);
    QColor color() const { return m_color; }
    void setColor(const QColor& color);
    // whether it is drawn
    bool isValid() const { return m_valid; }

    void setUnsetWidth(qreal width);

signals:
    void changed();

private:
    void validate();

    qreal m_width = 0;
    qreal m_unsetWidth = 0;
    bool m_widthSet = false;
    QColor m_color = Qt::black;
    // either was set
    bool m_set = false;
    bool m_valid = false;
};

/*!
    An image with rounded corners, drawn by its own scene graph node in one
    pass: the image's texture is sampled directly and each fragment's coverage
    comes from its distance to the rounded rectangle, so there is no layer, no
    mask texture and no hidden item. Shared by RoundedRenderSizedImage (a
    still image, decoded as StatusImage) and RoundedAnimatedImage, which
    declare its properties for QML and notify their changes with
    \c shapeChanged.

    By default the corners follow what is painted (\c roundedArea PaintedArea):
    the item for Stretch, PreserveAspectCrop and the tiled modes, the
    letterboxed image for PreserveAspectFit and Pad. With ItemArea the item's
    box is rounded and the painted image is clipped to it. Each corner radius
    defaults to \c radius.

    As within a Rectangle, the image is laid out inside the border
    (\c border.width, \c border.color), which runs along the item's edge
    with ItemArea and around the painted image with PaintedArea, and a
    background (\c backgroundColor) fills the shape under the image: the
    radii are the outer edge's and the inner corners are those less the
    border's width. Until the border is set its width is
    \c unsetBorderWidth, 0 by default and 1 as a Rectangle's: its band is
    then the background's and the image is clipped to the band's outer edge,
    as an image inset by a Rectangle's unset border and masked by its shape.
    All are drawn in the same pass, so the image and the border share their
    edge without a seam, and with no image (loading, error, no source) the
    border and the background are drawn alone. A circle can be cut out of
    them all where an overlapping icon sits (\c cutoutCenter,
    \c cutoutRadius, item coordinates).

    \c paintedWidth and \c paintedHeight are QQuickImage's, laid out in the
    whole item: for PreserveAspectFit they ignore the border.

    The per-image values travel as vertex attributes, so the material compares
    by texture only and the renderer can merge images that share an atlas
    texture into one draw call.

    The software renderer draws the plain image over the whole item:
    unrounded, with no border or background.
*/
class RoundedImageBase
{
public:
    qreal radius() const;
    void setRadius(qreal radius);

    qreal topLeftRadius() const;
    void setTopLeftRadius(qreal radius);
    void resetTopLeftRadius();
    qreal topRightRadius() const;
    void setTopRightRadius(qreal radius);
    void resetTopRightRadius();
    qreal bottomRightRadius() const;
    void setBottomRightRadius(qreal radius);
    void resetBottomRightRadius();
    qreal bottomLeftRadius() const;
    void setBottomLeftRadius(qreal radius);
    void resetBottomLeftRadius();

    // created on first use
    RoundedImageBorder* border();
    qreal unsetBorderWidth() const;
    void setUnsetBorderWidth(qreal width);

    QColor backgroundColor() const;
    void setBackgroundColor(const QColor& color);

    QPointF cutoutCenter() const;
    void setCutoutCenter(const QPointF& center);
    qreal cutoutRadius() const;
    void setCutoutRadius(qreal radius);

protected:
    // the items' RoundedArea enums
    enum Area { PaintedArea, ItemArea };

    explicit RoundedImageBase(QQuickImage* item);
    virtual ~RoundedImageBase() = default;
    Q_DISABLE_COPY_MOVE(RoundedImageBase)

    // emits the item's shapeChanged()
    virtual void notifyShapeChanged() = 0;

    Area area() const;
    void setArea(Area area);

    // The rounded node, or under the software renderer the plain one
    QSGNode* updateRoundedNode(QSGNode* oldNode,
                               const std::function<QSGNode*(QSGNode*)>& plainNode);

private:
    enum Corner { TopLeft, TopRight, BottomRight, BottomLeft };

    qreal cornerRadius(Corner corner) const;
    void setCornerRadius(Corner corner, qreal radius);
    void changed();

    // the border's width, set or not
    qreal borderWidth() const;
    bool borderVisible() const;
    // the item's box less the border
    QRectF contentBox() const;

    // with no image: the border and the background alone, or nothing
    QSGNode* updateBorderNode(QSGNode* oldNode);
    void writeVertices(QSGGeometry* geometry, const QRectF& area, const QRectF& painted,
                       const QRectF& uv) const;

    QQuickImage* m_item = nullptr;
    qreal m_radius = 0;
    // negative: follows m_radius
    std::array<qreal, 4> m_corners{ -1, -1, -1, -1 };
    RoundedImageBorder* m_border = nullptr;
    qreal m_unsetBorderWidth = 0;
    QColor m_backgroundColor = Qt::transparent;
    QPointF m_cutoutCenter;
    qreal m_cutoutRadius = 0;
    Area m_area = PaintedArea;
};
