#pragma once

#include <QObject>
#include <QString>
#include <QHash>
#include <QLoggingCategory>

#ifdef Q_OS_WIN
#include "windows.h"
#endif

Q_DECLARE_LOGGING_CATEGORY(osNotification)

namespace Status
{
    class OSNotification : public QObject
    {
        Q_OBJECT

    public:
        explicit OSNotification(QObject *parent = nullptr);
        ~OSNotification() override;

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

#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    private:
        QHash<quint32, QString> m_identifiers;
        QHash<quint32, QString> m_activationTokens;
    private slots:
        void onActionInvoked(quint32 id, const QString& actionKey);
        void onActivationToken(quint32 id, const QString& token);
        void onNotificationClosed(quint32 id, quint32 reason);
#endif
    };
}
