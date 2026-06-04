#include "StatusQ/networkchecker.h"

#include <QDebug>
#include <QGuiApplication>
#include <QTimer>

namespace {
// Must match the connection types defined in status-go (see internal/connection/state.go)
QString connectionTypeFromTransport(QNetworkInformation::TransportMedium transportMedium)
{
    switch (transportMedium) {
    case QNetworkInformation::TransportMedium::Cellular:
        return QStringLiteral("cellular");
    case QNetworkInformation::TransportMedium::Ethernet:
        return QStringLiteral("wifi"); // Set as wifi as we do not distinguish between ethernet and wifi in the UI, and ethernet is not supported on all platforms
    case QNetworkInformation::TransportMedium::WiFi:
        return QStringLiteral("wifi");
    default:
        return QStringLiteral("unknown");
    }
}

using namespace std::chrono_literals;
constexpr auto kCheckDelay = 10s;
}

NetworkChecker::NetworkChecker(QObject *parent)
    : QObject(parent)
{
    if (!QNetworkInformation::loadDefaultBackend()) {
        qWarning() << "QNetworkInformation is not supported on this platform or backend.";
        setActive(false);
        return;
    }

    m_netinfo = QNetworkInformation::instance();

    // initial update; app becomes active, or 10s max
    QDeadlineTimer deadline(kCheckDelay);
    while (!deadline.hasExpired() || (QGuiApplication::applicationState() & Qt::ApplicationActive)) {
        init();
        break;
    }
}

void NetworkChecker::init()
{
    // subscribe for updates
    connect(m_netinfo, &QNetworkInformation::reachabilityChanged, this, &NetworkChecker::onReachabilityChanged);
    connect(m_netinfo, &QNetworkInformation::transportMediumChanged, this, &NetworkChecker::onTransportMediumChanged);
    connect(m_netinfo, &QNetworkInformation::isMeteredChanged, this, &NetworkChecker::onMeteredChanged);

    connect(qApp, &QGuiApplication::applicationStateChanged, this, [&](Qt::ApplicationState state) {
        QTimer::singleShot(kCheckDelay, this, [&]() { onReachabilityChanged(m_netinfo->reachability()); });
    });

    onReachabilityChanged(m_netinfo->reachability());
    updateConnectionDetails();
}

void NetworkChecker::onReachabilityChanged(QNetworkInformation::Reachability reachability)
{
    if (!m_active)
        return;

    const auto appStateFlags = QGuiApplication::applicationState();
    if (!(appStateFlags & Qt::ApplicationActive))
        return;

    setOnline(reachability == QNetworkInformation::Reachability::Online);
    updateConnectionDetails();
}

void NetworkChecker::onTransportMediumChanged()
{
    if (m_active) {
        updateConnectionDetails();
    }
}

void NetworkChecker::onMeteredChanged()
{
    if (m_active) {
        updateConnectionDetails();
    }
}

bool NetworkChecker::isOnline() const
{
    return m_online;
}

void NetworkChecker::setOnline(bool online)
{
    if (m_online == online)
        return;
    m_online = online;
    emit isOnlineChanged(m_online);
}

QString NetworkChecker::connectionType() const
{
    if (!m_netinfo) {
        return QStringLiteral("unknown");
    }

    if (!m_online) {
        return QStringLiteral("none");
    }
    return connectionTypeFromTransport(m_netinfo->transportMedium());
}

bool NetworkChecker::isExpensive() const
{
    if (!m_netinfo)
        return false;
    return m_netinfo->isMetered() || m_netinfo->transportMedium() == QNetworkInformation::TransportMedium::Cellular;
}

void NetworkChecker::updateConnectionDetails()
{
    emit connectionTypeChanged();
}

void NetworkChecker::checkNetwork()
{
    if (!m_netinfo)
        return;

    setActive(false);
    setChecking(true);
    setActive(true);
}

bool NetworkChecker::isActive() const
{
    return m_active;
}

void NetworkChecker::setActive(bool active)
{
    setChecking(false);

    if (active == m_active)
        return;

    m_active = active;
    emit activeChanged(active);

    // check immediately, when re-activating, or when called from checkNetwork()
    if (m_active) {
        setOnline(m_netinfo && m_netinfo->reachability() == QNetworkInformation::Reachability::Online);
        updateConnectionDetails();
    }
}

bool NetworkChecker::checking() const
{
    return m_checking;
}

void NetworkChecker::setChecking(bool checking)
{
    if (m_checking == checking)
        return;

    m_checking = checking;
    emit checkingChanged(m_checking);
}
