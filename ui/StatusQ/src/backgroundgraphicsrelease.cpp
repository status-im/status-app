#include "StatusQ/backgroundgraphicsrelease.h"

#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQuickWindow>

Q_LOGGING_CATEGORY(backgroundGraphicsRelease, "status.backgroundGraphicsRelease", QtInfoMsg)

namespace Status
{
BackgroundGraphicsRelease::BackgroundGraphicsRelease(QObject* parent)
    : QObject(parent)
{
    connect(qApp, &QGuiApplication::applicationStateChanged,
            this, &BackgroundGraphicsRelease::onApplicationStateChanged);
}

void BackgroundGraphicsRelease::onApplicationStateChanged(Qt::ApplicationState state)
{
    if (state != Qt::ApplicationSuspended)
        return;

    QElapsedTimer timer;
    timer.start();
    int released = 0;
    int kept = 0;
    int skipped = 0;

    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow* window : windows) {
        auto quickWindow = qobject_cast<QQuickWindow*>(window);
        if (!quickWindow)
            continue;
        // A window that is still exposed keeps rendering, so the render loop
        // would only drop its caches.
        if (quickWindow->isExposed()) {
            ++skipped;
            continue;
        }

        const bool hadGraphics = quickWindow->rhi();
        const bool persistentGraphics = quickWindow->isPersistentGraphics();
        const bool persistentSceneGraph = quickWindow->isPersistentSceneGraph();
        quickWindow->setPersistentGraphics(false);
        quickWindow->setPersistentSceneGraph(false);
        quickWindow->releaseResources();
        quickWindow->setPersistentGraphics(persistentGraphics);
        quickWindow->setPersistentSceneGraph(persistentSceneGraph);
        // Without the threaded render loop, or when nothing was rendered since
        // the last release, only caches are dropped.
        if (hadGraphics && !quickWindow->rhi())
            ++released;
        else
            ++kept;
    }

    qCInfo(backgroundGraphicsRelease) << "suspended: released" << released
                                      << "windows, kept" << kept
                                      << "(no GPU resources freed), skipped" << skipped
                                      << "still exposed, took" << timer.elapsed() << "ms";
}
} // namespace Status
