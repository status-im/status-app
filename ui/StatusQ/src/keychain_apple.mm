#include "StatusQ/keychain.h"

#include <QDebug>
#include <QEventLoop>
#include <QFuture>
#include <QGuiApplication>
#include <QtConcurrent/QtConcurrent>

#include <Foundation/Foundation.h>
#include <LocalAuthentication/LocalAuthentication.h>
#include <Security/Security.h>

#if TARGET_OS_OSX
const static auto authPolicy =
    #if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
        LAPolicyDeviceOwnerAuthenticationWithBiometricsOrCompanion;
    #elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 101202
        LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    #else
        LAPolicyDeviceOwnerAuthentication;
    #endif
#elif TARGET_OS_IPHONE
const static LAPolicy authPolicy =
    #if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
        LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    #else
    LAPolicyDeviceOwnerAuthentication;
    #endif
#else
const static LAPolicy authPolicy = LAPolicyDeviceOwnerAuthentication;
#endif

static Keychain::Status convertStatus(OSStatus status)
{
    switch (status) {
    case errSecSuccess:
        return Keychain::StatusSuccess;
    case errSecItemNotFound:
        return Keychain::StatusNotFound;
#if defined(errSecCSCancelled)
    // Present on macOS SDKs
    case errSecCSCancelled:
        return Keychain::StatusCancelled;
#endif
#if defined(errSecUserCanceled)
    // Present on iOS (and also macOS); treat as the same "user cancelled" outcome
    case errSecUserCanceled:
        return Keychain::StatusCancelled;
#endif
    default:
        return Keychain::StatusGenericError;
    }
}

Keychain::Status convertError(NSError *error)
{
    switch (error.code) {
    case errSecSuccess:
        return Keychain::StatusSuccess;
    case LAErrorSystemCancel:
    case LAErrorUserCancel:
    case LAErrorAppCancel:
        return Keychain::StatusCancelled;
    case LAErrorUserFallback:
        return Keychain::StatusFallbackSelected;
    default:
        return Keychain::StatusGenericError;
    }
}

// Base attributes addressing a credential item. On macOS, hardened (biometric-bound) items
// live in the data-protection keychain, while items saved before the hardening (or by
// builds lacking the required entitlements) live in the legacy file-based keychain —
// `dataProtection` selects which one a query addresses. On iOS there is only the
// data-protection keychain, so the flag is irrelevant.
static NSMutableDictionary *baseQuery(const QString &service, const QString &account, bool dataProtection)
{
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id) kSecClass] = (__bridge id) kSecClassGenericPassword;
    query[(__bridge id) kSecAttrService] = service.toNSString();
    query[(__bridge id) kSecAttrAccount] = account.toNSString();
#if TARGET_OS_OSX
    if (dataProtection)
        query[(__bridge id) kSecUseDataProtectionKeychain] = @YES;
#else
    Q_UNUSED(dataProtection)
#endif
    return query;
}

// The data-protection keychain requires keychain entitlements (proper code signing);
// unsigned dev builds fail with errSecMissingEntitlement — the only condition under which
// operations may fall back to (or degrade to) the legacy file-based keychain, besides a
// plain errSecItemNotFound. Anything else (e.g. errSecNotAvailable, a general availability
// failure) leaves the hardened store's state unknown and must be propagated as an error.
static bool dataProtectionUnavailable(OSStatus status)
{
    return status == errSecMissingEntitlement;
}

Keychain::Keychain(QObject *parent)
    : QObject(parent)
{
    reevaluateAvailability();

    connect(qApp,
            &QGuiApplication::applicationStateChanged,
            this,
            [this](Qt::ApplicationState state) {
                if (state == Qt::ApplicationActive) {
                    reevaluateAvailability();
                }
            });
}

Keychain::~Keychain()
{
    cancelActiveRequest();
    m_future.waitForFinished();
}

bool Keychain::available() const
{
    return m_available;
}

