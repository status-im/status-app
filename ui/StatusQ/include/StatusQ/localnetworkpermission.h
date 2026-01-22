#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <memory>

class LocalNetworkPermissionBackend;

class LocalNetworkPermission : public QObject
{
    Q_OBJECT
    Q_PROPERTY(PermissionStatus status READ status NOTIFY statusChanged FINAL)

public:
    enum PermissionStatus {
        Unknown = 0,
        Granted = 1,
        Denied  = 2,
    };
    Q_ENUM(PermissionStatus)

    explicit LocalNetworkPermission(QObject* parent = nullptr);
    ~LocalNetworkPermission() override;

    PermissionStatus status() const;

    // Triggers a best-effort local-network probe. On first use, iOS may show the
    // Local Network permission prompt (driven by NSLocalNetworkUsageDescription).
    Q_INVOKABLE void request();

    Q_INVOKABLE void cancel();

signals:
    void statusChanged();

private:
    std::unique_ptr<LocalNetworkPermissionBackend> m_backend;

    PermissionStatus m_status{PermissionStatus::Unknown};

    void setStatus(PermissionStatus status);

    friend class LocalNetworkPermissionBackend;
};

