#include <StatusQ/NativeSwipeHandlerItem.h>

#ifdef Q_OS_IOS

#import <UIKit/UIKit.h>

#include <QMetaObject>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>
#include <QVector>

class NativeSwipeHandlerItem_iOS;

@interface NativeSwipePanTarget : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, assign) NativeSwipeHandlerItem_iOS *handler;
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
- (void)handleDismissTap:(UITapGestureRecognizer *)recognizer;
@end

class NativeSwipeHandlerItem_iOS : public NativeSwipeHandlerItem
{
    Q_OBJECT

public:
    explicit NativeSwipeHandlerItem_iOS(QQuickItem *parent = nullptr);
    ~NativeSwipeHandlerItem_iOS() override;

    void handlePanBegan(qreal translationX, qreal velocityX);
    void handlePanChanged(qreal translationX, qreal velocityX);
    void handlePanEnded(qreal translationX, qreal velocityX, bool canceled);
    QPointF mapViewPointToScene(const CGPoint &point) const;
    QPointF mapViewDeltaToScene(const CGPoint &delta) const;
    bool canHandleInput() const;
    bool hasDismissOverlay() const;

protected:
    void setupGestureRecognition() override;
    void teardownGestureRecognition() override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private slots:
    void updateDismissOverlay();

private:
    UIView *getUIView() const;
    qreal qtScaleFactor() const;
    CGRect sceneRectToViewRect(const QRectF &sceneRect) const;
    void removeDismissOverlay();
    void connectWindowGeometryUpdates();
    void disconnectWindowGeometryUpdates();

    UIPanGestureRecognizer *m_pan = nullptr;
    NativeSwipePanTarget *m_target = nullptr;
    bool m_attached = false;

    UIView *m_dismissOverlay = nullptr;
    UITapGestureRecognizer *m_dismissTap = nullptr;

    QVector<QMetaObject::Connection> m_windowConnections;
    QVector<QMetaObject::Connection> m_changeConnections;

    bool m_active = false;
    qreal m_startTranslationX = 0.0;
};

NativeSwipeHandlerItem_iOS::NativeSwipeHandlerItem_iOS(QQuickItem *parent)
    : NativeSwipeHandlerItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
    m_changeConnections.append(connect(this, &NativeSwipeHandlerItem::dismissTapOverlaySceneRectChanged,
                                       this, &NativeSwipeHandlerItem_iOS::updateDismissOverlay));
    m_changeConnections.append(connect(this, &QQuickItem::visibleChanged,
                                       this, &NativeSwipeHandlerItem_iOS::updateDismissOverlay));
    m_changeConnections.append(connect(this, &QQuickItem::enabledChanged,
                                       this, &NativeSwipeHandlerItem_iOS::updateDismissOverlay));
    QTimer::singleShot(0, this, [this]() { setupGestureRecognition(); });
}

NativeSwipeHandlerItem_iOS::~NativeSwipeHandlerItem_iOS()
{
    teardownGestureRecognition();
}

UIView *NativeSwipeHandlerItem_iOS::getUIView() const
{
    if (!window()) return nullptr;
    return reinterpret_cast<UIView *>(window()->winId());
}

qreal NativeSwipeHandlerItem_iOS::qtScaleFactor() const
{
    qreal qtScale = 1.0;
    const QString qtScaleEnv = qEnvironmentVariable("QT_SCALE_FACTOR");
    if (!qtScaleEnv.isEmpty()) {
        bool ok = false;
        const qreal parsed = qtScaleEnv.toDouble(&ok);
        if (ok && parsed > 0.0)
            qtScale = parsed;
    }
    return qtScale;
}

CGRect NativeSwipeHandlerItem_iOS::sceneRectToViewRect(const QRectF &sceneRect) const
{
    const qreal s = qtScaleFactor();
    return CGRectMake(sceneRect.x() * s, sceneRect.y() * s,
                      sceneRect.width() * s, sceneRect.height() * s);
}

bool NativeSwipeHandlerItem_iOS::canHandleInput() const
{
    return window() && isVisible() && isEnabled();
}

bool NativeSwipeHandlerItem_iOS::hasDismissOverlay() const
{
    const QRectF overlay = dismissTapOverlaySceneRect();
    return overlay.width() > 0.0 && overlay.height() > 0.0;
}

