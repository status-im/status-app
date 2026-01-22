#pragma once

#include "StatusQ/localnetworkpermission.h"

#include <QMetaObject>
#include <QPointer>

class LocalNetworkPermissionBackend
{
public:
    explicit LocalNetworkPermissionBackend(LocalNetworkPermission* owner)
        : m_owner(owner)
    {}

    virtual ~LocalNetworkPermissionBackend() = default;

    virtual void request() = 0;
    virtual void cancel() = 0;

protected:
    QPointer<LocalNetworkPermission> m_owner;

    void postStatus(LocalNetworkPermission::PermissionStatus status)
    {
        if (!m_owner)
            return;
        // Update on the Qt thread.
        QMetaObject::invokeMethod(m_owner.data(), [o = m_owner, status]() {
            if (!o)
                return;
            o->setStatus(status);
        }, Qt::QueuedConnection);
    }
};

