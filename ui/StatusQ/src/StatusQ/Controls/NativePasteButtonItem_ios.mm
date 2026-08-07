#include <StatusQ/NativePasteButtonItem.h>

#ifdef Q_OS_IOS

#import <UIKit/UIKit.h>

#include <QQuickWindow>
#include <QTimer>

class NativePasteButtonItem_iOS;

// Receives the item providers the system hands over when the paste control is
// tapped. Nothing here reads UIPasteboard.
API_AVAILABLE(ios(16.0))
@interface StatusQPasteTarget : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, assign) NativePasteButtonItem_iOS* owner;
@property (nonatomic, assign) UIControl* trackedControl;
- (void)cancelOnDrag:(UIPanGestureRecognizer*)recognizer;
@end

class NativePasteButtonItem_iOS : public NativePasteButtonItem
{
    Q_OBJECT

public:
    explicit NativePasteButtonItem_iOS(QQuickItem* parent = nullptr);
    ~NativePasteButtonItem_iOS() override;

    void deliverPastedText(const QString& text) { emit pasted(text); }

protected:
    void syncToNative() override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    void updatePolish() override;

private:
    UIView* getUIView() const;
    void ensureViews();
    void destroyViews();
    void applyConfiguration();
    void updateFrames();

    bool isOccluded() const;
    qreal effectiveOpacity() const;
    qreal scaleFactor() const;

    // Clips the control to the item's visible viewport. A native view is
    // composited above the whole Qt scene, so without this it draws over
    // anything Qt paints later - scrolled-away content, headers, popups.
    UIView* m_clipView = nullptr;
    StatusQPasteTarget* m_targetView = nullptr;
    UIControl* m_pasteControl = nullptr;
    bool m_configDirty = false;
    QMetaObject::Connection m_frameConnection;
    // Last values pushed to UIKit, so the per-frame sync is a no-op when idle.
    CGRect m_lastClipFrame = CGRectZero;
    CGRect m_lastTargetFrame = CGRectZero;
    bool m_lastShow = false;
};

@implementation StatusQPasteTarget

// Dragging off the control and releasing makes UIKit vend the pasteboard,
// which shows the "Allow Paste?" prompt even though no paste happens.
// Cancelling the control's touch tracking as soon as the finger moves is an
// attempt to stop it reaching that evaluation.
- (void)cancelOnDrag:(UIPanGestureRecognizer*)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan
        && recognizer.state != UIGestureRecognizerStateChanged)
        return;
    if (self.trackedControl)
        [self.trackedControl cancelTrackingWithEvent:nil];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)g
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)other
{
    return YES;
}

- (void)pasteItemProviders:(NSArray<NSItemProvider*>*)itemProviders
{
    for (NSItemProvider* provider in itemProviders) {
        if (![provider canLoadObjectOfClass:[NSString class]])
            continue;

        // Capture self, not owner: the block retains this view, and owner is
        // read on the main thread inside the block. Capturing owner up front
        // would snapshot a raw C++ pointer that destroyViews() cannot clear,
        // so a control torn down while the provider loads (closing the modal
        // it lives in) would deliver into freed memory.
        [provider loadObjectOfClass:[NSString class]
                  completionHandler:^(id<NSItemProviderReading> object, NSError* error) {
            if (error || ![object isKindOfClass:[NSString class]])
                return;
            const QString text = QString::fromNSString((NSString*)object);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.owner)
                    self.owner->deliverPastedText(text);
            });
        }];
        break;
    }
}

@end

