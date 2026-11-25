#pragma once

#include <QCoreApplication>
#include <QObject>
#include <qpa/qwindowsysteminterface.h>

// Drives Qt.application.state in tests, as the OS does when the app goes to
// the background (mobile) or loses focus (desktop).
class AppStateDriver : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    Q_INVOKABLE void setActive(bool active)
    {
        setState(active ? Qt::ApplicationActive : Qt::ApplicationInactive);
    }

    Q_INVOKABLE void setSuspended()
    {
        setState(Qt::ApplicationSuspended);
    }

private:
    void setState(Qt::ApplicationState state)
    {
        QWindowSystemInterface::handleApplicationStateChanged(state, true);
        QWindowSystemInterface::flushWindowSystemEvents();
        QCoreApplication::processEvents();
    }
};