Keychain::Status authenticate(const QString &reason, LAContext **context)
{
    if (context == nullptr)
        return Keychain::StatusGenericError;

    if (*context != nullptr) {
        qWarning() << "another local authentication request in progress";
        return Keychain::StatusGenericError;
    }

    *context = [[LAContext alloc] init];
    (*context).localizedFallbackTitle = QObject::tr("Use Status profile password").toNSString();

    QEventLoop loop;
    auto loopPtr = &loop;
    __block NSError *callbackError = nil;
    __block BOOL success = NO;

    // Prompt for biometrics authentication
    [*context evaluatePolicy:authPolicy
             localizedReason:reason.toNSString()
                       reply:^(BOOL authSuccess, NSError *error) {
                           success = authSuccess;
                           callbackError = error ? [error copy] : nil;
                           loopPtr->quit();
                       }];

    // Wait for biometrics authentication finished
    loop.exec();

    if (!success && callbackError) {
        qWarning() << "Keychain: authentication failed:"
                   << QString::fromNSString(callbackError.localizedDescription)
                   << "code=" << (long) callbackError.code
                   << "domain=" << QString::fromNSString(callbackError.domain)
                   << "(LAErrorNotInteractive=" << (long) LAErrorNotInteractive
                   << "LAErrorSystemCancel=" << (long) LAErrorSystemCancel << ")";
        return convertError(callbackError);
    }

    return Keychain::StatusSuccess;
}

void Keychain::requestGetCredential(const QString &reason, const QString &account)
{
    if (m_future.isRunning()) {
        qWarning() << "Keychain: getCredential already running, ignoring request";
        return;
    }

    const auto appState = qApp->applicationState();
    if (appState != Qt::ApplicationActive) {
        qWarning() << "Keychain: app not active (state=" << appState << "), deferring credential request";

        QObject::disconnect(m_pendingActivationConn);

        m_pendingActivationConn = connect(
            qApp,
            &QGuiApplication::applicationStateChanged,
            this,
            [this, reason, account](Qt::ApplicationState state) {
                if (state != Qt::ApplicationActive)
                    return;
                QObject::disconnect(m_pendingActivationConn);
                qInfo() << "Keychain: app became active, resuming deferred credential request";
                requestGetCredential(reason, account);
            });
        return;
    }

    m_future = QtConcurrent::run([this, reason, account]() {
        setLoading(true);
        QString credential;
        const auto status = getCredential(reason, account, &credential);
        qInfo() << "Keychain: getCredential completed status=" << status;
        emit getCredentialRequestCompleted(status, credential);
        setLoading(false);
    });
}

void Keychain::cancelActiveRequest()
{
    QObject::disconnect(m_pendingActivationConn); // cancel any pending activation connection

    if (m_activeAuthContext != nullptr)
        [m_activeAuthContext invalidate];
}

