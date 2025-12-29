#include <StatusQ/NativeSwipeHandlerItem.h>

#ifdef Q_OS_IOS

#import <UIKit/UIKit.h>

#include <QQuickWindow>
#include <QTimer>

class NativeSwipeHandlerItem_iOS;

@interface NativeSwipePanTarget : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, assign) NativeSwipeHandlerItem_iOS *handler;
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
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

protected:
    void setupGestureRecognition() override;
    void teardownGestureRecognition() override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    UIView *getUIView() const;

    UIPanGestureRecognizer *m_pan = nullptr;
    NativeSwipePanTarget *m_target = nullptr;
    bool m_attached = false;

    bool m_active = false;
    qreal m_startTranslationX = 0.0;
};

NativeSwipeHandlerItem_iOS::NativeSwipeHandlerItem_iOS(QQuickItem *parent)
    : NativeSwipeHandlerItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
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

QPointF NativeSwipeHandlerItem_iOS::mapViewPointToScene(const CGPoint &point) const
{
    if (!window())
        return QPointF(point.x, point.y);
    qreal qtScale = 1.0;
    const QString qtScaleEnv = qEnvironmentVariable("QT_SCALE_FACTOR");
    if (!qtScaleEnv.isEmpty()) {
        bool ok = false;
        const qreal parsed = qtScaleEnv.toDouble(&ok);
        if (ok && parsed > 0.0)
            qtScale = parsed;
    }
    return QPointF(point.x / qtScale, point.y / qtScale);
}

QPointF NativeSwipeHandlerItem_iOS::mapViewDeltaToScene(const CGPoint &delta) const
{
    if (!window())
        return QPointF(delta.x, delta.y);
    qreal qtScale = 1.0;
    const QString qtScaleEnv = qEnvironmentVariable("QT_SCALE_FACTOR");
    if (!qtScaleEnv.isEmpty()) {
        bool ok = false;
        const qreal parsed = qtScaleEnv.toDouble(&ok);
        if (ok && parsed > 0.0)
            qtScale = parsed;
    }
    return QPointF(delta.x / qtScale, delta.y / qtScale);
}

void NativeSwipeHandlerItem_iOS::setupGestureRecognition()
{
    if (m_attached) return;
    UIView *view = getUIView();
    if (!view) return;

    m_target = [[NativeSwipePanTarget alloc] init];
    [m_target setHandler:this];

    m_pan = [[UIPanGestureRecognizer alloc] initWithTarget:m_target action:@selector(handlePan:)];
    m_pan.maximumNumberOfTouches = 1;
    m_pan.delegate = m_target;
    [view addGestureRecognizer:m_pan];

    m_attached = true;
}

void NativeSwipeHandlerItem_iOS::teardownGestureRecognition()
{
    if (!m_attached) return;
    UIView *view = getUIView();
    if (view && m_pan) {
        [view removeGestureRecognizer:m_pan];
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
        if (value.window) QTimer::singleShot(0, this, [this]() { setupGestureRecognition(); });
        else teardownGestureRecognition();
    } else if (change == ItemTransformHasChanged) {
        update();
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
    if (!handler || !handler->window() || !handler->isVisible() || !handler->isEnabled())
        return NO;

    UIView *view = gestureRecognizer.view;
    if (!view) return NO;

    CGPoint locationInView = [touch locationInView:view];
    QPointF scenePoint = handler->mapViewPointToScene(locationInView);
    QPointF localPoint = handler->mapFromScene(scenePoint);
    return handler->contains(localPoint);
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer
{
    NativeSwipeHandlerItem_iOS *handler = self.handler;
    if (!handler || !handler->window() || !handler->isVisible() || !handler->isEnabled())
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

@end

void registerNativeSwipeHandlerItemType()
{
    qmlRegisterType<NativeSwipeHandlerItem_iOS>("StatusQ.Controls", 0, 1, "NativeSwipeHandlerItem");
}

#include "NativeSwipeHandlerItem_ios.moc"

#endif // Q_OS_IOS
