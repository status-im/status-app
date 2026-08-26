#include "StatusQ/securestorage.h"

SecureStorage::SecureStorage(QObject *parent)
    : QObject(parent)
{
}

SecureStorage::~SecureStorage() = default;

QString SecureStorage::service() const
{
    return m_service;
}

void SecureStorage::setService(const QString &service)
{
    if (m_service == service)
        return;

    m_service = service;
    emit serviceChanged();
}