Keychain::Status Keychain::saveCredential(const QString &account, const QString &password)
{
    CFErrorRef error = NULL;

    // On iOS there is no Apple Watch companion unlock; keep flags minimal.
    #if TARGET_OS_OSX
        auto flags = kSecAccessControlBiometryCurrentSet | kSecAccessControlOr | kSecAccessControlWatch;
    #else
        auto flags = kSecAccessControlBiometryCurrentSet;
    #endif

    // The keychain itself enforces biometrics for reading the item, and BiometryCurrentSet
    // invalidates it when the biometric enrollment changes. ThisDeviceOnly accessibility
    // (embedded in the access control) keeps the item out of any sync/backup.
    auto accessControl = SecAccessControlCreateWithFlags(NULL,
                                                         kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                         flags,
                                                         &error);

    if (error) {
        qWarning() << "failed to create SecAccessControl:"
                   << QString::fromNSString(
                          (__bridge_transfer NSString *) CFErrorCopyDescription(error));
        CFRelease(error);
        return StatusGenericError;
    }

    NSData *value = [password.toNSString() dataUsingEncoding:NSUTF8StringEncoding];

    // Remove any previous item from both keychains: every overwrite thereby doubles as the
    // migration of a legacy (pre-hardening) item to the hardened, biometric-bound form.
    // Each store must be confirmed deleted/absent — a stale copy left behind would shadow
    // or survive the new item.
    const auto dpDelete = SecItemDelete((__bridge CFDictionaryRef) baseQuery(m_service, account, true));
    if (dpDelete != errSecSuccess && dpDelete != errSecItemNotFound && !dataProtectionUnavailable(dpDelete)) {
        qWarning() << "Keychain: failed to clear previous hardened item OSStatus=" << (long) dpDelete;
        CFRelease(accessControl);
        return convertStatus(dpDelete);
    }
    const auto legacyDelete = SecItemDelete((__bridge CFDictionaryRef) baseQuery(m_service, account, false));
    if (legacyDelete != errSecSuccess && legacyDelete != errSecItemNotFound) {
        qWarning() << "Keychain: failed to clear previous legacy item OSStatus=" << (long) legacyDelete;
        CFRelease(accessControl);
        return convertStatus(legacyDelete);
    }

    NSMutableDictionary *query = baseQuery(m_service, account, true);
    query[(__bridge id) kSecValueData] = value;
    query[(__bridge id) kSecAttrAccessControl] = (__bridge id) accessControl;

    auto status = SecItemAdd((__bridge CFDictionaryRef) query, NULL);

    if (status != errSecSuccess && dataProtectionUnavailable(status)) {
        // The biometric-bound item requires the data-protection keychain, which in turn
        // requires proper code signing (keychain entitlements) — unsigned dev builds fail
        // here. Degrade to a legacy item (pre-hardening protection level, still gated by
        // the app-level LAContext authentication) rather than losing biometrics entirely.
        // Any other failure is reported as-is.
        qWarning() << "Keychain: data-protection keychain unavailable OSStatus=" << (long) status
                   << ", storing legacy item instead";
        NSMutableDictionary *legacyQuery = baseQuery(m_service, account, false);
        legacyQuery[(__bridge id) kSecValueData] = value;
        status = SecItemAdd((__bridge CFDictionaryRef) legacyQuery, NULL);
    }

    CFRelease(accessControl);
    if (status == errSecSuccess) {
        emit credentialSaved(account);
    } else {
        qWarning() << "Keychain: saveCredential failed OSStatus=" << (long) status;
    }

    return convertStatus(status);
}

Keychain::Status Keychain::deleteCredential(const QString &account)
{
    // The item may live in either keychain (hardened or legacy/pre-hardening); remove both.
    const auto dpStatus = SecItemDelete((__bridge CFDictionaryRef) baseQuery(m_service, account, true));
    const auto legacyStatus = SecItemDelete((__bridge CFDictionaryRef) baseQuery(m_service, account, false));

    // Success is only reported when BOTH stores are confirmed deleted or absent — otherwise
    // a copy could remain accessible after credentialDeleted was emitted.
    const bool dpResolved = dpStatus == errSecSuccess || dpStatus == errSecItemNotFound
                            || dataProtectionUnavailable(dpStatus);
    const bool legacyResolved = legacyStatus == errSecSuccess || legacyStatus == errSecItemNotFound;

    if (!dpResolved || !legacyResolved) {
        const auto failure = !dpResolved ? dpStatus : legacyStatus;
        qWarning() << "Keychain: deleteCredential failed OSStatus=" << (long) failure;
        return convertStatus(failure);
    }

    if (dpStatus != errSecSuccess && legacyStatus != errSecSuccess) {
        return StatusNotFound; // nothing existed in either store
    }

    emit credentialDeleted(account);
    return StatusSuccess;
}

