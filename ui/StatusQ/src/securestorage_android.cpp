#include "StatusQ/securestorage.h"

#include <QCoreApplication>
#include <QDebug>

#include <QJniEnvironment>
#include <QtCore/QJniObject>
#include <QtCore/qnativeinterface.h>

// JNI bridge to app.status.mobile.SecureStorageHelper: an AndroidKeyStore AES/GCM key
// generated with setUserAuthenticationRequired(false) wraps the credential, so — unlike
// the Keychain/SecureAndroidAuthentication pair — every call here is synchronous, never
// shows a BiometricPrompt, and needs no native callbacks.

static constexpr const char *kJavaClass = "app/status/mobile/SecureStorageHelper";

// Status codes of SecureStorageHelper (kept in sync with the Java side). The Java layer
// never conflates absence with failure: STATUS_NOT_FOUND is only returned for genuine
// absence or corruption whose cleanup verifiably succeeded.
static constexpr jint kStatusOk = 0;
static constexpr jint kStatusNotFound = 1;

static SecureStorage::Status convertStatus(jint status)
{
    switch (status) {
    case kStatusOk:
        return SecureStorage::StatusSuccess;
    case kStatusNotFound:
        return SecureStorage::StatusNotFound;
    default:
        return SecureStorage::StatusGenericError;
    }
}

// Get the singleton Java helper. Never cache a raw jobject; the Context is passed for
// this call only (same pattern as keychain_android.cpp).
static QJniObject javaHelper()
{
    QJniObject ctxObj = QNativeInterface::QAndroidApplication::context();
    if (!ctxObj.isValid()) {
        // Context not ready yet (too early in startup) — callers report unavailable and
        // may retry later.
        return QJniObject();
    }

    QJniObject inst = QJniObject::callStaticObjectMethod(
        kJavaClass,
        "getInstance",
        "(Landroid/content/Context;)Lapp/status/mobile/SecureStorageHelper;",
        ctxObj.object<jobject>());

    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return QJniObject();
    }

    return inst;
}

// The Java side catches everything, but guard the JNI boundary anyway: a pending Java
// exception poisons every subsequent JNI call.
static bool javaExceptionRaised()
{
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return true;
    }
    return false;
}

bool SecureStorage::available() const
{
    const QJniObject helper = javaHelper();
    if (!helper.isValid())
        return false; // not cached — the Context may simply not be ready yet

    if (m_availableCache < 0) {
        const jboolean usable = helper.callMethod<jboolean>("isAvailable", "()Z");
        if (javaExceptionRaised() || !usable)
            return false; // not cached — Keystore hiccups can be transient

        m_availableCache = 1;
    }

    return m_availableCache == 1;
}

SecureStorage::Status SecureStorage::setCredential(const QString &account, const QString &credential)
{
    const QJniObject helper = javaHelper();
    if (!helper.isValid())
        return StatusUnavailable;

    const jint status = helper.callMethod<jint>(
        "setCredential",
        "(Ljava/lang/String;Ljava/lang/String;)I",
        QJniObject::fromString(account).object<jstring>(),
        QJniObject::fromString(credential).object<jstring>());

    if (javaExceptionRaised())
        return StatusGenericError;

    if (status != kStatusOk)
        qWarning() << "SecureStorage: setCredential failed, code=" << status;

    return convertStatus(status);
}

SecureStorage::Status SecureStorage::deleteCredential(const QString &account)
{
    const QJniObject helper = javaHelper();
    if (!helper.isValid())
        return StatusUnavailable;

    const jint status = helper.callMethod<jint>(
        "deleteCredential",
        "(Ljava/lang/String;)I",
        QJniObject::fromString(account).object<jstring>());

    if (javaExceptionRaised())
        return StatusGenericError;

    if (status != kStatusOk && status != kStatusNotFound)
        qWarning() << "SecureStorage: deleteCredential failed, code=" << status;

    return convertStatus(status);
}

SecureStorage::Status SecureStorage::hasCredential(const QString &account) const
{
    const QJniObject helper = javaHelper();
    if (!helper.isValid())
        return StatusUnavailable;

    const jint status = helper.callMethod<jint>(
        "hasCredential",
        "(Ljava/lang/String;)I",
        QJniObject::fromString(account).object<jstring>());

    if (javaExceptionRaised())
        return StatusGenericError;

    return convertStatus(status);
}

QVariantMap SecureStorage::getCredential(const QString &account) const
{
    QString credential;

    const auto result = [&credential](Status status) {
        return QVariantMap{{QStringLiteral("status"), static_cast<int>(status)},
                           {QStringLiteral("credential"), credential}};
    };

    const QJniObject helper = javaHelper();
    if (!helper.isValid())
        return result(StatusUnavailable);

    // The secret travels through a String[1] out-array so the explicit status code and
    // the value arrive together — absence, cleaned-up corruption (NotFound) and backend
    // failure (GenericError) stay distinguishable.
    QJniEnvironment env;
    jclass stringClass = env->FindClass("java/lang/String");
    if (stringClass == nullptr || javaExceptionRaised())
        return result(StatusGenericError);

    jobjectArray outArray = env->NewObjectArray(1, stringClass, nullptr);
    env->DeleteLocalRef(stringClass);
    if (outArray == nullptr || javaExceptionRaised())
        return result(StatusGenericError);

    const jint status = helper.callMethod<jint>(
        "getCredential",
        "(Ljava/lang/String;[Ljava/lang/String;)I",
        QJniObject::fromString(account).object<jstring>(),
        outArray);

    if (javaExceptionRaised()) {
        env->DeleteLocalRef(outArray);
        return result(StatusGenericError);
    }

    bool hasValue = false;
    if (status == kStatusOk) {
        jstring secret = static_cast<jstring>(env->GetObjectArrayElement(outArray, 0));
        if (secret != nullptr) {
            credential = QJniObject(secret).toString();
            env->DeleteLocalRef(secret);
            hasValue = true;
        }
    }

    env->DeleteLocalRef(outArray);

    if (status == kStatusOk && !hasValue) {
        qWarning() << "SecureStorage: getCredential reported success without a value";
        return result(StatusGenericError);
    }

    return result(convertStatus(status));
}
