#pragma once

#include <QColor>
#include <QPointF>
#include <QQuickItem>
#include <QTimer>

// A ripple's press and release, in milliseconds on the scene graph clock.
struct RippleTimeline
{
    qint64 pressTime = -1; // -1: at rest
    qint64 releaseTime = -1; // -1: held
    int expandDuration = 0;
    int collapseDuration = 0;
    qreal endRadius = 0;

    qint64 expandEnd() const { return pressTime + expandDuration; }
    // a release during the expansion collapses once it has finished
    qint64 collapseStart() const { return qMax(releaseTime, expandEnd()); }
    qint64 collapseEnd() const { return collapseStart() + collapseDuration; }

    qreal radiusAt(qint64 time) const;
    // nothing changes after `time` until the next press or release
    bool settledAt(qint64 time) const;
};

// Press ripple: a circle growing from `centre` and shrinking back after the
// release, clipped to the rounded bounds, drawn in one pass. The scene graph
// node computes the radius from the timeline and requests its own frames, so
// nothing reads the item between syncs and, with the threaded render loop, the
// ripple keeps animating while the GUI thread is busy.
class RippleItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QPointF centre READ centre WRITE setCentre NOTIFY centreChanged)
    Q_PROPERTY(qreal endRadius READ endRadius WRITE setEndRadius NOTIFY endRadiusChanged)
    Q_PROPERTY(int expandDuration READ expandDuration WRITE setExpandDuration NOTIFY expandDurationChanged)
    Q_PROPERTY(int collapseDuration READ collapseDuration WRITE setCollapseDuration NOTIFY collapseDurationChanged)
    Q_PROPERTY(bool active READ isActive NOTIFY activeChanged)
    Q_PROPERTY(qreal rippleRadius READ rippleRadius NOTIFY rippleRadiusChanged)

public:
    explicit RippleItem(QQuickItem* parent = nullptr);

    QColor color() const { return m_color; }
    void setColor(const QColor& color);

    // corner radius of the clip
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);

    QPointF centre() const { return m_centre; }
    void setCentre(const QPointF& centre);

    qreal endRadius() const { return m_timeline.endRadius; }
    void setEndRadius(qreal radius);

    int expandDuration() const { return m_timeline.expandDuration; }
    void setExpandDuration(int duration);

    int collapseDuration() const { return m_timeline.collapseDuration; }
    void setCollapseDuration(int duration);

    // from a press until the collapse after its release has finished
    bool isActive() const { return m_active; }

    // the radius at rest: the end radius once expanded, 0 once collapsed
    qreal rippleRadius() const { return m_rippleRadius; }

    const RippleTimeline& timeline() const { return m_timeline; }

    Q_INVOKABLE void press();
    Q_INVOKABLE void release();

signals:
    void colorChanged();
    void radiusChanged();
    void centreChanged();
    void endRadiusChanged();
    void expandDurationChanged();
    void collapseDurationChanged();
    void activeChanged();
    void rippleRadiusChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

private:
    void settle();
    void setActive(bool active);
    void setRippleRadius(qreal radius);

    QColor m_color;
    qreal m_radius = 0;
    QPointF m_centre;
    RippleTimeline m_timeline;
    QTimer m_settleTimer;
    bool m_active = false;
    qreal m_rippleRadius = 0;
};
