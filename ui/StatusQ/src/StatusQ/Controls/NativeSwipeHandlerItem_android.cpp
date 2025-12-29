#include <StatusQ/NativeSwipeHandlerItem.h>

#ifdef Q_OS_ANDROID

#include <QJniEnvironment>
#include <QJniObject>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>

class NativeSwipeHandlerItem_Android : public NativeSwipeHandlerItem
{
    Q_OBJECT

public:
    explicit NativeSwipeHandlerItem_Android(QQuickItem *parent = nullptr);
    ~NativeSwipeHandlerItem_Android() override;

protected:
    void setupGestureRecognition() override;
    void teardownGestureRecognition() override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    void updatePolish() override;

private:
    void initializeJNI();
    void cleanupJNI();
    void updateOverlayBounds();
    static void onSwipeBegan(JNIEnv *, jobject, jlong ptr, jfloat velocityX);
    static void onSwipeChanged(JNIEnv *, jobject, jlong ptr, jfloat deltaX, jfloat velocityX);
    static void onSwipeEnded(JNIEnv *, jobject, jlong ptr, jfloat deltaX, jfloat velocityX, jboolean canceled);

    QJniObject m_javaHelper;
    bool m_jniInitialized = false;

    QVector<QMetaObject::Connection> m_changeConnections;
    QVector<QMetaObject::Connection> m_windowConnections;
    bool m_active = false;
};

NativeSwipeHandlerItem_Android::NativeSwipeHandlerItem_Android(QQuickItem *parent)
    : NativeSwipeHandlerItem(parent)
{
    setFlag(QQuickItem::ItemObservesViewport, true);
    m_changeConnections.append(connect(this, &QQuickItem::widthChanged, this, [this]() { polish(); }));
    m_changeConnections.append(connect(this, &QQuickItem::heightChanged, this, [this]() { polish(); }));
    m_changeConnections.append(connect(this, &QQuickItem::visibleChanged, this, [this]() { polish(); }));
    m_changeConnections.append(connect(this, &QQuickItem::enabledChanged, this, [this]() { polish(); }));
    QTimer::singleShot(0, this, [this]() { setupGestureRecognition(); });
}

NativeSwipeHandlerItem_Android::~NativeSwipeHandlerItem_Android()
{
    teardownGestureRecognition();
}

void NativeSwipeHandlerItem_Android::initializeJNI()
{
    if (m_jniInitialized)
        return;

    JNINativeMethod methods[] = {
        {"nativeOnSwipeBegan", "(JF)V", reinterpret_cast<void *>(onSwipeBegan)},
        {"nativeOnSwipeChanged", "(JFF)V", reinterpret_cast<void *>(onSwipeChanged)},
        {"nativeOnSwipeEnded", "(JFFZ)V", reinterpret_cast<void *>(onSwipeEnded)},
    };

    QJniEnvironment env;
    jclass javaClass = env.findClass("app/status/mobile/NativeSwipeHandlerHelper");
    if (javaClass) {
        env->RegisterNatives(javaClass, methods, sizeof(methods) / sizeof(methods[0]));
    }
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }

    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");
    if (!activity.isValid())
        return;

    m_javaHelper = QJniObject(
        "app/status/mobile/NativeSwipeHandlerHelper",
        "(JLandroid/app/Activity;)V",
        reinterpret_cast<jlong>(this),
        activity.object());

    if (!m_javaHelper.isValid())
        return;

    m_jniInitialized = true;
    updateOverlayBounds();
}

void NativeSwipeHandlerItem_Android::cleanupJNI()
{
    if (m_javaHelper.isValid()) {
        m_javaHelper.callMethod<void>("cleanup");
    }
    m_javaHelper = QJniObject();
    m_jniInitialized = false;
}

void NativeSwipeHandlerItem_Android::setupGestureRecognition()
{
    initializeJNI();
    polish();
}

void NativeSwipeHandlerItem_Android::teardownGestureRecognition()
{
    cleanupJNI();
    for (const auto &c : std::as_const(m_windowConnections))
        disconnect(c);
    m_windowConnections.clear();
}

void NativeSwipeHandlerItem_Android::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    NativeSwipeHandlerItem::geometryChange(newGeometry, oldGeometry);
    Q_UNUSED(oldGeometry)
    updateOverlayBounds();
}

