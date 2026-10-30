#pragma once

#include <QColor>
#include <QPointF>
#include <QQuickItem>
#include <QSizeF>

// Rounded loading placeholder with a shimmer sweep, drawn in one pass.
//
// The sweep phase lives entirely on the scene graph side: the node advances it
// from a shared clock in preprocess() and requests the next frame from the
// render thread. Nothing touches the item between syncs, so the item can be
// removed from the window at any moment, and the sweep keeps running while the
// GUI thread is busy. This is why it does not use UniformAnimator, which reads
// the live item on the render thread and crashes when it leaves the window
// (QTBUG-151922).
class SkeletonTileItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor highlightColor READ highlightColor WRITE setHighlightColor NOTIFY highlightColorChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QPointF sweepOrigin READ sweepOrigin WRITE setSweepOrigin NOTIFY sweepOriginChanged)
    Q_PROPERTY(QSizeF sweepSize READ sweepSize WRITE setSweepSize NOTIFY sweepSizeChanged)

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

signals:
    void colorChanged();
    void highlightColorChanged();
    void radiusChanged();
    void sweepOriginChanged();
    void sweepSizeChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

private:
    QColor m_color;
    QColor m_highlightColor;
    qreal m_radius = 4;
    QPointF m_sweepOrigin;
    QSizeF m_sweepSize;
};
