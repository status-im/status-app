#pragma once

#include <QNetworkInformation>

/// Automatically checks if the internet connection is available as long as the \c active property is \c true (by default it is)
class NetworkChecker : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool isOnline READ isOnline NOTIFY isOnlineChanged FINAL)
    Q_PROPERTY(QString connectionType READ connectionType NOTIFY connectionTypeChanged FINAL)
    Q_PROPERTY(bool isExpensive READ isExpensive NOTIFY isExpensiveChanged FINAL)
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged FINAL)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged FINAL)

public:
    explicit NetworkChecker(QObject *parent = nullptr);

    Q_INVOKABLE void checkNetwork();

signals:
    void isOnlineChanged(bool online);
    void connectionTypeChanged(const QString& connectionType);
    void isExpensiveChanged(bool isExpensive);
    void activeChanged(bool active);
    void checkingChanged(bool checking);

private slots:
    void onReachabilityChanged(QNetworkInformation::Reachability reachability);
    void onTransportMediumChanged(QNetworkInformation::TransportMedium transportMedium);
    void onMeteredChanged(bool isMetered);

private:
    QNetworkInformation* m_netinfo;

    bool m_online{true};
    bool isOnline() const;
    void setOnline(bool online);

    QString m_connectionType{"unknown"};
    QString connectionType() const;
    void setConnectionType(const QString& connectionType);

    bool m_isExpensive{false};
    bool isExpensive() const;
    void setExpensive(bool isExpensive);
    void updateConnectionDetails();

    bool m_active{true};
    bool isActive() const;
    void setActive(bool active);

    bool m_checking{false};
    bool checking() const;
    void setChecking(bool checking);
};
