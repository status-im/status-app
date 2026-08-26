#include "StatusQ/securestorage.h"

#include <QDebug>

bool SecureStorage::available() const
{
    return false;
}

SecureStorage::Status SecureStorage::setCredential(const QString &account, const QString &credential)
{
    Q_UNUSED(account);
    Q_UNUSED(credential);

    qWarning() << "SecureStorage::setCredential is not supported on this platform.";

    return SecureStorage::StatusNotSupported;
}

SecureStorage::Status SecureStorage::deleteCredential(const QString &account)
{
    Q_UNUSED(account);

    qWarning() << "SecureStorage::deleteCredential is not supported on this platform.";

    return SecureStorage::StatusNotSupported;
}

SecureStorage::Status SecureStorage::hasCredential(const QString &account) const
{
    Q_UNUSED(account);

    return SecureStorage::StatusNotSupported;
}

QVariantMap SecureStorage::getCredential(const QString &account) const
{
    Q_UNUSED(account);

    qWarning() << "SecureStorage::getCredential is not supported on this platform.";

    return {{QStringLiteral("status"), static_cast<int>(SecureStorage::StatusNotSupported)},
            {QStringLiteral("credential"), QString()}};
}
