#include "StatusQ/securestorage.h"

#include <QDebug>

#include <Foundation/Foundation.h>
#include <LocalAuthentication/LocalAuthentication.h>
#include <Security/Security.h>

static SecureStorage::Status convertStatus(OSStatus status)
{
    switch (status) {
    case errSecSuccess:
        return SecureStorage::StatusSuccess;
    case errSecItemNotFound:
        return SecureStorage::StatusNotFound;
    case errSecMissingEntitlement:
        // The data-protection keychain requires keychain entitlements (proper code
        // signing); unsigned dev builds fail with this status. There is deliberately NO
        // fallback to the legacy file-based keychain: legacy items cannot carry the
        // device-only accessibility this class guarantees (kSecAttrAccessible is only
        // supported for data-protection keychain items on macOS), so degrading would
        // silently weaken the protection of the stored credential.
        //
        // Unavailable, NOT NotSupported: the verdict is definitive for THIS process, but
        // it proves nothing about the store itself — an entitled build sharing the data
        // directory may have stored a credential this process cannot see or delete.
        // Callers must treat it as an unverified outcome (e.g. sign-out persists the
        // auto-login suppression instead of assuming nothing is stored).
        return SecureStorage::StatusUnavailable;
    default:
        return SecureStorage::StatusGenericError;
    }
}

// All items live exclusively in the data-protection keychain (see convertStatus for why
// the legacy file-based keychain is never used). On iOS it is the only keychain anyway.
static NSMutableDictionary *baseQuery(const QString &service, const QString &account)
{
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id) kSecClass] = (__bridge id) kSecClassGenericPassword;
    query[(__bridge id) kSecAttrService] = service.toNSString();
    query[(__bridge id) kSecAttrAccount] = account.toNSString();
#if TARGET_OS_OSX
    query[(__bridge id) kSecUseDataProtectionKeychain] = @YES;
#endif
    return query;
}

// A non-interactive LAContext guarantees no system prompt can ever appear: a query that
// touches an access-controlled item fails with errSecInteractionNotAllowed instead of
// prompting. Items written by this class carry no access control, so this is a guard for
// foreign/unexpected items, not a gate for our own.
static LAContext *silentContext()
{
    LAContext *context = [[[LAContext alloc] init] autorelease];
    context.interactionNotAllowed = YES;
    return context;
}

bool SecureStorage::available() const
{
    if (m_availableCache < 0) {
        // WRITE probe, not a read probe: on unsigned dev builds SecItemCopyMatching on
        // the data-protection keychain can report errSecItemNotFound (so reads look
        // fine) while SecItemAdd/SecItemDelete fail with errSecMissingEntitlement —
        // availability must prove the operations this class actually performs. The
        // probe item uses the exact attributes of a real write and is removed again.
        NSMutableDictionary *query = baseQuery(QStringLiteral("StatusSecureStorageProbe"),
                                               QStringLiteral("probe"));
        query[(__bridge id) kSecValueData] = [@"probe" dataUsingEncoding:NSUTF8StringEncoding];
        query[(__bridge id) kSecAttrAccessible] = (__bridge id) kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

        const auto status = SecItemAdd((__bridge CFDictionaryRef) query, NULL);

        // errSecDuplicateItem means a probe item from an earlier run survived — the
        // store accepted a write before, which proves the same thing.
        if (status == errSecSuccess || status == errSecDuplicateItem) {
            const auto cleanupStatus = SecItemDelete(
                        (__bridge CFDictionaryRef) baseQuery(QStringLiteral("StatusSecureStorageProbe"),
                                                             QStringLiteral("probe")));
            if (cleanupStatus != errSecSuccess && cleanupStatus != errSecItemNotFound)
                qWarning() << "SecureStorage: probe item cleanup failed OSStatus=" << (long) cleanupStatus;
            m_availableCache = 1;
        } else if (status == errSecMissingEntitlement) {
            m_availableCache = 0; // definitive — signing state cannot change within a process
            qWarning() << "SecureStorage: data-protection keychain unavailable (missing "
                          "entitlements, unsigned build?) — secure storage disabled";
        } else {
            // Transient/unexpected failure (e.g. keychain locked): report unavailable
            // but do NOT cache the verdict, so a later call can retry the probe.
            qWarning() << "SecureStorage: availability probe failed OSStatus=" << (long) status;
            return false;
        }
    }

    return m_availableCache == 1;
}

