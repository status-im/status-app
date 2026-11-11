#include "StatusQ/nativeqrcodecapture.h"

#include <QDateTime>
#include <QHash>
#include <QLoggingCategory>
#include <QMutexLocker>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>

#include <jni.h>

#include <mutex>
#endif

namespace {
Q_LOGGING_CATEGORY(lcQrCam, "status.qrcam")

constexpr int handleBase = 0x40000000;
constexpr qint64 pullIntervalMs = 100;

// Items by frame-source handle. The lock is held while an item is used from the JNI
// threads, and the destructor removes the item under it.
QMutex registryMutex;
QHash<int, NativeQrCodeCapture*>& registry()
{
    static QHash<int, NativeQrCodeCapture*> items;
    return items;
}

int nextHandle()
{
    static std::atomic_int next{handleBase};
    return ++next;
}

QRectF cropRect(const QSizeF& item, const QSize& frame)
{
    if (frame.isEmpty() || item.isEmpty())
        return {};
    const qreal scale = qMax(item.width() / frame.width(), item.height() / frame.height());
    const QSizeF shown = QSizeF(frame) * scale;
    return QRectF((item.width() - shown.width()) / 2, (item.height() - shown.height()) / 2,
                  shown.width(), shown.height());
}

#ifdef Q_OS_ANDROID
void jniFrame(JNIEnv* env, jclass, jlong handle, jobject buffer, jint rowStride, jint width,
              jint height)
{
    const auto* data = static_cast<const uchar*>(env->GetDirectBufferAddress(buffer));
    if (!data)
        return;
    QMutexLocker lock(&registryMutex);
    if (auto* item = registry().value(int(handle)))
        item->onFrame(data, rowStride, width, height);
}

void jniState(JNIEnv*, jclass, jlong handle, jboolean running, jboolean torchSupported,
              jstring error)
{
    const QString message = QJniObject(error).toString();
    QMutexLocker lock(&registryMutex);
    if (auto* item = registry().value(int(handle)))
        item->onState(running, torchSupported, message);
}

constexpr auto javaClass = "app/status/mobile/QrCamera";

void registerNatives()
{
    static std::once_flag once;
    std::call_once(once, [] {
        QJniEnvironment env;
        jclass clazz = env.findClass(javaClass);
        if (!clazz) {
            qCWarning(lcQrCam) << "QrCamera class not found";
            return;
        }
        const JNINativeMethod methods[] = {
            {const_cast<char*>("nativeFrame"), const_cast<char*>("(JLjava/nio/ByteBuffer;III)V"),
             reinterpret_cast<void*>(jniFrame)},
            {const_cast<char*>("nativeState"), const_cast<char*>("(JZZLjava/lang/String;)V"),
             reinterpret_cast<void*>(jniState)},
        };
        if (env->RegisterNatives(clazz, methods, jint(std::size(methods))) != 0)
            qCWarning(lcQrCam) << "RegisterNatives failed";
    });
}

QJniObject* javaCamera(void* camera)
{
    return static_cast<QJniObject*>(camera);
}
#endif
} // namespace

NativeQrCodeCapture::NativeQrCodeCapture(QQuickItem* parent)
    : QQuickItem(parent)
    , m_handle(nextHandle())
{
    setFlag(ItemHasContents, true);
    {
        QMutexLocker lock(&registryMutex);
        registry().insert(m_handle, this);
    }
#ifdef Q_OS_ANDROID
    registerNatives();
    const QString list = QJniObject::callStaticMethod<jstring>(
                javaClass, "cameras", "(Landroid/content/Context;)Ljava/lang/String;",
                QNativeInterface::QAndroidApplication::context().object()).toString();
    for (const QString& line : list.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const auto parts = line.split(QLatin1Char('\t'));
        m_cameras.append(QVariantMap{{QStringLiteral("deviceId"), parts.value(0)},
                                     {QStringLiteral("displayName"), parts.value(1)}});
    }
#endif
}

NativeQrCodeCapture::~NativeQrCodeCapture()
{
    {
        QMutexLocker lock(&registryMutex);
        registry().remove(m_handle);
    }
#ifdef Q_OS_ANDROID
    if (auto* camera = javaCamera(m_camera)) {
        camera->callMethod<void>("release");
        delete camera;
    }
#endif
}

bool NativeQrCodeCapture::supported() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

