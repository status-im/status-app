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

#ifndef Q_OS_ANDROID
SecureStorage::Status SecureStorage::setBootLoginRecord(const QString &)
{
    return StatusNotSupported;
}

SecureStorage::Status SecureStorage::deleteBootLoginRecord()
{
    return StatusNotSupported;
}

bool SecureStorage::isBootLoginRecordFromOtherVersion() const
{
    return false;
}
#endif
