#pragma once

#include <QObject>
#include <QString>

#ifdef Q_OS_WIN
#include <QHash>

#include "windows.h"
#endif

namespace Status
{
    class OSNotification : public QObject
    {
        Q_OBJECT

    public:
        explicit OSNotification(QObject *parent = nullptr);
        ~OSNotification();

        void showNotification(const QString& title, const QString& message,
                              const QString& identifier);
        void showIconBadgeNotification(int notificationsCount);

    signals:
        void notificationClicked(const QString& identifier);

#ifdef Q_OS_WIN
    public:
        QHash<uint, QString> m_identifiers;

    private:
        bool initNotificationWin();
        void stringToLimitedWCharArray(QString in, wchar_t* target, int maxLength);
        HWND m_hwnd = nullptr;

#elif defined Q_OS_MACOS
    private:
        void initNotificationMacOs();
        void showNotificationMacOs(QString title, QString message, QString identifier);
        void* m_delegate = nullptr; // StatusQNotificationDelegate* (opaque to C++)
#endif
    };
}