void NativeQrCodeCapture::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    emit activeChanged();
    applyCamera();
}

void NativeQrCodeCapture::setTorchOn(bool on)
{
    if (m_torchOn == on)
        return;
    m_torchOn = on;
    emit torchOnChanged();
#ifdef Q_OS_ANDROID
    if (auto* camera = javaCamera(m_camera))
        camera->callMethod<void>("setTorch", "(Z)V", jboolean(on));
#endif
}

qreal NativeQrCodeCapture::sourceRatio() const
{
    return m_frameSize.isEmpty() ? 0 : qreal(m_frameSize.width()) / m_frameSize.height();
}

QRectF NativeQrCodeCapture::contentRect() const
{
    return cropRect(size(), m_frameSize);
}

void NativeQrCodeCapture::setCameraDevice(const QString& deviceId)
{
    if (deviceId.isEmpty() || deviceId == m_facing)
        return;
    m_facing = deviceId;
    {
        QMutexLocker lock(&m_frameMutex);
        m_roiMirrored = mirrored();
    }
    emit mirroredChanged();
    applyCamera();
}

void NativeQrCodeCapture::setPreviewRoi(qreal x, qreal y, qreal width, qreal height)
{
    QMutexLocker lock(&m_frameMutex);
    m_roi = QRectF(x, y, width, height);
}

void NativeQrCodeCapture::setConsumer(Consumer consumer, intptr_t user)
{
    m_consumer = consumer;
    m_consumerUser = user;
    if (!consumer) {
        QMutexLocker lock(&m_frameMutex);
        m_armed = false;
    }
}

void NativeQrCodeCapture::arm()
{
    QMutexLocker lock(&m_frameMutex);
    m_armed = true;
}

void NativeQrCodeCapture::componentComplete()
{
    QQuickItem::componentComplete();
    applyCamera();
}

void NativeQrCodeCapture::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    {
        QMutexLocker lock(&m_frameMutex);
        m_itemSize = newGeometry.size();
    }
    if (newGeometry.size() != oldGeometry.size()) {
        emit layoutChanged();
        update();
    }
}

void NativeQrCodeCapture::applyCamera()
{
    if (!isComponentComplete())
        return;
#ifdef Q_OS_ANDROID
    if (m_active) {
        if (!m_camera) {
            const QJniObject activity = QJniObject::callStaticObjectMethod(
                        "org/qtproject/qt/android/QtNative", "activity", "()Landroid/app/Activity;");
            auto* camera = new QJniObject(javaClass, "(JLandroid/app/Activity;)V", jlong(m_handle),
                                          activity.object());
            if (!camera->isValid()) {
                delete camera;
                m_error = QStringLiteral("Camera is not available");
                emit stateChanged();
                return;
            }
            m_camera = camera;
            if (m_torchOn)
                camera->callMethod<void>("setTorch", "(Z)V", jboolean(true));
        }
        javaCamera(m_camera)->callMethod<void>("start", "(Ljava/lang/String;)V",
                                              QJniObject::fromString(m_facing).object<jstring>());
    } else if (auto* camera = javaCamera(m_camera)) {
        camera->callMethod<void>("stop");
    }
#else
    if (m_error.isEmpty()) {
        m_error = QStringLiteral("Not supported on this platform");
        emit stateChanged();
    }
#endif
}

