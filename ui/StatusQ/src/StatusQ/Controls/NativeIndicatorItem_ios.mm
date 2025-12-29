#include <StatusQ/NativeIndicatorItem.h>

#ifdef Q_OS_IOS

#import <UIKit/UIKit.h>

#include <QBuffer>
#include <QImage>
#include <QPainter>
#include <QPointer>
#include <QQuickWindow>
#include <QSvgRenderer>
#include <QTimer>
#include <QtCore/qstring.h>

class NativeIndicatorItem_iOS : public NativeIndicatorItem
{
    Q_OBJECT

public:
    explicit NativeIndicatorItem_iOS(QQuickItem *parent = nullptr);
    ~NativeIndicatorItem_iOS() override;

protected:
    void syncToNative() override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    void updatePolish() override;

private:
    UIView *getUIView() const;
    void ensureViews();
    void destroyViews();
    void attachParentWatchers();
    void detachParentWatchers();
    void updateImageIfNeeded();
    void updateFramesAndVisibility();

    QPointer<QQuickItem> m_parentItem;
    QVector<QMetaObject::Connection> m_parentConnections;

    UIView *m_containerView = nullptr;
    UIImageView *m_imageView = nullptr;

    QUrl m_lastSource;
    QSize m_lastPixelSize;
};

NativeIndicatorItem_iOS::NativeIndicatorItem_iOS(QQuickItem *parent)
    : NativeIndicatorItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
    connect(this, &NativeIndicatorItem::sourceChanged, this, [this]() { polish(); });
    connect(this, &QQuickItem::visibleChanged, this, [this]() { polish(); });
    connect(this, &QQuickItem::enabledChanged, this, [this]() { polish(); });
    QTimer::singleShot(0, this, [this]() { polish(); });
}

NativeIndicatorItem_iOS::~NativeIndicatorItem_iOS()
{
    detachParentWatchers();
    destroyViews();
}

UIView *NativeIndicatorItem_iOS::getUIView() const
{
    if (!window())
        return nullptr;
    return reinterpret_cast<UIView *>(window()->winId());
}

void NativeIndicatorItem_iOS::ensureViews()
{
    if (m_containerView && m_imageView)
        return;

    UIView *root = getUIView();
    if (!root)
        return;

    m_containerView = [[UIView alloc] initWithFrame:CGRectZero];
    m_containerView.userInteractionEnabled = NO;
    m_containerView.hidden = YES;

    m_imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    m_imageView.contentMode = UIViewContentModeScaleToFill;
    m_imageView.hidden = YES;

    [m_containerView addSubview:m_imageView];
    [root addSubview:m_containerView];

    // QtWebView (WKWebView) is a native UIView inserted into the same hierarchy.
    // Ensure our overlay stays above it.
    [root bringSubviewToFront:m_containerView];
}

void NativeIndicatorItem_iOS::destroyViews()
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

void NativeIndicatorItem_iOS::attachParentWatchers()
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

void NativeIndicatorItem_iOS::detachParentWatchers()
{
    for (const auto &c : std::as_const(m_parentConnections))
        disconnect(c);
    m_parentConnections.clear();
    m_parentItem.clear();
}

void NativeIndicatorItem_iOS::itemChange(ItemChange change, const ItemChangeData &value)
{
    NativeIndicatorItem::itemChange(change, value);
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

void NativeIndicatorItem_iOS::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    NativeIndicatorItem::geometryChange(newGeometry, oldGeometry);
    Q_UNUSED(oldGeometry)
    polish();
}

void NativeIndicatorItem_iOS::updatePolish()
{
    QQuickItem::updatePolish();
    syncToNative();
}

void NativeIndicatorItem_iOS::syncToNative()
{
    if (!window() || !isVisible() || !isEnabled()) {
        if (m_containerView) m_containerView.hidden = YES;
        if (m_imageView) m_imageView.hidden = YES;
        return;
    }

    ensureViews();
    if (m_containerView) {
        UIView *root = getUIView();
        if (root)
            [root bringSubviewToFront:m_containerView];
    }
    attachParentWatchers();
    updateImageIfNeeded();
    updateFramesAndVisibility();
}

void NativeIndicatorItem_iOS::updateImageIfNeeded()
{
    if (!m_imageView || !window())
        return;

    const QUrl src = source();
    if (src.isEmpty())
        return;

    const qreal dpr = window()->effectiveDevicePixelRatio();
    const QSize pixelSize(qMax(1, int(width() * dpr)), qMax(1, int(height() * dpr)));
    if (src == m_lastSource && pixelSize == m_lastPixelSize && m_imageView.image != nil)
        return;

    QString path;
    if (src.isLocalFile()) path = src.toLocalFile();
    else if (src.scheme() == QLatin1String("qrc")) path = QLatin1Char(':') + src.path();
    else path = src.toString();

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
    UIImage *uiImg = [UIImage imageWithData:data scale:1.0];
    if (uiImg) {
        m_imageView.image = uiImg;
        m_lastSource = src;
        m_lastPixelSize = pixelSize;
    }
}

void NativeIndicatorItem_iOS::updateFramesAndVisibility()
{
    if (!m_containerView || !m_imageView || !window())
        return;

    QQuickItem *pItem = parentItem();
    const bool clip = pItem ? pItem->clip() : false;

    QPointF parentScenePos(0, 0);
    QSizeF parentSize(window()->width(), window()->height());
    if (pItem) {
        parentScenePos = pItem->mapToScene(QPointF(0, 0));
        parentSize = QSizeF(pItem->width(), pItem->height());
    }

    QPointF indicatorScenePos = mapToScene(QPointF(0, 0));

    qreal qtScale = 1.0;
    const QString qtScaleEnv = qEnvironmentVariable("QT_SCALE_FACTOR");
    if (!qtScaleEnv.isEmpty()) {
        bool ok = false;
        const qreal parsed = qtScaleEnv.toDouble(&ok);
        if (ok && parsed > 0.0)
            qtScale = parsed;
    }

    const QPointF parentNativePos(parentScenePos.x() * qtScale, parentScenePos.y() * qtScale);
    const QSizeF parentNativeSize(parentSize.width() * qtScale, parentSize.height() * qtScale);
    const QPointF indicatorNativePos(indicatorScenePos.x() * qtScale, indicatorScenePos.y() * qtScale);
    const QSizeF indicatorNativeSize(width() * qtScale, height() * qtScale);

    const qreal localX = indicatorNativePos.x() - parentNativePos.x();
    const qreal localY = indicatorNativePos.y() - parentNativePos.y();

    m_containerView.frame = CGRectMake(parentNativePos.x(), parentNativePos.y(), parentNativeSize.width(), parentNativeSize.height());
    m_containerView.clipsToBounds = clip ? YES : NO;
    m_imageView.frame = CGRectMake(localX, localY, indicatorNativeSize.width(), indicatorNativeSize.height());


    const bool show = isVisible() && isEnabled() && (!pItem || pItem->isVisible());
    m_containerView.hidden = !show;
    m_imageView.hidden = !show;

    // Keep it on top even if native views (e.g. WKWebView) are re-attached later.
    UIView *root = getUIView();
    if (root)
        [root bringSubviewToFront:m_containerView];
}

void registerNativeIndicatorItemType()
{
    qmlRegisterType<NativeIndicatorItem_iOS>("StatusQ.Controls", 0, 1, "NativeIndicatorItem");
}

#include "NativeIndicatorItem_ios.moc"

#endif // Q_OS_IOS
