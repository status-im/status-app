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

void requestNextFrame(QQuickWindow* window)
{
    if (QThread::currentThread() != window->thread()) {
        window->update();
        return;
    }

    // The basic render loop would render again right away and keep the GUI
    // thread rendering back to back.
    if (window->property(kFramePendingProperty).toBool())
        return;
    window->setProperty(kFramePendingProperty, true);
    QTimer::singleShot(kGuiThreadFrameIntervalMs, window, [window] {
        window->setProperty(kFramePendingProperty, false);
        window->update();
    });
}
