#include "StatusQ/networkchecker.h"

#include <QDebug>

namespace {
// Must match the connection types defined in status-go (see internal/connection/state.go)
QString connectionTypeFromTransport(QNetworkInformation::TransportMedium transportMedium)
{
    switch (transportMedium) {
    case QNetworkInformation::TransportMedium::Cellular:
        return "cellular";
    case QNetworkInformation::TransportMedium::Ethernet:
        return "wifi"; // Set as wifi as we do not distinguish between ethernet and wifi in the UI, and ethernet is not supported on all platforms
    case QNetworkInformation::TransportMedium::WiFi:
        return "wifi";
    default:
        return "unknown";
    }
}
}

NetworkChecker::NetworkChecker(QObject *parent)
    : QObject(parent)
{
    qInfo() << "!!! QNetworkInformation backends:" << QNetworkInformation::availableBackends();

    if (!QNetworkInformation::loadDefaultBackend()) {
        qWarning() << "QNetworkInformation is not supported on this platform or backend.";
        return;
    }

    m_netinfo = QNetworkInformation::instance();
    qInfo() << "!!! Using QNetworkInformation backend:" << m_netinfo->backendName();

    // subscribe for updates
    connect(m_netinfo, &QNetworkInformation::reachabilityChanged, this, &NetworkChecker::onReachabilityChanged);
    connect(m_netinfo, &QNetworkInformation::transportMediumChanged, this, &NetworkChecker::onTransportMediumChanged);
    connect(m_netinfo, &QNetworkInformation::isMeteredChanged, this, &NetworkChecker::onMeteredChanged);

    // initial update
    onReachabilityChanged(m_netinfo->reachability());
    updateConnectionDetails();

    connect(this, &NetworkChecker::isOnlineChanged, this, [](bool online) {
        qInfo() << "!!! ONLINE CHANGED:" << online;
    });
}

void NetworkChecker::onReachabilityChanged(QNetworkInformation::Reachability reachability)
{
    if (m_active) {
        setOnline(reachability == QNetworkInformation::Reachability::Online);
        updateConnectionDetails();
    }
}

void NetworkChecker::onTransportMediumChanged(QNetworkInformation::TransportMedium transportMedium)
{
    Q_UNUSED(transportMedium)

    if (m_active) {
        updateConnectionDetails();
    }
}

void NetworkChecker::onMeteredChanged(bool isMetered)
{
    Q_UNUSED(isMetered)

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
    return m_connectionType;
}

void NetworkChecker::setConnectionType(const QString& connectionType)
{
    if (m_connectionType == connectionType)
        return;

    m_connectionType = connectionType;
    emit connectionTypeChanged(m_connectionType);
}

bool NetworkChecker::isExpensive() const
{
    return m_isExpensive;
}

void NetworkChecker::setExpensive(bool isExpensive)
{
    if (m_isExpensive == isExpensive)
        return;

    m_isExpensive = isExpensive;
    emit isExpensiveChanged(m_isExpensive);
}

void NetworkChecker::updateConnectionDetails()
{
    if (!m_netinfo) {
        setConnectionType("unknown");
        setExpensive(false);
        return;
    }

    if (!m_online) {
        setConnectionType("none");
        setExpensive(false);
        return;
    }

    const auto newConnectionType = connectionTypeFromTransport(m_netinfo->transportMedium());
    const bool expensive = m_netinfo->isMetered() || newConnectionType == "cellular";

    setConnectionType(newConnectionType);
    setExpensive(expensive);
}

void NetworkChecker::checkNetwork()
{
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
