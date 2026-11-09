#include "scenegraphanimation.h"

#include <QElapsedTimer>
#include <QQuickWindow>
#include <QThread>
#include <QTimer>

namespace {

constexpr int kGuiThreadFrameIntervalMs = 16;
constexpr char kFramePendingProperty[] = "_statusq_nextFramePending";

} // namespace

qint64 sceneGraphClockMs()
{
    static const QElapsedTimer clock = [] {
        QElapsedTimer timer;
        timer.start();
        return timer;
    }();
    return clock.elapsed();
}

AnimatedQuadNode::AnimatedQuadNode(QSGMaterial* material)
{
    setGeometry(new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4));
    setMaterial(material);
    setFlags(OwnsGeometry | OwnsMaterial | UsePreprocess);
}

AnimatedQuadNode::~AnimatedQuadNode()
{
    QObject::disconnect(m_beforeRendering);
}

void AnimatedQuadNode::setWindow(QQuickWindow* window)
{
    if (m_window == window)
        return;
    QObject::disconnect(m_beforeRendering);
    m_window = window;
    if (!window)
        return;
    // emitted on the thread that renders, before the layers render
    m_beforeRendering = QObject::connect(window, &QQuickWindow::beforeRendering, [this] {
        if (!m_nextFrameRequested)
            return;
        m_nextFrameRequested = false;
        markDirty(DirtyMaterial);
    });
}

void AnimatedQuadNode::setSize(const QSizeF& size)
{
    QSGGeometry::updateTexturedRectGeometry(geometry(), QRectF(QPointF(0, 0), size), QRectF(0, 0, 1, 1));
    markDirty(DirtyGeometry);
}

void AnimatedQuadNode::requestNextFrame()
{
    if (!m_window)
        return;
    m_nextFrameRequested = true;

    if (QThread::currentThread() != m_window->thread()) {
        m_window->update();
        return;
    }

    // The basic render loop would render again right away and keep the GUI
    // thread rendering back to back.
    if (m_window->property(kFramePendingProperty).toBool())
        return;
    m_window->setProperty(kFramePendingProperty, true);
    QQuickWindow* const window = m_window;
    QTimer::singleShot(kGuiThreadFrameIntervalMs, window, [window] {
        window->setProperty(kFramePendingProperty, false);
        window->update();
    });
}
