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
    // We still create an access control object even if it's not added to the query (left commented below),
    // to keep parity with macOS and make it easy to enable later.
    #if TARGET_OS_OSX
        auto flags = kSecAccessControlBiometryCurrentSet | kSecAccessControlOr | kSecAccessControlWatch;
    #else
        auto flags = kSecAccessControlBiometryCurrentSet;
    #endif

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

    NSDictionary *query = @{
        (__bridge id) kSecClass: (__bridge id) kSecClassGenericPassword,
        (__bridge id) kSecAttrService: m_service.toNSString(),
        (__bridge id) kSecAttrAccount: account.toNSString(),
        (__bridge id) kSecValueData: [password.toNSString() dataUsingEncoding:NSUTF8StringEncoding],
        // (__bridge id)kSecAttrAccessControl: (__bridge id)accessControl, // enable if you want Keychain to enforce biometrics

    };

    SecItemDelete((__bridge CFDictionaryRef) query);                  // Ensure old item is removed
    auto status = SecItemAdd((__bridge CFDictionaryRef) query, NULL); // Add item

    CFRelease(accessControl);
    if (status == errSecSuccess) {
        emit credentialSaved(account);
    }

    return convertStatus(status);
}

Keychain::Status Keychain::deleteCredential(const QString &account)
{
    NSDictionary *query = @{
        (__bridge id) kSecClass: (__bridge id) kSecClassGenericPassword,
        (__bridge id) kSecAttrService: m_service.toNSString(),
        (__bridge id) kSecAttrAccount: account.toNSString(),
    };
    const auto status = SecItemDelete((__bridge CFDictionaryRef) query);
    if (status == errSecSuccess) {
        emit credentialDeleted(account);
    }

    return convertStatus(status);
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

    NSDictionary *query = @{
        (__bridge id) kSecClass: (__bridge id) kSecClassGenericPassword,
        (__bridge id) kSecAttrService: m_service.toNSString(),
        (__bridge id) kSecAttrAccount: account.toNSString(),
        (__bridge id) kSecReturnData: @YES,
        (__bridge id) kSecMatchLimit: (__bridge id) kSecMatchLimitOne,
        (__bridge id) kSecUseAuthenticationContext: m_activeAuthContext,
    };

    // Use the LAContext with Keychain when available. iOS 11+/macOS 10.13+ support kSecUseAuthenticationContext.
    #if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000) || \
        (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 101300)
        NSMutableDictionary *mutableQuery = [query mutableCopy];
        mutableQuery[(__bridge id)kSecUseAuthenticationContext] = m_activeAuthContext;
        query = mutableQuery;
    #endif

    CFDataRef data = NULL;

    const auto status = SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef *) &data);

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
    NSDictionary *query = @{
        (__bridge id) kSecClass: (__bridge id) kSecClassGenericPassword,
        (__bridge id) kSecAttrService: m_service.toNSString(),
        (__bridge id) kSecAttrAccount: account.toNSString(),
        (__bridge id) kSecReturnData: @NO,
        (__bridge id) kSecReturnAttributes: @YES,
        (__bridge id) kSecMatchLimit: (__bridge id) kSecMatchLimitOne,
    };

    const auto status = SecItemCopyMatching((__bridge CFDictionaryRef) query, nil);
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
