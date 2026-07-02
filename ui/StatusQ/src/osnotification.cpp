#include "StatusQ/osnotification.h"

#ifdef Q_OS_WIN
#include <shellapi.h>
#include <stdlib.h>
#include <string.h>
#include <winuser.h>
#include <comdef.h>
#include <QDebug>

using namespace Status;

static const UINT NOTIFYICONID = 0;
static std::pair<HWND, OSNotification *> HWND_INSTANCE_PAIR;
#endif

#ifdef Q_OS_LINUX
#include <QProcess>
#include <QStandardPaths>
#include <QDebug>
#endif

using namespace Status;

OSNotification::OSNotification(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_WIN
    initNotificationWin();
#elif defined Q_OS_MACOS
    initNotificationMacOs();
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
#elif defined Q_OS_LINUX
    static QString notifyExe = QStandardPaths::findExecutable(QStringLiteral("notify-send"));
    if (notifyExe.isEmpty()) {
        qWarning() << "'notify-send' not found; OS notifications will not work";
        return;
    }
    QStringList args;
    args << QStringLiteral("-a") << QStringLiteral("nim-status");
    args << QStringLiteral("-c") << QStringLiteral("im");
    args << title;
    args << message;
    QProcess::execute(notifyExe, args);
#else
    Q_UNUSED(title) Q_UNUSED(message) Q_UNUSED(identifier)
#endif
}

void OSNotification::showIconBadgeNotification(int notificationsCount)
{
#ifdef Q_OS_MACOS
    showIconBadgeNotificationMacOs(notificationsCount);
#else
    Q_UNUSED(notificationsCount)
#endif
}