NativePasteButtonItem_iOS::NativePasteButtonItem_iOS(QQuickItem* parent)
    : NativePasteButtonItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
    auto markDirty = [this]() { m_configDirty = true; polish(); };
    connect(this, &NativePasteButtonItem::displayModeChanged, this, markDirty);
    connect(this, &NativePasteButtonItem::foregroundColorChanged, this, markDirty);
    connect(this, &NativePasteButtonItem::backgroundColorChanged, this, markDirty);
    connect(this, &NativePasteButtonItem::cornerStyleChanged, this, markDirty);
    connect(this, &QQuickItem::visibleChanged, this, [this]() { polish(); });
    connect(this, &QQuickItem::enabledChanged, this, [this]() { polish(); });
    QTimer::singleShot(0, this, [this]() { polish(); });
}

NativePasteButtonItem_iOS::~NativePasteButtonItem_iOS()
{
    disconnect(m_frameConnection);
    destroyViews();
}

UIView* NativePasteButtonItem_iOS::getUIView() const
{
    if (!window())
        return nullptr;
    return reinterpret_cast<UIView*>(window()->winId());
}

void NativePasteButtonItem_iOS::ensureViews()
{
    if (m_targetView)
        return;

    UIView* root = getUIView();
    if (!root)
        return;

    if (@available(iOS 16.0, *)) {
        m_targetView = [[StatusQPasteTarget alloc] initWithFrame:CGRectZero];
        m_targetView.owner = this;
        m_targetView.backgroundColor = UIColor.clearColor;
        // Declaring what we accept lets UIKit decide the control's enabled state
        // from the pasteboard's type identifiers alone. Implementing
        // canPasteItemProviders: instead makes UIKit materialise the item
        // providers, and that read triggers the "Allow Paste?" prompt (#21438).
        m_targetView.pasteConfiguration =
            [[[UIPasteConfiguration alloc] initWithTypeIdentifiersForAcceptingClass:[NSString class]] autorelease];
        m_clipView = [[UIView alloc] initWithFrame:CGRectZero];
        m_clipView.backgroundColor = UIColor.clearColor;
        m_clipView.clipsToBounds = YES;
        [m_clipView addSubview:m_targetView];
        [root addSubview:m_clipView];
        applyConfiguration();
    }
}

void NativePasteButtonItem_iOS::destroyViews()
{
    if (m_pasteControl) {
        [m_pasteControl removeFromSuperview];
        [m_pasteControl release];
        m_pasteControl = nullptr;
    }
    if (m_targetView) {
        m_targetView.owner = nullptr;
        m_targetView.trackedControl = nullptr;
        [m_targetView removeFromSuperview];
        [m_targetView release];
        m_targetView = nullptr;
    }
    if (m_clipView) {
        [m_clipView removeFromSuperview];
        [m_clipView release];
        m_clipView = nullptr;
    }
    m_lastShow = false;
    m_lastClipFrame = CGRectZero;
    m_lastTargetFrame = CGRectZero;
}

static UIColor* toUIColor(const QColor& color)
{
    if (!color.isValid())
        return nil;
    return [UIColor colorWithRed:color.redF()
                           green:color.greenF()
                            blue:color.blueF()
                           alpha:color.alphaF()];
}