void NativeQrCodeCapture::onFrame(const uchar* rgba, int rowStride, int width, int height)
{
    QByteArray gray;
    QRect roi;
    {
        QMutexLocker lock(&m_frameMutex);
        if (m_frame.width() != width || m_frame.height() != height)
            m_frame = QImage(width, height, QImage::Format_RGBA8888);
        uchar* dst = m_frame.bits(); // detaches from a copy the renderer still holds
        const qsizetype dstStride = m_frame.bytesPerLine();
        for (int row = 0; row < height; ++row)
            memcpy(dst + row * dstStride, rgba + qsizetype(row) * rowStride, size_t(width) * 4);
        m_frameDirty = true;

        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (m_armed && now - m_lastPullMs >= pullIntervalMs) {
            m_armed = false;
            m_lastPullMs = now;
            // The scan corners as shown (cropped, maybe mirrored) mapped to the frame.
            const QRectF shown = cropRect(m_itemSize, QSize(width, height));
            QRectF area = m_roi.isValid() ? m_roi : QRectF(QPointF(), m_itemSize);
            if (m_roiMirrored)
                area.moveLeft(m_itemSize.width() - area.right());
            if (!shown.isEmpty()) {
                const qreal scale = shown.width() / width;
                roi = QRectF((area.x() - shown.x()) / scale, (area.y() - shown.y()) / scale,
                             area.width() / scale, area.height() / scale)
                          .toAlignedRect()
                          .intersected(QRect(0, 0, width, height));
            }
            if (roi.isEmpty())
                roi = QRect(0, 0, width, height);
            gray.resize(qsizetype(roi.width()) * roi.height());
            auto* out = reinterpret_cast<uchar*>(gray.data());
            for (int y = 0; y < roi.height(); ++y) {
                const uchar* p = rgba + qsizetype(roi.y() + y) * rowStride + roi.x() * 4;
                for (int x = 0; x < roi.width(); ++x, p += 4)
                    *out++ = uchar((77 * p[0] + 150 * p[1] + 29 * p[2]) >> 8);
            }
        }
    }

    const QSize frameSize(width, height);
    if (!gray.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, gray, roi, frameSize] {
            if (m_frameSize != frameSize) {
                m_frameSize = frameSize;
                emit layoutChanged();
                emit stateChanged();
            }
            deliver(gray, roi.width(), roi.height());
        }, Qt::QueuedConnection);
    }
    if (!m_updatePosted.exchange(true)) {
        QMetaObject::invokeMethod(this, [this, frameSize] {
            m_updatePosted = false;
            if (m_frameSize != frameSize) {
                m_frameSize = frameSize;
                emit layoutChanged();
                emit stateChanged();
            }
            update();
        }, Qt::QueuedConnection);
    }
}

void NativeQrCodeCapture::onState(bool running, bool torchSupported, const QString& error)
{
    QMetaObject::invokeMethod(this, [this, running, torchSupported, error] {
        m_running = running;
        m_torchSupported = torchSupported;
        if (!error.isEmpty() || running)
            m_error = error;
        if (!running) {
            m_frameSize = QSize();
            emit layoutChanged();
        }
        emit stateChanged();
    }, Qt::QueuedConnection);
}

void NativeQrCodeCapture::deliver(const QByteArray& gray, int width, int height)
{
    if (m_consumer)
        m_consumer(m_consumerUser, reinterpret_cast<const uint8_t*>(gray.constData()), width,
                   height, width);
}

QSGNode* NativeQrCodeCapture::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    auto* node = static_cast<QSGSimpleTextureNode*>(oldNode);
    QImage frame;
    bool dirty;
    {
        QMutexLocker lock(&m_frameMutex);
        dirty = m_frameDirty;
        m_frameDirty = false;
        if (dirty)
            frame = m_frame;
    }
    if (!cameraAvailable() || width() <= 0 || height() <= 0) {
        delete node;
        return nullptr;
    }
    if (!node) {
        if (!dirty)
            return nullptr;
        node = new QSGSimpleTextureNode;
        node->setOwnsTexture(true);
        node->setFiltering(QSGTexture::Linear);
    }
    if (dirty && !frame.isNull())
        node->setTexture(window()->createTextureFromImage(frame));
    if (!node->texture()) {
        delete node;
        return nullptr;
    }
    const QSize texSize = node->texture()->textureSize();
    const QRectF shown = cropRect(size(), texSize);
    const qreal scale = shown.width() / texSize.width();
    node->setRect(boundingRect());
    node->setSourceRect(QRectF(-shown.x() / scale, -shown.y() / scale, width() / scale,
                               height() / scale));
    node->setTextureCoordinatesTransform(mirrored() ? QSGSimpleTextureNode::MirrorHorizontally
                                                    : QSGSimpleTextureNode::NoTransform);
    return node;
}

extern "C" {
Q_DECL_EXPORT void statusq_qrcam_set_consumer(int source, NativeQrCodeCapture::Consumer consumer,
                                              intptr_t user)
{
    QMutexLocker lock(&registryMutex);
    if (auto* item = registry().value(source))
        item->setConsumer(consumer, user);
}

Q_DECL_EXPORT void statusq_qrcam_arm(int source)
{
    QMutexLocker lock(&registryMutex);
    if (auto* item = registry().value(source))
        item->arm();
}
}
