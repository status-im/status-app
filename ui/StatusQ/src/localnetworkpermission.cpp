#include "StatusQ/localnetworkpermission.h"

#include "localnetworkpermission_backend.h"

#ifdef Q_OS_IOS
std::unique_ptr<LocalNetworkPermissionBackend> createLNPermissionIOS(LocalNetworkPermission* owner);
#endif

#ifndef Q_OS_IOS
namespace {
struct StubBackend final : LocalNetworkPermissionBackend {
    using LocalNetworkPermissionBackend::LocalNetworkPermissionBackend;

    void request() override {
        postStatus(LocalNetworkPermission::Granted);
    }

    void cancel() override {}
};
}
#endif

LocalNetworkPermission::LocalNetworkPermission(QObject* parent)
    : QObject(parent)
{
#ifdef Q_OS_IOS
    m_backend = createLNPermissionIOS(this);
#else
    m_backend = std::make_unique<StubBackend>(this);
#endif
}

LocalNetworkPermission::~LocalNetworkPermission()
{
    cancel();
}

LocalNetworkPermission::PermissionStatus LocalNetworkPermission::status() const
{
    return m_status;
}

void LocalNetworkPermission::setStatus(PermissionStatus status)
{
    if (m_status == status)
        return;

    m_status = status;
    emit statusChanged();
}

void LocalNetworkPermission::request()
{
    if (m_backend) m_backend->request();
}

void LocalNetworkPermission::cancel()
{
    if (m_backend) m_backend->cancel();
}