// UIPasteControl only takes its configuration at construction, so any style
// change means building a new control.
void NativePasteButtonItem_iOS::applyConfiguration()
{
    if (!m_targetView)
        return;

    if (@available(iOS 16.0, *)) {
        UIPasteControlConfiguration* config = [[UIPasteControlConfiguration alloc] init];

        switch (displayMode()) {
        case IconOnly:  config.displayMode = UIPasteControlDisplayModeIconOnly; break;
        case LabelOnly: config.displayMode = UIPasteControlDisplayModeLabelOnly; break;
        default:        config.displayMode = UIPasteControlDisplayModeIconAndLabel; break;
        }

        if (UIColor* fg = toUIColor(foregroundColor()))
            config.baseForegroundColor = fg;
        if (UIColor* bg = toUIColor(backgroundColor()))
            config.baseBackgroundColor = bg;

        switch (cornerStyle()) {
        case Dynamic: config.cornerStyle = UIButtonConfigurationCornerStyleDynamic; break;
        case Small:   config.cornerStyle = UIButtonConfigurationCornerStyleSmall; break;
        case Medium:  config.cornerStyle = UIButtonConfigurationCornerStyleMedium; break;
        case Large:   config.cornerStyle = UIButtonConfigurationCornerStyleLarge; break;
        case Capsule: config.cornerStyle = UIButtonConfigurationCornerStyleCapsule; break;
        default:      config.cornerStyle = UIButtonConfigurationCornerStyleFixed; break;
        }

        UIPasteControl* control = [[UIPasteControl alloc] initWithConfiguration:config];
        control.target = m_targetView;

        [m_pasteControl removeFromSuperview];
        [m_pasteControl release];
        m_pasteControl = control;
        [m_targetView addSubview:m_pasteControl];
        m_targetView.trackedControl = m_pasteControl;
        m_lastTargetFrame = CGRectZero;

        UIPanGestureRecognizer* pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:m_targetView
                                                    action:@selector(cancelOnDrag:)];
        pan.delegate = m_targetView;
        pan.cancelsTouchesInView = NO;
        [m_pasteControl addGestureRecognizer:pan];
        [pan release];

        [config release];
    }
}

void NativePasteButtonItem_iOS::itemChange(ItemChange change, const ItemChangeData& value)
{
    NativePasteButtonItem::itemChange(change, value);
    if (change == ItemSceneChange) {
        disconnect(m_frameConnection);
        if (value.window) {
            // Popups opening, list scrolling and ancestor visibility changes do
            // not all reach us as geometry changes, so re-evaluate every frame.
            // NOTE: sync directly - polish() calls QQuickWindow::maybeUpdate(),
            // which requests another frame, so polishing from a per-frame signal
            // keeps the window rendering forever and never lets it idle.
            m_frameConnection = connect(value.window, &QQuickWindow::afterAnimating,
                                        this, [this]() { syncToNative(); });
            QTimer::singleShot(0, this, [this]() { polish(); });
        } else {
            destroyViews();
        }
    } else if (change == ItemParentHasChanged || change == ItemTransformHasChanged) {
        polish();
    }
}

void NativePasteButtonItem_iOS::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    NativePasteButtonItem::geometryChange(newGeometry, oldGeometry);
    Q_UNUSED(oldGeometry)
    polish();
}

void NativePasteButtonItem_iOS::updatePolish()
{
    QQuickItem::updatePolish();
    syncToNative();
}

void NativePasteButtonItem_iOS::syncToNative()
{
    if (!window() || !isVisible()) {
        if (m_clipView && m_lastShow) {
            m_clipView.hidden = YES;
            m_clipView.userInteractionEnabled = NO;
            m_lastShow = false;
        }
        return;
    }

    ensureViews();
    if (m_configDirty) {
        m_configDirty = false;
        applyConfiguration();
    }
    updateFrames();
}


// Qt logical coordinates -> UIKit points. Both are "points" on iOS, so the
// factor is 1 unless Qt has been told to scale on top of that. The window's
// devicePixelRatio is the hardware scale times any such extra scaling, and the
// view's contentScaleFactor is the hardware scale alone, so their ratio is
// exactly the extra factor - without having to know how Qt was asked for it.
qreal NativePasteButtonItem_iOS::scaleFactor() const
{
    UIView* view = getUIView();
    if (!view || !window())
        return 1.0;

    const qreal hwScale = view.contentScaleFactor;
    if (qFuzzyIsNull(hwScale))
        return 1.0;

    return window()->devicePixelRatio() / hwScale;
}

qreal NativePasteButtonItem_iOS::effectiveOpacity() const
{
    qreal o = opacity();
    for (const QQuickItem* p = parentItem(); p; p = p->parentItem())
        o *= p->opacity();
    return o;
}

