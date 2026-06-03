#include "StatusQ/keychain.h"

#include <QCoreApplication>
#include <QString>

#include <QtCore/QJniObject>
#include <QtCore/qnativeinterface.h>
#include <QJniEnvironment>

extern "C" {
static void jni_nativeCredentialSaved(JNIEnv*, jobject, jboolean);
static void jni_nativeCredentialLoaded(JNIEnv*, jobject, jstring, jstring);
static void jni_nativeCredentialError(JNIEnv*, jobject, jint, jstring);
}

// We keep a single pointer to “the” Keychain that owns this state so JNI can reach it..
// If you expect multiple Keychain instances, replace this with a safer registry.
static Keychain* s_keychain = nullptr;

static constexpr const char* kJavaClass =
    "app/status/mobile/SecureAndroidAuthentication";

// Get the singleton Java object, creating it if needed.
// Never cache a raw jobject; pass the Context only for this call.
static QJniObject getJavaSingleton()
{
    // Qt 6.9+ returns a typed wrapper; convert to QJniObject or pull jobject
    QJniObject ctxObj = QNativeInterface::QAndroidApplication::context();
    if (!ctxObj.isValid()) {
        // Context not ready yet (too early in startup) → try again later
        return QJniObject();
    }

    QJniObject inst = QJniObject::callStaticObjectMethod(
        kJavaClass,
        "getInstance",
        "(Landroid/content/Context;)Lapp/status/mobile/SecureAndroidAuthentication;",
        ctxObj.object<jobject>() // pass a fresh Context for this call only
        );

    // If Java threw, clear it and return invalid (prevents stale refs lingering)
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return QJniObject();
    }

    return inst; // will hold a *global ref* if valid
}

// Ensure we have the Java singleton and register our natives exactly once.
static QJniObject ensureJavaAuth()
{
    static QJniObject   s_auth;     // cached singleton (Qt manages global ref)
    static std::once_flag regOnce;  // one-time native registration

    if (!s_auth.isValid()) {
        s_auth = getJavaSingleton();
        if (!s_auth.isValid()) return QJniObject(); // context not ready yet
    }

    // Capture a copy so the lambda can use it safely
    QJniObject auth = s_auth;

    std::call_once(regOnce, [auth]{
        QJniEnvironment env;
        jclass clazz = env->GetObjectClass(auth.object<jobject>());
        if (!clazz) return;

        // Register *instance* natives (non-static Java natives → jobject here)
        const JNINativeMethod methods[] = {
                                           { const_cast<char*>("nativeCredentialSaved"),
                                            const_cast<char*>("(Z)V"),
                                            reinterpret_cast<void*>(jni_nativeCredentialSaved) },

                                           { const_cast<char*>("nativeCredentialLoaded"),
                                            const_cast<char*>("(Ljava/lang/String;Ljava/lang/String;)V"),
                                            reinterpret_cast<void*>(jni_nativeCredentialLoaded) },

                                           { const_cast<char*>("nativeCredentialError"),
                                            const_cast<char*>("(ILjava/lang/String;)V"),
                                            reinterpret_cast<void*>(jni_nativeCredentialError) },
                                           };

        jint rc = env->RegisterNatives(clazz, methods, jint(std::size(methods)));
        env->DeleteLocalRef(clazz);

        if (rc != 0) {
            qWarning() << "[Keychain/Android] RegisterNatives failed:" << rc;
        }
    });

    return s_auth;
}

void setTitle(const QString &title)
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return;
    auth.callMethod<void>("setTitle",
                          "(Ljava/lang/String;)V",
                          QJniObject::fromString(title).object<jstring>()
                          );
}

void setDescription(const QString &description)
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return;

    auth.callMethod<void>("setDescription",
                          "(Ljava/lang/String;)V",
                          QJniObject::fromString(description).object<jstring>()
                          );
}

void setNegativeButton(const QString &negativeButton)
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return;

    auth.callMethod<void>("setNegativeButton",
                          "(Ljava/lang/String;)V",
                          QJniObject::fromString(negativeButton).object<jstring>()
                          );
}

Keychain::Keychain(QObject *parent)
    : QObject(parent)
{
    s_keychain = this; // NOTE: single-owner short-cut; replace with registry if needed.

    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return;

    // Configure the authentication prompt
    setTitle(tr("Authenticate"));
    setDescription(tr("Login to Status"));
    setNegativeButton(tr("Cancel"));
    auth.callMethod<void>("setAuthenticators",
                          "(I)V",
                          1 //BIOMETRIC_STRONG
                          );

    // Evaluate if the device supports biometric authentication
    const int res = auth.callMethod<jint>("canAuthenticate", "()I");
    bool avail = (res == 1); // 1 == BIOMETRIC_SUCCESS in our Java file
    if (m_available != avail) {
        m_available = avail;
        emit availableChanged();
    }
}

