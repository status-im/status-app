#include <StatusQ/NativeIndicatorItem.h>

#ifdef Q_OS_MACOS

#import <AppKit/AppKit.h>

#include <QBuffer>
#include <QImage>
#include <QPainter>
#include <QPointer>
#include <QQuickWindow>
#include <QSvgRenderer>
#include <QTimer>
#include <QtCore/qstring.h>

class NativeIndicatorItem_macOS : public NativeIndicatorItem
{
    Q_OBJECT

public:
    explicit NativeIndicatorItem_macOS(QQuickItem *parent = nullptr);
    ~NativeIndicatorItem_macOS() override;

protected:
    void syncToNative() override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    void updatePolish() override;

private:
    NSView *getNSView() const;
    void ensureViews();
    void destroyViews();
    void updateImageIfNeeded();
    void updateFramesAndVisibility();

    void attachParentWatchers();
    void detachParentWatchers();

    QPointer<QQuickItem> m_parentItem;
    QVector<QMetaObject::Connection> m_parentConnections;

    NSView *m_containerView = nullptr;
    NSImageView *m_imageView = nullptr;

    QUrl m_lastSource;
    QSize m_lastPixelSize;
};

NativeIndicatorItem_macOS::NativeIndicatorItem_macOS(QQuickItem *parent)
    : NativeIndicatorItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
    connect(this, &NativeIndicatorItem::sourceChanged, this, [this]() { polish(); });
    connect(this, &QQuickItem::visibleChanged, this, [this]() { polish(); });
    connect(this, &QQuickItem::enabledChanged, this, [this]() { polish(); });
    QTimer::singleShot(0, this, [this]() { polish(); });
}

NativeIndicatorItem_macOS::~NativeIndicatorItem_macOS()
{
    detachParentWatchers();
    destroyViews();
}

NSView *NativeIndicatorItem_macOS::getNSView() const
{
    if (!window())
        return nullptr;
    return reinterpret_cast<NSView *>(window()->winId());
}

void NativeIndicatorItem_macOS::ensureViews()
{
    if (m_containerView && m_imageView)
        return;

    NSView *root = getNSView();
    if (!root)
        return;

    m_containerView = [[NSView alloc] initWithFrame:NSZeroRect];
    m_containerView.wantsLayer = YES;
    m_containerView.layer.masksToBounds = NO;
    m_containerView.hidden = YES;

    m_imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    m_imageView.imageScaling = NSImageScaleAxesIndependently;
    m_imageView.hidden = YES;

    [m_containerView addSubview:m_imageView];
    [root addSubview:m_containerView];
}

void NativeIndicatorItem_macOS::destroyViews()
{
    if (m_imageView) {
        [m_imageView removeFromSuperview];
        [m_imageView release];
        m_imageView = nullptr;
    }
    if (m_containerView) {
        [m_containerView removeFromSuperview];
        [m_containerView release];
        m_containerView = nullptr;
    }
}

void NativeIndicatorItem_macOS::attachParentWatchers()
{
    auto p = parentItem();
    if (m_parentItem == p && !m_parentConnections.isEmpty())
        return;


    detachParentWatchers();
    m_parentItem = p;
    if (!m_parentItem)
        return;
    m_parentConnections.append(connect(m_parentItem, &QQuickItem::widthChanged, this, [this]() { polish(); }));
    m_parentConnections.append(connect(m_parentItem, &QQuickItem::heightChanged, this, [this]() { polish(); }));
    m_parentConnections.append(connect(m_parentItem, &QQuickItem::clipChanged, this, [this]() { polish(); }));
    m_parentConnections.append(connect(m_parentItem, &QQuickItem::visibleChanged, this, [this]() { polish(); }));
    m_parentConnections.append(connect(m_parentItem, &QQuickItem::enabledChanged, this, [this]() { polish(); }));
}

void NativeIndicatorItem_macOS::detachParentWatchers()
{
    for (const auto &c : std::as_const(m_parentConnections))
        disconnect(c);
    m_parentConnections.clear();
    m_parentItem.clear();
}

void NativeIndicatorItem_macOS::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemSceneChange) {
        if (value.window) QTimer::singleShot(0, this, [this]() { polish(); });
        else { detachParentWatchers(); destroyViews(); }
    } else if (change == ItemParentHasChanged) {
        attachParentWatchers();
        polish();
    } else if (change == ItemTransformHasChanged) {
        polish();
    }
}

void NativeIndicatorItem_macOS::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    Q_UNUSED(oldGeometry)
    polish();
}

void NativeIndicatorItem_macOS::updatePolish()
{
    QQuickItem::updatePolish();
    syncToNative();
}

void NativeIndicatorItem_macOS::syncToNative()
{
    if (!window() || !isVisible() || !isEnabled()) {
        if (m_containerView) m_containerView.hidden = YES;
        if (m_imageView) m_imageView.hidden = YES;
        return;
    }

    ensureViews();
    attachParentWatchers();
    updateImageIfNeeded();
    updateFramesAndVisibility();
}