QPointF NativeSwipeHandlerItem_iOS::mapViewPointToScene(const CGPoint &point) const
{
    if (!window())
        return QPointF(point.x, point.y);
    const qreal qtScale = qtScaleFactor();
    return QPointF(point.x / qtScale, point.y / qtScale);
}

QPointF NativeSwipeHandlerItem_iOS::mapViewDeltaToScene(const CGPoint &delta) const
{
    if (!window())
        return QPointF(delta.x, delta.y);
    const qreal qtScale = qtScaleFactor();
    return QPointF(delta.x / qtScale, delta.y / qtScale);
}

void NativeSwipeHandlerItem_iOS::removeDismissOverlay()
{
    if (m_dismissTap) {
        if (m_dismissOverlay)
            [m_dismissOverlay removeGestureRecognizer:m_dismissTap];
        [m_dismissTap release];
        m_dismissTap = nullptr;
    }
    if (m_dismissOverlay) {
        [m_dismissOverlay removeFromSuperview];
        [m_dismissOverlay release];
        m_dismissOverlay = nullptr;
    }
}

void NativeSwipeHandlerItem_iOS::connectWindowGeometryUpdates()
{
    disconnectWindowGeometryUpdates();
    if (!window())
        return;
    m_windowConnections.append(connect(window(), &QQuickWindow::widthChanged,
                                         this, &NativeSwipeHandlerItem_iOS::updateDismissOverlay));
    m_windowConnections.append(connect(window(), &QQuickWindow::heightChanged,
                                         this, &NativeSwipeHandlerItem_iOS::updateDismissOverlay));
}

void NativeSwipeHandlerItem_iOS::disconnectWindowGeometryUpdates()
{
    for (const auto &c : std::as_const(m_windowConnections))
        disconnect(c);
    m_windowConnections.clear();
}

void NativeSwipeHandlerItem_iOS::updateDismissOverlay()
{
    if (!canHandleInput()) {
        removeDismissOverlay();
        return;
    }

    if (!hasDismissOverlay()) {
        removeDismissOverlay();
        return;
    }
    const QRectF r = dismissTapOverlaySceneRect();

    UIView *view = getUIView();
    if (!view) {
        removeDismissOverlay();
        return;
    }

    if (!m_target) {
        // setupGestureRecognition not finished yet; overlay will attach on next setup pass.
        return;
    }

    if (!m_dismissOverlay) {
        m_dismissOverlay = [[UIView alloc] initWithFrame:CGRectZero];
        m_dismissOverlay.backgroundColor = [UIColor clearColor];
        m_dismissOverlay.userInteractionEnabled = YES;
        m_dismissOverlay.autoresizingMask = UIViewAutoresizingNone;
        // WKWebView is often a native subview above the Qt root; keep the hit target on top.
        m_dismissOverlay.layer.zPosition = 1000000.0;

        m_dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:m_target action:@selector(handleDismissTap:)];
        m_dismissTap.numberOfTapsRequired = 1;
        m_dismissTap.cancelsTouchesInView = YES;
        m_dismissTap.delegate = m_target;
        [m_dismissOverlay addGestureRecognizer:m_dismissTap];
    }

    const CGRect frame = sceneRectToViewRect(r);
    m_dismissOverlay.frame = frame;

    if (m_dismissOverlay.superview != view)
        [view addSubview:m_dismissOverlay];
    [view bringSubviewToFront:m_dismissOverlay];
}

void NativeSwipeHandlerItem_iOS::setupGestureRecognition()
{
    UIView *view = getUIView();
    if (!view)
        return;

    if (!m_attached) {
        m_target = [[NativeSwipePanTarget alloc] init];
        [m_target setHandler:this];

        m_pan = [[UIPanGestureRecognizer alloc] initWithTarget:m_target action:@selector(handlePan:)];
        m_pan.maximumNumberOfTouches = 1;
        m_pan.delegate = m_target;
        [view addGestureRecognizer:m_pan];

        m_attached = true;
    } else if (m_pan && m_pan.view != view) {
        UIView *oldView = m_pan.view;
        if (oldView)
            [oldView removeGestureRecognizer:m_pan];
        [view addGestureRecognizer:m_pan];
    }

    connectWindowGeometryUpdates();
    updateDismissOverlay();
}

