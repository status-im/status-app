#pragma once

#include <QRectF>
#include <QQuickItem>

class NativeSwipeHandlerItem : public QQuickItem
{
    Q_OBJECT

    // If > 0, used as the normalization distance for swipe progress (logical units).
    Q_PROPERTY(qreal openDistance READ openDistance WRITE setOpenDistance NOTIFY openDistanceChanged)
    // Android: expand native touch overlay to the full window and emit tapToDismissRequested on a
    // stationary tap (used when WebView would otherwise steal taps outside the narrow edge strip).
    Q_PROPERTY(bool fullScreenTapToDismissEnabled READ fullScreenTapToDismissEnabled WRITE setFullScreenTapToDismissEnabled NOTIFY fullScreenTapToDismissEnabledChanged)
    // When fullScreenTapToDismissEnabled is set, native overlay uses this rect (scene / window logical coords)
    // instead of the handler item bounds — typically the “outside sidebar” strip.
    Q_PROPERTY(QRectF dismissTapOverlaySceneRect READ dismissTapOverlaySceneRect WRITE setDismissTapOverlaySceneRect NOTIFY dismissTapOverlaySceneRectChanged)

public:
    explicit NativeSwipeHandlerItem(QQuickItem *parent = nullptr);
    ~NativeSwipeHandlerItem() override = default;

    qreal openDistance() const { return m_openDistance; }
    void setOpenDistance(qreal d);

    bool fullScreenTapToDismissEnabled() const { return m_fullScreenTapToDismissEnabled; }
    void setFullScreenTapToDismissEnabled(bool enabled);

    QRectF dismissTapOverlaySceneRect() const { return m_dismissTapOverlaySceneRect; }
    void setDismissTapOverlaySceneRect(const QRectF &rect);

signals:
    void openDistanceChanged();
    void fullScreenTapToDismissEnabledChanged();
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
    bool m_fullScreenTapToDismissEnabled = false;
    QRectF m_dismissTapOverlaySceneRect;
};
