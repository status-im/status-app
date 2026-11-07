#pragma once

#include <QColor>
#include <QPointF>
#include <QQuickItem>
#include <QSizeF>

// Rounded loading placeholder with a shimmer sweep, drawn in one pass.
//
// Phase advances in preprocess() from a shared clock. Visible tiles poll
// update() on the GUI thread; preprocess() must not call window()->update().
// UniformAnimator is not used (QTBUG-151922).
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
    ~SkeletonTileItem() override;

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
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

private:
    void syncSweep();

    QColor m_color;
    QColor m_highlightColor;
    qreal m_radius = 4;
    QPointF m_sweepOrigin;
    QSizeF m_sweepSize;
};