// True when a Qt Quick popup is open above us. A native view always composites
// above the Qt scene, so it would otherwise float over modals and their dim
// overlay. If the control itself lives inside the popup, it is not occluded.
bool NativePasteButtonItem_iOS::isOccluded() const
{
    if (!window() || !window()->contentItem())
        return false;

    QQuickItem* overlay = nullptr;
    const auto topLevel = window()->contentItem()->childItems();
    for (QQuickItem* child : topLevel) {
        if (QString::fromLatin1(child->metaObject()->className())
                .startsWith(QLatin1String("QQuickOverlay"))) {
            overlay = child;
            break;
        }
    }
    if (!overlay)
        return false;

    // The overlay child that contains us, if we live inside a popup ourselves.
    const auto overlayChildren = overlay->childItems();
    QQuickItem* ownRoot = nullptr;
    for (QQuickItem* p = const_cast<NativePasteButtonItem_iOS*>(this); p; p = p->parentItem()) {
        if (p->parentItem() == overlay) {
            ownRoot = p;
            break;
        }
    }

    const int ownIndex = ownRoot ? overlayChildren.indexOf(ownRoot) : -1;
    const qreal ownZ = ownRoot ? ownRoot->z() : 0.0;

    // Occluded by anything stacked above us: any visible popup when we are not
    // in a popup at all, or one painted later than ours when we are. Qt paints
    // overlay children by z, then by insertion order.
    for (int i = 0; i < overlayChildren.size(); ++i) {
        QQuickItem* child = overlayChildren.at(i);
        if (child == ownRoot || !child->isVisible())
            continue;
        if (child->width() <= 0 || child->height() <= 0)
            continue;
        if (!ownRoot)
            return true;
        if (child->z() > ownZ || (qFuzzyCompare(child->z(), ownZ) && i > ownIndex))
            return true;
    }
    return false;
}

void NativePasteButtonItem_iOS::updateFrames()
{
    if (!m_targetView || !window())
        return;

    const qreal qtScale = scaleFactor();

    // clipRect() is the part of the item still inside every clipping ancestor
    // (ItemObservesViewport is set), so a control scrolled out of a list or
    // under a header shrinks away instead of floating over them.
    const QRectF visible = clipRect();
    const bool show = isVisible() && isEnabled() && !visible.isEmpty()
                      && effectiveOpacity() > 0.01 && !isOccluded();

    if (!show) {
        if (m_lastShow) {
            m_clipView.hidden = YES;
            m_clipView.userInteractionEnabled = NO;
            m_lastShow = false;
        }
        return;
    }

    const QPointF visScenePos = mapToScene(visible.topLeft());
    const CGRect clipFrame = CGRectMake(visScenePos.x() * qtScale, visScenePos.y() * qtScale,
                                        visible.width() * qtScale, visible.height() * qtScale);
    // Position the control at the item's origin, expressed inside the clip view.
    const CGRect targetFrame = CGRectMake(-visible.x() * qtScale, -visible.y() * qtScale,
                                          width() * qtScale, height() * qtScale);

    if (!m_lastShow) {
        m_clipView.hidden = NO;
        m_clipView.userInteractionEnabled = YES;
        m_targetView.hidden = NO;
        m_targetView.userInteractionEnabled = YES;
        m_lastShow = true;
    }
    if (!CGRectEqualToRect(clipFrame, m_lastClipFrame)) {
        m_clipView.frame = clipFrame;
        m_lastClipFrame = clipFrame;
    }
    if (!CGRectEqualToRect(targetFrame, m_lastTargetFrame)) {
        m_targetView.frame = targetFrame;
        m_pasteControl.frame = m_targetView.bounds;
        m_lastTargetFrame = targetFrame;
    }
}

void registerNativePasteButtonItemType()
{
    qmlRegisterType<NativePasteButtonItem_iOS>("StatusQ.Controls", 0, 1, "NativePasteButtonItem");
}

#include "NativePasteButtonItem_ios.moc"

#endif // Q_OS_IOS
