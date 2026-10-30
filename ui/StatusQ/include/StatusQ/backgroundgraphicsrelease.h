#pragma once

#include <QLoggingCategory>
#include <QObject>

Q_DECLARE_LOGGING_CATEGORY(backgroundGraphicsRelease)

namespace Status
{
    /// Frees the scene graph and the graphics context of every QQuickWindow
    /// that is no longer exposed once the application is suspended. Qt keeps
    /// both while a window stays visible, and a backgrounded Android window
    /// stays visible. The next expose rebuilds them.
    class BackgroundGraphicsRelease : public QObject
    {
        Q_OBJECT

    public:
        explicit BackgroundGraphicsRelease(QObject* parent = nullptr);

    public slots:
        void onApplicationStateChanged(Qt::ApplicationState state);
    };
} // namespace Status
