#include "StatusQ/networkchecker.h"

#include <QDebug>

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

    // initial update
    onReachabilityChanged(m_netinfo->reachability());

    connect(this, &NetworkChecker::isOnlineChanged, this, [](bool online) {
        qInfo() << "!!! ONLINE CHANGED:" << online;
    });
}

void NetworkChecker::onReachabilityChanged(QNetworkInformation::Reachability reachability)
{
    if (m_active) {
        setOnline(reachability == QNetworkInformation::Reachability::Online);
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
