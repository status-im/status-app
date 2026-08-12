#include <QGuiApplication>

#include "StatusQ/osnotification.h"

#include <QDebug>

#ifdef Q_OS_WIN
#include <shellapi.h>
#include <stdlib.h>
#include <string.h>
#include <winuser.h>
#include <comdef.h>

using namespace Status;

static const UINT NOTIFYICONID = 0;
static std::pair<HWND, OSNotification *> HWND_INSTANCE_PAIR;
#endif

using namespace Qt::Literals::StringLiterals;

Q_LOGGING_CATEGORY(osNotification, "status.osNotification", QtInfoMsg)

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include <QDBusMessage>
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

constexpr auto kDbusService = "org.freedesktop.Notifications"_L1;
constexpr auto kDbusPath = "/org/freedesktop/Notifications"_L1;
constexpr auto kDbusInterface = "org.freedesktop.Notifications"_L1;

constexpr auto kDefaultAction = "default"_L1;
#endif

using namespace Status;

OSNotification::OSNotification(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_WIN
    initNotificationWin();
#elif defined Q_OS_MACOS
    initNotificationMacOs();
#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    auto bus = QDBusConnection::sessionBus();
    // NB see https://specifications.freedesktop.org/notification/latest-single/#signal-action-invoked
    bus.connect(kDbusService, kDbusPath, kDbusInterface, "ActionInvoked"_L1,
                this, SLOT(onActionInvoked(quint32, QString)));
    // NB see https://specifications.freedesktop.org/notification/latest-single/#signal-activation-token
    bus.connect(kDbusService, kDbusPath, kDbusInterface, "ActivationToken"_L1,
                this, SLOT(onActivationToken(quint32, QString)));
    // NB see https://specifications.freedesktop.org/notification/latest-single/#signal-notification-closed
    bus.connect(kDbusService, kDbusPath, kDbusInterface, "NotificationClosed"_L1,
                this, SLOT(onNotificationClosed(quint32, quint32)));
#endif
}

#ifndef Q_OS_MACOS
OSNotification::~OSNotification() = default;
#endif

#ifdef Q_OS_WIN
LRESULT CALLBACK StatusWndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    const int msgInfo = LOWORD(lParam);
    if (hwnd == HWND_INSTANCE_PAIR.first
        && HWND_INSTANCE_PAIR.second
        && HWND_INSTANCE_PAIR.second->m_identifiers.contains(uMsg)
        && msgInfo == NIN_BALLOONUSERCLICK)
    {
        emit HWND_INSTANCE_PAIR.second->notificationClicked(
            HWND_INSTANCE_PAIR.second->m_identifiers[uMsg]);
        return 0;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

void OSNotification::stringToLimitedWCharArray(QString in, wchar_t* target, int maxLength)
{
    const int length = qMin(maxLength - 1, in.size());
    if (length < in.size())
        in.truncate(length);
    in.toWCharArray(target);
    target[length] = wchar_t(0);
}

bool OSNotification::initNotificationWin()
{
    // Hold the std::string results in named locals so the c_str() pointers stay valid
    // until RegisterClassExA/FindWindowExA use them (a bare .toStdString().c_str() dangles).
    const std::string classNameStr = QStringLiteral("QTrayIconMessageWindowClass").toStdString();
    LPCSTR className = classNameStr.c_str();
    const std::string windowNameStr = QStringLiteral("QTrayIconMessageWindow").toStdString();
    LPCSTR windowName = windowNameStr.c_str();

    const auto appInstance = static_cast<HINSTANCE>(GetModuleHandle(nullptr));

    WNDCLASSEXA wc;
    wc.cbSize = sizeof(WNDCLASSEXA);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = StatusWndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = appInstance;
    wc.hCursor = nullptr;
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW);
    wc.hIcon = nullptr;
    wc.hIconSm = nullptr;
    wc.lpszMenuName = nullptr;
    wc.lpszClassName = className;

    ATOM atom = RegisterClassExA(&wc);
    if (!atom && GetLastError() != ERROR_CLASS_ALREADY_EXISTS)
        qWarning() << "Status::OsNotification registering window class failed.";

    m_hwnd = FindWindowExA(0, 0, className, windowName);
    if (m_hwnd) {
        HWND_INSTANCE_PAIR = std::make_pair(m_hwnd, this);
        return true;
    }
    return false;
}
#endif

