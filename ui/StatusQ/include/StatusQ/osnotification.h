#ifndef STATUSQ_OS_NOTIFICATION_H
#define STATUSQ_OS_NOTIFICATION_H

#include <QObject>
#include <QString>
#include <QHash>

#ifdef Q_OS_WIN
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
        void notificationClicked(QString identifier);

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
        void showIconBadgeNotificationMacOs(int notificationsCount);
        void* m_delegate = nullptr; // StatusQNotificationDelegate* (opaque to C++)
#endif
    };
}

#endif // STATUSQ_OS_NOTIFICATION_H
