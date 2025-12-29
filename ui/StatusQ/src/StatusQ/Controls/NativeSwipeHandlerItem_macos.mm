#include <StatusQ/NativeSwipeHandlerItem.h>

#ifdef Q_OS_MACOS

#import <AppKit/AppKit.h>

#include <QGuiApplication>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>
#include <QtCore/qstring.h>

namespace {
qreal qtScaleFactor()
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
}

class NativeSwipeHandlerItem_macOS;

@interface NativeSwipeGestureDelegate : NSObject <NSGestureRecognizerDelegate>
@property (nonatomic, assign) NativeSwipeHandlerItem_macOS *handler;
@property (nonatomic, strong) NSPanGestureRecognizer *panGesture;
- (void)handlePanGesture:(NSPanGestureRecognizer *)recognizer;
@end

class NativeSwipeHandlerItem_macOS : public NativeSwipeHandlerItem
{
    Q_OBJECT

public:
    explicit NativeSwipeHandlerItem_macOS(QQuickItem *parent = nullptr);
    ~NativeSwipeHandlerItem_macOS() override;

    bool isPointInHandlerBounds(const QPointF &windowPoint) const;
    void handlePanBegan(qreal translationX, qreal velocityX);
    void handlePanChanged(qreal translationX, qreal velocityX);
    void handlePanEnded(qreal translationX, qreal velocityX, bool canceled);

protected:
    void setupGestureRecognition() override;
    void teardownGestureRecognition() override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    NSView *getNSView() const;
    void attachGestureRecognizer();
    void detachGestureRecognizer();

    NativeSwipeGestureDelegate *m_delegate = nullptr;
    bool m_attached = false;

    bool m_active = false;
    qreal m_startTranslationX = 0.0;
};

NativeSwipeHandlerItem_macOS::NativeSwipeHandlerItem_macOS(QQuickItem *parent)
    : NativeSwipeHandlerItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
    QTimer::singleShot(0, this, [this]() { setupGestureRecognition(); });
}

NativeSwipeHandlerItem_macOS::~NativeSwipeHandlerItem_macOS()
{
    teardownGestureRecognition();
}

NSView *NativeSwipeHandlerItem_macOS::getNSView() const
{
    if (!window())
        return nullptr;
    if (QGuiApplication::platformName() == QStringLiteral("offscreen"))
        return nullptr;
    WId winId = window()->winId();
    if (!winId)
        return nullptr;
    id viewId = reinterpret_cast<id>(winId);
    if (![viewId isKindOfClass:[NSView class]])
        return nullptr;
    return reinterpret_cast<NSView *>(viewId);
}

bool NativeSwipeHandlerItem_macOS::isPointInHandlerBounds(const QPointF &windowPoint) const
{
    if (!window() || !isVisible() || !isEnabled())
        return false;
    const QPointF itemPoint = mapFromScene(windowPoint);
    return contains(itemPoint);
}

void NativeSwipeHandlerItem_macOS::setupGestureRecognition()
{
    if (m_attached || !window())
        return;
    attachGestureRecognizer();
}

void NativeSwipeHandlerItem_macOS::teardownGestureRecognition()
{
    detachGestureRecognizer();
}

void NativeSwipeHandlerItem_macOS::attachGestureRecognizer()
{
    NSView *view = getNSView();
    if (!view)
        return;

    m_delegate = [[NativeSwipeGestureDelegate alloc] init];
    m_delegate.handler = this;

    NSPanGestureRecognizer *pan = [[NSPanGestureRecognizer alloc] initWithTarget:m_delegate action:@selector(handlePanGesture:)];
    pan.delegate = m_delegate;
    m_delegate.panGesture = pan;
    [view addGestureRecognizer:pan];
    [pan release];

    m_attached = true;
}

void NativeSwipeHandlerItem_macOS::detachGestureRecognizer()
{
    if (!m_attached)
        return;

    NSView *view = getNSView();
    if (view && m_delegate && m_delegate.panGesture) {
        [view removeGestureRecognizer:m_delegate.panGesture];
        m_delegate.panGesture = nil;
    }
    if (m_delegate) {
        m_delegate.handler = nullptr;
        [m_delegate release];
        m_delegate = nullptr;
    }

    m_attached = false;
    m_active = false;
}

void NativeSwipeHandlerItem_macOS::handlePanBegan(qreal translationX, qreal /*velocityX*/)
{
    m_active = true;
    m_startTranslationX = translationX;
    emit swipeStarted();
}

void NativeSwipeHandlerItem_macOS::handlePanChanged(qreal translationX, qreal velocityX)
{
    if (!m_active) return;
    const qreal delta = translationX - m_startTranslationX;
    emit swipeUpdated(delta, velocityX);
}

void NativeSwipeHandlerItem_macOS::handlePanEnded(qreal translationX, qreal velocityX, bool canceled)
{
    if (!m_active) return;
    const qreal delta = translationX - m_startTranslationX;
    m_active = false;
    emit swipeEnded(delta, velocityX, canceled);
}

void NativeSwipeHandlerItem_macOS::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemSceneChange) {
        if (value.window) QTimer::singleShot(0, this, [this]() { setupGestureRecognition(); });
        else teardownGestureRecognition();
    } else if (change == ItemTransformHasChanged) {
        update();
    }
}

@implementation NativeSwipeGestureDelegate

- (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer
{
    if (!self.handler || !self.handler->window() || !self.handler->isVisible() || !self.handler->isEnabled())
        return NO;
    NSEvent *event = NSApp.currentEvent;
    if (!event) return NO;

    NSView *view = (NSView *)gestureRecognizer.view;
    if (!view) return NO;

    NSPoint locationInView = [event locationInWindow];
    locationInView = [view convertPoint:locationInView fromView:nil];

    const bool viewFlipped = [view isFlipped];
    const CGFloat windowH = view.frame.size.height;
    const qreal sceneY = viewFlipped ? locationInView.y : (windowH - locationInView.y);
    const qreal qtScale = qtScaleFactor();
    QPointF scenePoint(locationInView.x / qtScale, sceneY / qtScale);
    return self.handler->isPointInHandlerBounds(scenePoint);
}

- (void)handlePanGesture:(NSPanGestureRecognizer *)recognizer
{
    if (!self.handler || !self.handler->window() || !self.handler->isVisible() || !self.handler->isEnabled())
        return;

    NSPoint translation = [recognizer translationInView:recognizer.view];
    NSPoint velocity = [recognizer velocityInView:recognizer.view];
    const qreal qtScale = qtScaleFactor();

    switch (recognizer.state) {
        case NSGestureRecognizerStateBegan:
            self.handler->handlePanBegan(translation.x / qtScale, velocity.x / qtScale);
            break;
        case NSGestureRecognizerStateChanged:
            self.handler->handlePanChanged(translation.x / qtScale, velocity.x / qtScale);
            break;
        case NSGestureRecognizerStateEnded:
            self.handler->handlePanEnded(translation.x / qtScale, velocity.x / qtScale, false);
            break;
        case NSGestureRecognizerStateCancelled:
            self.handler->handlePanEnded(translation.x / qtScale, velocity.x / qtScale, true);
            break;
        default:
            break;
    }
}

@end

void registerNativeSwipeHandlerItemType()
{
    qmlRegisterType<NativeSwipeHandlerItem_macOS>("StatusQ.Controls", 0, 1, "NativeSwipeHandlerItem");
}

#include "NativeSwipeHandlerItem_macos.moc"

#endif // Q_OS_MACOS