SecureStorage::Status SecureStorage::setCredential(const QString &account, const QString &credential)
{
    if (!available())
        return StatusUnavailable;

    // Remove any previous item first — it must be confirmed deleted/absent, otherwise a
    // stale copy could shadow or survive the new item.
    const auto deleteStatus = SecItemDelete((__bridge CFDictionaryRef) baseQuery(m_service, account));
    if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound) {
        qWarning() << "SecureStorage: failed to clear previous item OSStatus=" << (long) deleteStatus;
        return convertStatus(deleteStatus);
    }

    // Device-only, excluded from any sync/backup, readable only while unlocked.
    // Deliberately NO kSecAttrAccessControl — reads must stay prompt-free; that is the
    // class contract (the biometric-gated sibling item is managed by Keychain instead).
    NSMutableDictionary *query = baseQuery(m_service, account);
    query[(__bridge id) kSecValueData] = [credential.toNSString() dataUsingEncoding:NSUTF8StringEncoding];
    query[(__bridge id) kSecAttrAccessible] = (__bridge id) kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    const auto status = SecItemAdd((__bridge CFDictionaryRef) query, NULL);

    if (status != errSecSuccess)
        qWarning() << "SecureStorage: setCredential failed OSStatus=" << (long) status;

    return convertStatus(status);
}

SecureStorage::Status SecureStorage::deleteCredential(const QString &account)
{
    if (!available())
        return StatusUnavailable;

    const auto status = SecItemDelete((__bridge CFDictionaryRef) baseQuery(m_service, account));

    if (status != errSecSuccess && status != errSecItemNotFound)
        qWarning() << "SecureStorage: deleteCredential failed OSStatus=" << (long) status;

    return convertStatus(status);
}

SecureStorage::Status SecureStorage::hasCredential(const QString &account) const
{
    if (!available())
        return StatusUnavailable;

    NSMutableDictionary *query = baseQuery(m_service, account);
    query[(__bridge id) kSecReturnData] = @NO;
    query[(__bridge id) kSecReturnAttributes] = @YES;
    query[(__bridge id) kSecMatchLimit] = (__bridge id) kSecMatchLimitOne;
    query[(__bridge id) kSecUseAuthenticationContext] = silentContext();

    const auto status = SecItemCopyMatching((__bridge CFDictionaryRef) query, nil);

    // An access-controlled or invalidated item was never written by this class — report it
    // as absent rather than as something a prompt-free read could ever return.
    if (status == errSecInteractionNotAllowed || status == errSecAuthFailed)
        return StatusNotFound;

    return convertStatus(status);
}

QVariantMap SecureStorage::getCredential(const QString &account) const
{
    QString credential;

    if (!available())
        return {{QStringLiteral("status"), static_cast<int>(StatusUnavailable)},
                {QStringLiteral("credential"), credential}};

    NSMutableDictionary *query = baseQuery(m_service, account);
    query[(__bridge id) kSecReturnData] = @YES;
    query[(__bridge id) kSecMatchLimit] = (__bridge id) kSecMatchLimitOne;
    query[(__bridge id) kSecUseAuthenticationContext] = silentContext();

    CFDataRef data = NULL;
    auto status = SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef *) &data);

    // See hasCredential: never surface access-controlled items through the silent path.
    if (status == errSecInteractionNotAllowed || status == errSecAuthFailed)
        status = errSecItemNotFound;

    if (status == errSecSuccess && data != NULL) {
        NSString *dataString = [[[NSString alloc] initWithData:(__bridge NSData *) data
                                                      encoding:NSUTF8StringEncoding] autorelease];
        credential = QString::fromNSString(dataString);
    } else if (status != errSecSuccess && status != errSecItemNotFound) {
        qWarning() << "SecureStorage: getCredential failed OSStatus=" << (long) status;
    }

    if (data)
        CFRelease(data);

    return {{QStringLiteral("status"), static_cast<int>(convertStatus(status))},
            {QStringLiteral("credential"), credential}};
}
