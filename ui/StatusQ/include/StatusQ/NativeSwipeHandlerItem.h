#pragma once

#include <QQuickItem>

class NativeSwipeHandlerItem : public QQuickItem
{
    Q_OBJECT

    // If > 0, used as the normalization distance for swipe progress (logical units).
    Q_PROPERTY(qreal openDistance READ openDistance WRITE setOpenDistance NOTIFY openDistanceChanged)

public:
    explicit NativeSwipeHandlerItem(QQuickItem *parent = nullptr);
    ~NativeSwipeHandlerItem() override = default;

    qreal openDistance() const { return m_openDistance; }
    void setOpenDistance(qreal d);

signals:
    void openDistanceChanged();

    // Delta/velocity-only API. Units are logical pixels along X axis.
    void swipeStarted();
    void swipeUpdated(qreal delta, qreal velocity);
    void swipeEnded(qreal delta, qreal velocity, bool canceled);

protected:
    virtual void setupGestureRecognition();
    virtual void teardownGestureRecognition();

private:
    qreal m_openDistance = 0.0;
};