Keychain::Status Keychain::getCredential(const QString &reason, const QString &account, QString *out)
{
    if (!m_available) {
        qWarning() << "Keychain: getCredential called while unavailable (m_available=false)";
        return StatusUnavailable;
    }

    QScopedValueRollback<LAContext *> roolback(m_activeAuthContext, nullptr);
    const auto authStatus = authenticate(reason, &m_activeAuthContext);

    if (authStatus != StatusSuccess) {
        qWarning() << "Keychain: getCredential aborting, authenticate status=" << authStatus;
        return authStatus;
    }

    // The freshly evaluated LAContext satisfies the item's access control without a second
    // prompt (iOS 11+/macOS 10.13+ support kSecUseAuthenticationContext).
    const auto copyItem = [this, &account](bool dataProtection, CFDataRef *data) {
        NSMutableDictionary *query = baseQuery(m_service, account, dataProtection);
        query[(__bridge id) kSecReturnData] = @YES;
        query[(__bridge id) kSecMatchLimit] = (__bridge id) kSecMatchLimitOne;
        query[(__bridge id) kSecUseAuthenticationContext] = m_activeAuthContext;
        return SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef *) data);
    };

    CFDataRef data = NULL;

    // Hardened item first.
    auto status = copyItem(true, &data);

    // A biometric re-enrollment invalidates the BiometryCurrentSet-bound item: report it as
    // missing so callers fall back to password entry (the next successful save re-binds the
    // item to the new enrollment). Deliberately no legacy fallback here — a leftover legacy
    // copy must never resurrect a credential the invalidation just revoked.
    if (status == errSecAuthFailed) {
        qWarning() << "Keychain: hardened item invalidated (errSecAuthFailed), reporting not found";
        return StatusNotFound;
    }

    // Items saved before the hardening (or by builds without keychain entitlements) remain
    // readable from the legacy keychain; any other failure is propagated as-is.
    if (status == errSecItemNotFound || dataProtectionUnavailable(status))
        status = copyItem(false, &data);

    if (status != errSecSuccess) {
        qWarning() << "Keychain: SecItemCopyMatching failed OSStatus=" << (long) status
                   << "(errSecItemNotFound=" << (long) errSecItemNotFound
                   << "errSecInteractionNotAllowed=" << (long) errSecInteractionNotAllowed
                   << "errSecAuthFailed=" << (long) errSecAuthFailed << ")";
    }

    // Convert and release CF data on success.
    if (out != nullptr) {
        auto dataString = [[NSString alloc] initWithData:(__bridge NSData *) data
                                                encoding:NSUTF8StringEncoding];
        *out = QString::fromNSString(dataString);
    }

    if (data) CFRelease(data);

    return convertStatus(status);
}

void Keychain::reevaluateAvailability()
{
    auto context = [[LAContext alloc] init];
    NSError *authError = nil;

    const auto available = [context canEvaluatePolicy:authPolicy error:&authError];

    qInfo() << "Keychain: reevaluateAvailability available=" << available
            << "appState=" << qApp->applicationState()
            << (authError ? QString::fromNSString(authError.localizedDescription) : QString());

    if (m_available == available) {
        return;
    }

    m_available = available;
    emit availableChanged();
}

Keychain::Status Keychain::hasCredential(const QString &account) const
{
    // Existence check must never prompt: request attributes only and forbid interaction
    // (a non-interactive LAContext makes protected queries fail with
    // errSecInteractionNotAllowed instead of showing a biometric prompt).
    LAContext *silentContext = [[[LAContext alloc] init] autorelease];
    silentContext.interactionNotAllowed = YES;

    const auto check = [this, &account, silentContext](bool dataProtection) {
        NSMutableDictionary *query = baseQuery(m_service, account, dataProtection);
        query[(__bridge id) kSecReturnData] = @NO;
        query[(__bridge id) kSecReturnAttributes] = @YES;
        query[(__bridge id) kSecMatchLimit] = (__bridge id) kSecMatchLimitOne;
        query[(__bridge id) kSecUseAuthenticationContext] = silentContext;
        return SecItemCopyMatching((__bridge CFDictionaryRef) query, nil);
    };

    auto status = check(true);
    if (status == errSecItemNotFound || dataProtectionUnavailable(status))
        status = check(false); // legacy (pre-hardening) item; other errors are propagated

    // The item exists: reading it would merely require authentication, or is currently
    // blocked by an enrollment invalidation (handled at read time as not-found).
    if (status == errSecInteractionNotAllowed || status == errSecAuthFailed)
        return StatusSuccess;

    return convertStatus(status);
}

Keychain::Status Keychain::updateCredential(const QString &account, const QString &password)
{
    const auto status = hasCredential(account);

    if (status == Status::StatusNotFound) {
        return Status::StatusSuccess;
    }

    if (status != Status::StatusSuccess) {
        return status;
    }

    return saveCredential(account, password);
}
