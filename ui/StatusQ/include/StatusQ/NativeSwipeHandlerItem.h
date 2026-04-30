#pragma once

#include <QRectF>
#include <QQuickItem>

class NativeSwipeHandlerItem : public QQuickItem
{
    Q_OBJECT

    // If > 0, used as the normalization distance for swipe progress (logical units).
    Q_PROPERTY(qreal openDistance READ openDistance WRITE setOpenDistance NOTIFY openDistanceChanged)
    // Android: non-empty rect expands the native touch overlay to that region (scene / window logical
    // coords) and emits tapToDismissRequested on a stationary tap — e.g. outside the narrow edge strip
    // over WebView. Empty rect uses the handler item bounds.
    Q_PROPERTY(QRectF dismissTapOverlaySceneRect READ dismissTapOverlaySceneRect WRITE setDismissTapOverlaySceneRect NOTIFY dismissTapOverlaySceneRectChanged)

public:
    explicit NativeSwipeHandlerItem(QQuickItem *parent = nullptr);
    ~NativeSwipeHandlerItem() override = default;

    qreal openDistance() const { return m_openDistance; }
    void setOpenDistance(qreal d);

    QRectF dismissTapOverlaySceneRect() const { return m_dismissTapOverlaySceneRect; }
    void setDismissTapOverlaySceneRect(const QRectF &rect);

signals:
    void openDistanceChanged();
    void dismissTapOverlaySceneRectChanged();

    // Delta/velocity-only API. Units are logical pixels along X axis.
    void swipeStarted();
    void swipeUpdated(qreal delta, qreal velocity);
    void swipeEnded(qreal delta, qreal velocity, bool canceled);
    void tapToDismissRequested();

protected:
    virtual void setupGestureRecognition();
    virtual void teardownGestureRecognition();

private:
    qreal m_openDistance = 0.0;
    QRectF m_dismissTapOverlaySceneRect;
};
