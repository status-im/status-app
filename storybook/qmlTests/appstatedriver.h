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
        QWindowSystemInterface::handleApplicationStateChanged(
            active ? Qt::ApplicationActive : Qt::ApplicationInactive, true);
        QWindowSystemInterface::flushWindowSystemEvents();
        QCoreApplication::processEvents();
    }
};
