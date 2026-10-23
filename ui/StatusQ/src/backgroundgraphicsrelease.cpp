#include "StatusQ/backgroundgraphicsrelease.h"

#include <QGuiApplication>
#include <QQuickWindow>

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

    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow* window : windows) {
        auto quickWindow = qobject_cast<QQuickWindow*>(window);
        // A window that is still exposed keeps rendering, so the render loop
        // would only drop its caches.
        if (!quickWindow || quickWindow->isExposed())
            continue;

        const bool persistentGraphics = quickWindow->isPersistentGraphics();
        const bool persistentSceneGraph = quickWindow->isPersistentSceneGraph();
        quickWindow->setPersistentGraphics(false);
        quickWindow->setPersistentSceneGraph(false);
        quickWindow->releaseResources();
        quickWindow->setPersistentGraphics(persistentGraphics);
        quickWindow->setPersistentSceneGraph(persistentSceneGraph);
    }
}
