#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickItem>
#include <QRectF>
#include <QVariantList>

#include <atomic>
#include <cstdint>

// Camera preview for QR scanning without QtMultimedia: on Android a CameraX analysis
// stream (app.status.mobile.QrCamera) drawn as a texture, so scanning never loads the
// QtMultimedia backend or FFmpeg. Same API as StatusQrCodeCapture.qml, except that the
// host reads frames through `frameSource` (statusq_qrcam_* below) instead of a video
// sink. `supported` is false on other platforms, which keep StatusQrCodeCapture.
class NativeQrCodeCapture : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(bool supported READ supported CONSTANT)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool torchOn READ torchOn WRITE setTorchOn NOTIFY torchOnChanged)
    Q_PROPERTY(QVariantList availableCameras READ availableCameras CONSTANT)
    Q_PROPERTY(bool cameraAvailable READ cameraAvailable NOTIFY stateChanged)
    Q_PROPERTY(bool torchSupported READ torchSupported NOTIFY stateChanged)
    Q_PROPERTY(QString cameraError READ cameraError NOTIFY stateChanged)
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY layoutChanged)
    Q_PROPERTY(QSize contentSize READ contentSize NOTIFY layoutChanged)
    Q_PROPERTY(qreal sourceRatio READ sourceRatio NOTIFY layoutChanged)
    Q_PROPERTY(QRectF contentRect READ contentRect NOTIFY layoutChanged)
    Q_PROPERTY(int fillMode READ fillMode CONSTANT)
    Q_PROPERTY(bool mirrored READ mirrored NOTIFY mirroredChanged)
    Q_PROPERTY(int frameSource READ frameSource CONSTANT)

public:
    explicit NativeQrCodeCapture(QQuickItem* parent = nullptr);
    ~NativeQrCodeCapture() override;

    bool supported() const;
    bool active() const { return m_active; }
    void setActive(bool active);
    bool torchOn() const { return m_torchOn; }
    void setTorchOn(bool on);
    QVariantList availableCameras() const { return m_cameras; }
    bool cameraAvailable() const { return m_running && m_frameSize.isValid(); }
    bool torchSupported() const { return m_running && m_torchSupported; }
    QString cameraError() const { return m_error; }
    QSize sourceSize() const { return m_frameSize; }
    QSize contentSize() const { return contentRect().size().toSize(); }
    qreal sourceRatio() const;
    QRectF contentRect() const;
    int fillMode() const { return 2; } // VideoOutput.PreserveAspectCrop
    bool mirrored() const { return m_facing == QLatin1String("front"); }
    int frameSource() const { return m_handle; }

    Q_INVOKABLE void setCameraDevice(const QString& deviceId);
    // The area the decoder gets, in this item's pixels (the scan corners).
    Q_INVOKABLE void setPreviewRoi(qreal x, qreal y, qreal width, qreal height);

    using Consumer = void (*)(intptr_t user, const uint8_t* data, int width, int height,
                              int rowStride);
    void setConsumer(Consumer consumer, intptr_t user);
    void arm();

    // Analysis thread (JNI): one upright RGBA frame.
    void onFrame(const uchar* rgba, int rowStride, int width, int height);
    void onState(bool running, bool torchSupported, const QString& error);

signals:
    void activeChanged();
    void torchOnChanged();
    void stateChanged();
    void layoutChanged();
    void mirroredChanged();

protected:
    void componentComplete() override;
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;

private:
    void applyCamera();
    void deliver(const QByteArray& gray, int width, int height);

    const int m_handle;
    bool m_active = true;
    bool m_torchOn = false;
    bool m_running = false;
    bool m_torchSupported = false;
    QString m_error;
    QString m_facing = QStringLiteral("back");
    QVariantList m_cameras;
    QSize m_frameSize;
    Consumer m_consumer = nullptr;
    intptr_t m_consumerUser = 0;

    // Shared with the analysis and render threads.
    QMutex m_frameMutex;
    QImage m_frame;
    bool m_frameDirty = false;
    QRectF m_roi;
    QSizeF m_itemSize;
    bool m_roiMirrored = false;
    bool m_armed = false;
    qint64 m_lastPullMs = 0;
    std::atomic_bool m_updatePosted{false};
    void* m_camera = nullptr; // QJniObject* on Android
};

extern "C" {
// For a frame source in the decoder host (Nim, GUI thread): `source` is a
// NativeQrCodeCapture.frameSource. After arm(), the next frame (at most 10 per second)
// is cropped to the preview ROI, converted to 8-bit luma and passed to the consumer
// on the GUI thread, once.
Q_DECL_EXPORT void statusq_qrcam_set_consumer(int source, NativeQrCodeCapture::Consumer consumer,
                                              intptr_t user);
Q_DECL_EXPORT void statusq_qrcam_arm(int source);
}