void OSNotification::showNotification(const QString& title,
    const QString& message, const QString& identifier)
{
#ifdef Q_OS_WIN
    if (!initNotificationWin())
        return;

    auto sizeRestrictTitle = title.left(63).toStdString();
    auto sizeRestrictMessage = message.left(255).toStdString();

    NOTIFYICONDATAA tnd;
    memset(&tnd, 0, sizeof(tnd));
    tnd.cbSize = sizeof(tnd);
    tnd.uVersion = NOTIFYICON_VERSION_4;
    strncpy_s(tnd.szInfoTitle, sizeof(tnd.szInfoTitle), sizeRestrictTitle.c_str(), sizeRestrictTitle.size());
    strncpy_s(tnd.szInfo, sizeof(tnd.szInfo), sizeRestrictMessage.c_str(), sizeRestrictMessage.size());
    tnd.uID = NOTIFYICONID;
    tnd.hWnd = m_hwnd;
    tnd.dwInfoFlags = NIIF_INFO;
    tnd.uTimeout = UINT(10000);
    tnd.uFlags = NIF_MESSAGE | NIF_INFO | NIF_SHOWTIP;

    uint id = WM_APP + 2 + m_identifiers.size();
    m_identifiers.insert(id, identifier);
    tnd.uCallbackMessage = id;

    Shell_NotifyIconA(NIM_MODIFY, &tnd);

#elif defined Q_OS_MACOS
    showNotificationMacOs(title, message, identifier);
#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    // NB see https://specifications.freedesktop.org/notification/latest-single/#protocol for the API
    auto notifyMsg = QDBusMessage::createMethodCall(kDbusService, kDbusPath, kDbusInterface, "Notify"_L1);
    notifyMsg << QCoreApplication::applicationName(); // STRING app_name
    notifyMsg << quint32(0); // UINT32 replaces_id (0 == does not replace anything)
    notifyMsg << QString(); // STRING app_icon (using the app icon as decoration by default)
    notifyMsg << title; // STRING summary
    notifyMsg << message; // STRING body
    notifyMsg << QStringList{kDefaultAction, {}}; // AS actions ("default" == invoked on click)
    notifyMsg << QVariantMap(); // A{SV} hints
    notifyMsg << -1; // INT32 expire_timeout (-1 == impl dependent/default)

    auto pendingCall = QDBusConnection::sessionBus().asyncCall(notifyMsg);
    auto watcher = new QDBusPendingCallWatcher(pendingCall, this);

    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, this, [=](QDBusPendingCallWatcher *self) {
        QDBusPendingReply<quint32> reply = *self;
        if (reply.isValid()) {
            quint32 notificationId = reply.value();
            qCDebug(osNotification) << Q_FUNC_INFO << "Fired notification:" << notificationId << identifier;
            m_identifiers.insert(notificationId, identifier);
        } else {
            qCWarning(osNotification) << Q_FUNC_INFO << reply.error().name() << reply.error().message();
        }
        self->deleteLater();
    });

#else
    Q_UNUSED(title) Q_UNUSED(message) Q_UNUSED(identifier)
#endif
}

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
void OSNotification::onActionInvoked(quint32 id, const QString& actionKey)
{
    // NB see https://specifications.freedesktop.org/notification/latest-single/#signal-action-invoked
    // The "default" action is emitted when the user clicks the notification body itself.
    if (actionKey != kDefaultAction)
        return;
    if (!m_identifiers.contains(id)) {
        qCWarning(osNotification) << Q_FUNC_INFO << "Ignoring unknown notification with id:" << id;
        return;
    }

    if (m_activationTokens.contains(id)) {
        const auto token = m_activationTokens.take(id);
        if (!token.isEmpty())
            qputenv("XDG_ACTIVATION_TOKEN", token.toUtf8());
    }

    const auto identifier = m_identifiers.value(id);
    qCDebug(osNotification) << Q_FUNC_INFO << "User clicked notification:" << id << identifier;
    emit notificationClicked(identifier);
}

void OSNotification::onActivationToken(quint32 id, const QString& token)
{
    if (!m_identifiers.contains(id)) {
        qCWarning(osNotification) << Q_FUNC_INFO << "Ignoring activation token for unknown notification id:" << id;
        return;
    }
    qCDebug(osNotification) << Q_FUNC_INFO << "Got activation token for notification id:" << id;
    m_activationTokens.insert(id, token);
}

void OSNotification::onNotificationClosed(quint32 id, quint32 reason)
{
    // NB see https://specifications.freedesktop.org/notification/latest-single/#signal-notification-closed
    // Reason 1 = expired, 2 = dismissed by user, 3 = closed by CloseNotification call, 4 = undefined.
    // We only clean up the identifier map here; actual click handling is done in onActionInvoked.
    if (!m_identifiers.contains(id)) {
        qCWarning(osNotification) << Q_FUNC_INFO << "Ignoring unknown notification with id:" << id;
        return;
    }
    qCDebug(osNotification) << Q_FUNC_INFO << "Notification closed, id:" << id << "reason:" << reason;
    m_identifiers.remove(id);
    m_activationTokens.remove(id);
}
#endif

void OSNotification::showIconBadgeNotification(int notificationsCount)
{
    qGuiApp->setBadgeNumber(notificationsCount);
}
