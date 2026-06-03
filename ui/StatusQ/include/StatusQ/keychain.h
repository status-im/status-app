#pragma once

#include <QObject>
#include <QFuture>

#ifdef __OBJC__
@class LAContext;
#else
class LAContext;
#endif

class Keychain : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString service READ service WRITE setService NOTIFY serviceChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit Keychain(QObject *parent = nullptr);
    ~Keychain() override;

    enum Status {
        StatusSuccess = 0,
        StatusNotSupported,
        StatusGenericError,
        StatusUnavailable,
        StatusCancelled,
        StatusNotFound,
        StatusFallbackSelected,
    };

    Q_ENUM(Status)

    QString service() const;
    void setService(const QString &service);

    bool available() const;

    bool loading() const;

    Q_INVOKABLE Status saveCredential(const QString &account, const QString &password);
    Q_INVOKABLE Status deleteCredential(const QString &account);
    Q_INVOKABLE Status hasCredential(const QString &account) const;

    // updateCredential calls saveCredential(account, password) if this accounts already exists in Keychain
    // This wrapper can be used when password changes.
    // Returns StatusSuccess if the account is not found in Keychain,
    // otherwise returns the actual error of hasCredential or result of saveCredential.
    Q_INVOKABLE Status updateCredential(const QString &account, const QString &password);

    Q_INVOKABLE void requestGetCredential(const QString &reason, const QString &account);
    Q_INVOKABLE void cancelActiveRequest();

signals:
    void getCredentialRequestCompleted(Keychain::Status status, const QString &password);

    void serviceChanged();
    void reasonChanged();
    void loadingChanged();
    void availableChanged();

    void credentialSaved(const QString& account);
    void credentialDeleted(const QString& account);

private:
    QString m_service;
    bool m_loading = false;
    bool m_available = false;
    void setLoading(bool loading);

    QFuture<void> m_future;

#if defined(Q_OS_MACOS) || defined(Q_OS_IOS)
    LAContext *m_activeAuthContext;

    QMetaObject::Connection m_pendingActivationConn; // used to defer a credential request if the app is not active

    Status getCredential(const QString &reason, const QString &account, QString *out);
    void reevaluateAvailability();
#endif
};