void NativeSwipeHandlerItem_Android::itemChange(ItemChange change, const ItemChangeData &value)
{
    NativeSwipeHandlerItem::itemChange(change, value);
    if (change == ItemSceneChange) {
        if (value.window) {
            // Window can change/recreate on rotation; re-init JNI and re-push bounds.
            for (const auto &c : std::as_const(m_windowConnections))
                disconnect(c);
            m_windowConnections.clear();

            m_windowConnections.append(connect(value.window, &QQuickWindow::widthChanged, this, [this]() { polish(); }));
            m_windowConnections.append(connect(value.window, &QQuickWindow::heightChanged, this, [this]() { polish(); }));

            QTimer::singleShot(0, this, [this]() {
                teardownGestureRecognition();
                setupGestureRecognition();
            });
        }
        else teardownGestureRecognition();
    }
    if (change == ItemTransformHasChanged)
        polish();
}

void NativeSwipeHandlerItem_Android::updatePolish()
{
    QQuickItem::updatePolish();
    updateOverlayBounds();
}

void NativeSwipeHandlerItem_Android::updateOverlayBounds()
{
    if (!m_javaHelper.isValid() || !window() || !isVisible() || !isEnabled())
        return;

    const QPointF scenePos = mapToScene(QPointF(0, 0));
    const qreal dpr = window()->effectiveDevicePixelRatio();
    const qreal xPx = scenePos.x() * dpr;
    const qreal yPx = scenePos.y() * dpr;
    const qreal wPx = width() * dpr;
    const qreal hPx = height() * dpr;

    m_javaHelper.callMethod<void>("updateTouchOverlayBounds", "(FFFF)V",
                                  static_cast<jfloat>(xPx),
                                  static_cast<jfloat>(yPx),
                                  static_cast<jfloat>(wPx),
                                  static_cast<jfloat>(hPx));
}


void NativeSwipeHandlerItem_Android::onSwipeBegan(JNIEnv *, jobject, jlong ptr, jfloat)
{
    auto *self = reinterpret_cast<NativeSwipeHandlerItem_Android *>(ptr);
    if (!self || !self->window() || !self->isVisible() || !self->isEnabled())
        return;

    QPointer<NativeSwipeHandlerItem_Android> weak(self);
    QMetaObject::invokeMethod(self, [weak]() {
        if (!weak || !weak->window() || !weak->isVisible() || !weak->isEnabled())
            return;
        weak->m_active = true;
        emit weak->swipeStarted();
    }, Qt::QueuedConnection);
}

void NativeSwipeHandlerItem_Android::onSwipeChanged(JNIEnv *, jobject, jlong ptr, jfloat deltaX, jfloat velocityX)
{
    auto *self = reinterpret_cast<NativeSwipeHandlerItem_Android *>(ptr);
    if (!self)
        return;

    QPointer<NativeSwipeHandlerItem_Android> weak(self);
    QMetaObject::invokeMethod(self, [weak, deltaX, velocityX]() {
        if (!weak || !weak->m_active || !weak->window() || !weak->isVisible() || !weak->isEnabled())
            return;

        const qreal dpr = weak->window()->effectiveDevicePixelRatio();
        const qreal delta = static_cast<qreal>(deltaX) / qMax<qreal>(1.0, dpr);
        const qreal velocity = static_cast<qreal>(velocityX) / qMax<qreal>(1.0, dpr);
        emit weak->swipeUpdated(delta, velocity);
    }, Qt::QueuedConnection);
}

void NativeSwipeHandlerItem_Android::onSwipeEnded(JNIEnv *, jobject, jlong ptr, jfloat deltaX, jfloat velocityX, jboolean canceled)
{
    auto *self = reinterpret_cast<NativeSwipeHandlerItem_Android *>(ptr);
    if (!self)
        return;

    QPointer<NativeSwipeHandlerItem_Android> weak(self);
    QMetaObject::invokeMethod(self, [weak, deltaX, velocityX, canceled]() {
        if (!weak || !weak->m_active || !weak->window())
            return;

        const qreal dpr = weak->window()->effectiveDevicePixelRatio();
        const qreal delta = static_cast<qreal>(deltaX) / qMax<qreal>(1.0, dpr);
        const qreal v = static_cast<qreal>(velocityX) / qMax<qreal>(1.0, dpr);

        weak->m_active = false;
        emit weak->swipeEnded(delta, v, canceled == JNI_TRUE);
    }, Qt::QueuedConnection);
}

void registerNativeSwipeHandlerItemType()
{
    qmlRegisterType<NativeSwipeHandlerItem_Android>("StatusQ.Controls", 0, 1, "NativeSwipeHandlerItem");
}

#include "NativeSwipeHandlerItem_android.moc"

#endif // Q_OS_ANDROID