Keychain::~Keychain()
{
    // TODO: Clean up platform-specific resources here (if any).
    // e.g., release m_activeAuthContext on Apple platforms if you own it.
    cancelActiveRequest();
    if (s_keychain == this)
        s_keychain = nullptr;
    // m_future.waitForFinished();
}

bool Keychain::available() const
{
    return m_available;
}

Keychain::Status Keychain::saveCredential(const QString &account, const QString &password)
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return StatusGenericError;

    setTitle(tr("Save password"));
    setDescription(tr("Confirm to enable biometric login"));

    const bool ok = auth.callMethod<jboolean>(
        "beginSaveCredential",
        "(Ljava/lang/String;Ljava/lang/String;)Z",
        QJniObject::fromString(account).object<jstring>(),
        QJniObject::fromString(password).object<jstring>()
        );

    return ok ? StatusSuccess : StatusGenericError;
}

Keychain::Status Keychain::deleteCredential(const QString &account)
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return StatusGenericError;

    const jboolean ok = auth.callMethod<jboolean>(
        "deleteCredential", "(Ljava/lang/String;)Z",
        QJniObject::fromString(account).object<jstring>());


    if (ok) {
        QMetaObject::invokeMethod(s_keychain, [account]{
            emit s_keychain->credentialDeleted(account);
        }, Qt::QueuedConnection);
    }

    return ok ? StatusSuccess : StatusNotFound;
}

Keychain::Status Keychain::hasCredential(const QString& account) const
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return StatusGenericError;

    const jboolean ok = auth.callMethod<jboolean>(
        "hasCredential", "(Ljava/lang/String;)Z",
        QJniObject::fromString(account).object<jstring>());

    return ok ? StatusSuccess : StatusNotFound;
}

Keychain::Status Keychain::updateCredential(const QString &account, const QString &password)
{
    const Status exists = hasCredential(account);
    if (exists == StatusSuccess)
        return saveCredential(account, password);
    if (exists == StatusNotFound)
        return StatusSuccess;
    return exists;
}

void Keychain::requestGetCredential(const QString &reason, const QString &account)
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return;

    setTitle(tr("Authenticate"));
    setDescription(tr("Login to Status"));

    const bool ok = auth.callMethod<jboolean>(
        "beginGetCredential",
        "(Ljava/lang/String;)Z",
        QJniObject::fromString(account).object<jstring>()
        );
}

void Keychain::cancelActiveRequest()
{
    const QJniObject auth = ensureJavaAuth();
    if (!auth.isValid()) return;

    auth.callMethod<void>("cancel", "()V");
}

// Credential saved result (async)
// TODO send accoutn back from Java method
static void jni_nativeCredentialSaved(JNIEnv*, jobject, jboolean ok)
{
    if (!s_keychain) return;

    QMetaObject::invokeMethod(s_keychain, [ok]{
        emit s_keychain->credentialSaved("");
    }, Qt::QueuedConnection);
}

// Credential loaded result (async)
static void jni_nativeCredentialLoaded(JNIEnv*, jobject, jstring jAccount, jstring jSecret)
{
    if (!s_keychain) return;

    const QString secret  = jSecret ? QJniObject(jSecret).toString() : QString();

    QMetaObject::invokeMethod(s_keychain, [secret]{
        emit s_keychain->getCredentialRequestCompleted(Keychain::StatusSuccess, secret);
    }, Qt::QueuedConnection);
}

// Credential error (async)
static void jni_nativeCredentialError(JNIEnv*, jobject, jint code, jstring jMsg)
{
    if (!s_keychain) return;

    const QString msg = QJniObject(jMsg).toString();

    if (code == -11) { // "User cancelled"
        QMetaObject::invokeMethod(s_keychain, [msg]{
            emit s_keychain->getCredentialRequestCompleted(Keychain::StatusCancelled, QString());
        }, Qt::QueuedConnection);
        return;
    }

    QMetaObject::invokeMethod(s_keychain, [msg]{
        emit s_keychain->getCredentialRequestCompleted(Keychain::StatusGenericError, QString());
    }, Qt::QueuedConnection);
}