void NativeSwipeHandlerItem_iOS::teardownGestureRecognition()
{
    removeDismissOverlay();
    disconnectWindowGeometryUpdates();

    if (!m_attached)
        return;

    UIView *view = m_pan ? m_pan.view : getUIView();
    if (view && m_pan)
        [view removeGestureRecognizer:m_pan];
    if (m_pan) {
        [m_pan release];
        m_pan = nullptr;
    }
    if (m_target) {
        [m_target setHandler:nullptr];
        [m_target release];
        m_target = nullptr;
    }
    m_attached = false;
    m_active = false;
}

void NativeSwipeHandlerItem_iOS::itemChange(ItemChange change, const ItemChangeData &value)
{
    NativeSwipeHandlerItem::itemChange(change, value);
    if (change == ItemSceneChange) {
        if (value.window) {
            QTimer::singleShot(0, this, [this]() {
                teardownGestureRecognition();
                setupGestureRecognition();
            });
        } else {
            teardownGestureRecognition();
        }
    } else if (change == ItemTransformHasChanged) {
        update();
        updateDismissOverlay();
    }
}

void NativeSwipeHandlerItem_iOS::handlePanBegan(qreal translationX, qreal /*velocityX*/)
{
    m_active = true;
    m_startTranslationX = translationX;
    emit swipeStarted();
}

void NativeSwipeHandlerItem_iOS::handlePanChanged(qreal translationX, qreal velocityX)
{
    if (!m_active) return;
    const qreal delta = translationX - m_startTranslationX;
    emit swipeUpdated(delta, velocityX);
}

void NativeSwipeHandlerItem_iOS::handlePanEnded(qreal translationX, qreal velocityX, bool canceled)
{
    if (!m_active) return;
    const qreal delta = translationX - m_startTranslationX;

    m_active = false;
    emit swipeEnded(delta, velocityX, canceled);
}

@implementation NativeSwipePanTarget

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    NativeSwipeHandlerItem_iOS *handler = self.handler;
    if (!handler || !handler->canHandleInput())
        return NO;

    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        if (!handler->hasDismissOverlay())
            return NO;
        const CGPoint loc = [touch locationInView:gestureRecognizer.view];
        return CGRectContainsPoint(gestureRecognizer.view.bounds, loc);
    }

    UIView *view = gestureRecognizer.view;
    if (!view)
        return NO;

    const CGPoint locationInView = [touch locationInView:view];
    const QPointF scenePoint = handler->mapViewPointToScene(locationInView);
    const QPointF localPoint = handler->mapFromScene(scenePoint);
    return handler->contains(localPoint);
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer
{
    NativeSwipeHandlerItem_iOS *handler = self.handler;
    if (!handler || !handler->canHandleInput())
        return;

    UIView *view = recognizer.view;
    CGPoint translation = [recognizer translationInView:view];
    CGPoint velocity = [recognizer velocityInView:view];
    const QPointF translationScene = handler->mapViewDeltaToScene(translation);
    const QPointF velocityScene = handler->mapViewDeltaToScene(velocity);

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            handler->handlePanBegan(translationScene.x(), velocityScene.x());
            break;
        case UIGestureRecognizerStateChanged:
            handler->handlePanChanged(translationScene.x(), velocityScene.x());
            break;
        case UIGestureRecognizerStateEnded:
            handler->handlePanEnded(translationScene.x(), velocityScene.x(), false);
            break;
        case UIGestureRecognizerStateCancelled:
            handler->handlePanEnded(translationScene.x(), velocityScene.x(), true);
            break;
        default:
            break;
    }
}

- (void)handleDismissTap:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;

    NativeSwipeHandlerItem_iOS *handler = self.handler;
    if (!handler)
        return;

    QPointer<NativeSwipeHandlerItem_iOS> weak(handler);
    QMetaObject::invokeMethod(handler, [weak]() {
        if (!weak || !weak->canHandleInput() || !weak->hasDismissOverlay())
            return;
        emit weak->tapToDismissRequested();
    }, Qt::QueuedConnection);
}

@end

void registerNativeSwipeHandlerItemType()
{
    qmlRegisterType<NativeSwipeHandlerItem_iOS>("StatusQ.Controls", 0, 1, "NativeSwipeHandlerItem");
}

#include "NativeSwipeHandlerItem_ios.moc"

#endif // Q_OS_IOS