void NativeIndicatorItem_macOS::updateImageIfNeeded()
{
    if (!m_imageView)
        return;

    const QUrl src = source();
    if (src.isEmpty())
        return;

    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    const QSize pixelSize(qMax(1, int(width() * dpr)), qMax(1, int(height() * dpr)));
    if (src == m_lastSource && pixelSize == m_lastPixelSize && m_imageView.image != nil)
        return;

    QString path;
    if (src.isLocalFile()) {
        path = src.toLocalFile();
    } else if (src.scheme() == QLatin1String("qrc")) {
        path = QLatin1Char(':') + src.path();
    } else {
        path = src.toString();
    }

    QSvgRenderer renderer(path);
    if (!renderer.isValid())
        return;

    QImage img(pixelSize, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::SmoothPixmapTransform, true);
    renderer.render(&p, QRectF(0, 0, pixelSize.width(), pixelSize.height()));
    p.end();

    QByteArray png;
    QBuffer buf(&png);
    buf.open(QIODevice::WriteOnly);
    img.save(&buf, "PNG");

    NSData *data = [NSData dataWithBytes:png.constData() length:png.size()];
    NSImage *nsImg = [[NSImage alloc] initWithData:data];
    if (nsImg) {
        [m_imageView setImage:nsImg];
        [nsImg release];
        m_lastSource = src;
        m_lastPixelSize = pixelSize;
    }
}

void NativeIndicatorItem_macOS::updateFramesAndVisibility()
{
    if (!m_containerView || !m_imageView || !window())
        return;

    QQuickItem *pItem = parentItem();
    const bool parentClips = pItem ? pItem->clip() : false;

    qreal qtScale = 1.0;
    const QString qtScaleEnv = qEnvironmentVariable("QT_SCALE_FACTOR");
    if (!qtScaleEnv.isEmpty()) {
        bool ok = false;
        const qreal parsed = qtScaleEnv.toDouble(&ok);
        if (ok && parsed > 0.0)
            qtScale = parsed;
    }

    QPointF parentScenePos(0, 0);
    QSizeF parentSize(0, 0);
    if (pItem) {
        parentScenePos = pItem->mapToScene(QPointF(0, 0));
        parentSize = QSizeF(pItem->width(), pItem->height());
    } else {
        parentSize = QSizeF(window()->width(), window()->height());
    }

    QPointF indicatorScenePos = mapToScene(QPointF(0, 0));
    const QPointF parentNativePos(parentScenePos.x() * qtScale, parentScenePos.y() * qtScale);
    const QSizeF parentNativeSize(parentSize.width() * qtScale, parentSize.height() * qtScale);
    const QPointF indicatorNativePos(indicatorScenePos.x() * qtScale, indicatorScenePos.y() * qtScale);
    const QSizeF indicatorNativeSize(width() * qtScale, height() * qtScale);

    const qreal localX = indicatorNativePos.x() - parentNativePos.x();
    const qreal localY = indicatorNativePos.y() - parentNativePos.y();

    NSView *root = getNSView();
    if (!root)
        return;

    const CGFloat rootH = root.frame.size.height;
    const CGFloat containerX = parentNativePos.x();
    const CGFloat containerYTop = parentNativePos.y();
    const CGFloat containerYBottom = rootH - parentNativePos.y() - parentNativeSize.height();
    const auto withinBounds = [](CGFloat y, CGFloat h, CGFloat maxH) {
        return y >= -1.0 && (y + h) <= (maxH + 1.0);
    };
    const bool topOk = withinBounds(containerYTop, parentNativeSize.height(), rootH);
    const bool bottomOk = withinBounds(containerYBottom, parentNativeSize.height(), rootH);
    const bool useTop = topOk && !bottomOk
        ? true
        : (!topOk && bottomOk ? false : [root isFlipped]);
    const CGFloat containerY = useTop ? containerYTop : containerYBottom;
    const CGFloat containerW = parentNativeSize.width();
    const CGFloat containerH = parentNativeSize.height();

    m_containerView.frame = NSMakeRect(containerX, containerY, containerW, containerH);
    m_containerView.layer.masksToBounds = parentClips ? YES : NO;

    const CGFloat imgX = localX;
    const CGFloat imgY = useTop
        ? localY
        : containerH - localY - indicatorNativeSize.height();
    m_imageView.frame = NSMakeRect(imgX, imgY, indicatorNativeSize.width(), indicatorNativeSize.height());

    const bool show = isVisible() && isEnabled();
    m_containerView.hidden = !show;
    m_imageView.hidden = !show;
}

void registerNativeIndicatorItemType()
{
    qmlRegisterType<NativeIndicatorItem_macOS>("StatusQ.Controls", 0, 1, "NativeIndicatorItem");
}

#include "NativeIndicatorItem_macos.moc"

#endif // Q_OS_MACOS
