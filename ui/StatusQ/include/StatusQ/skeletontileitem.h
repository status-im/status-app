#pragma once

#include <QColor>
#include <QPointF>
#include <QPointer>
#include <QQuickItem>
#include <QSizeF>

class QSGTextureProvider;

// Rounded loading placeholder with a shimmer sweep, drawn in one pass.
//
// The sweep phase lives entirely on the scene graph side: the node advances it
// from a shared clock in preprocess() and requests the next frame itself. Nothing
// touches the item between syncs, so the item can be removed from the window at
// any moment, and with the threaded render loop the sweep keeps running while
// the GUI thread is busy. This is why it does not use UniformAnimator, which
// reads the live item on the render thread and crashes when it leaves the window
// (QTBUG-151922).
//
// With a mask, an item that provides a texture, the tile is drawn where the
// mask is opaque instead of as a rounded box.
class SkeletonTileItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor highlightColor READ highlightColor WRITE setHighlightColor NOTIFY highlightColorChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QPointF sweepOrigin READ sweepOrigin WRITE setSweepOrigin NOTIFY sweepOriginChanged)
    Q_PROPERTY(QSizeF sweepSize READ sweepSize WRITE setSweepSize NOTIFY sweepSizeChanged)
    Q_PROPERTY(QQuickItem* mask READ mask WRITE setMask NOTIFY maskChanged)

public:
    explicit SkeletonTileItem(QQuickItem* parent = nullptr);

    QColor color() const { return m_color; }
    void setColor(const QColor& color);

    QColor highlightColor() const { return m_highlightColor; }
    void setHighlightColor(const QColor& color);

    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);

    QPointF sweepOrigin() const { return m_sweepOrigin; }
    void setSweepOrigin(const QPointF& origin);

    QSizeF sweepSize() const { return m_sweepSize; }
    void setSweepSize(const QSizeF& size);

    QQuickItem* mask() const { return m_mask; }
    void setMask(QQuickItem* mask);

signals:
    void colorChanged();
    void highlightColorChanged();
    void radiusChanged();
    void sweepOriginChanged();
    void sweepSizeChanged();
    void maskChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

private:
    QColor m_color;
    QColor m_highlightColor;
    qreal m_radius = 4;
    QPointF m_sweepOrigin;
    QSizeF m_sweepSize;
    QPointer<QQuickItem> m_mask;
    // render thread
    QPointer<QSGTextureProvider> m_maskProvider;
};
