#pragma once

#include <QObject>
#include <QVariantMap>

// Prompt-free platform secure storage for one credential per account.
//
// Unlike Keychain (asynchronous, gated by biometrics/user presence), every
// operation here is synchronous and never shows any system UI. Items are
// protected by the platform store itself (device unlock / OS user account),
// not by a per-read authentication — this is the storage behind features like
// "Stay logged in", where the credential must be readable silently at startup.
//
// Platform backends:
//  - macOS/iOS: Keychain item without access control (device-only accessibility)
//  - Windows:   DPAPI-protected blob (current user scope)
//  - Linux:     Secret Service (GNOME Keyring / KWallet) via libsecret
//  - Android:   Keystore-wrapped entry (no user-authentication requirement)
//
// Latency contract: operations are local and fast on macOS/iOS/Windows/Android. On Linux
// they cross D-Bus; each public call runs ONE worker-thread operation bounded by a single
// short deadline (~1.5s) — a broken Secret Service can stall a UI-thread caller for at
// most that deadline, never indefinitely. A timeout or unreachable service invalidates
// `available` and starts a backoff window during which reads fail fast (mutations, being
// user-initiated, still attempt). A timed-out mutation reports StatusIndeterminate — see
// the enum note. Callers on hot paths should gate on `available`.
class SecureStorage : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString service READ service WRITE setService NOTIFY serviceChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit SecureStorage(QObject *parent = nullptr);
    ~SecureStorage() override;

    enum Status {
        StatusSuccess = 0,
        StatusNotSupported,
        StatusGenericError,
        StatusUnavailable,
        StatusNotFound,

        // A mutation hit its deadline while possibly still in flight (Linux only): it MAY
        // or MAY NOT take effect. The backend rolls a late commit back on a best-effort
        // basis; callers must treat this as failure for UX purposes and reconcile the
        // stored state (hasCredential) before relying on it.
        StatusIndeterminate,
    };

    Q_ENUM(Status)

    QString service() const;
    void setService(const QString &service);

    bool available() const;

    Q_INVOKABLE Status setCredential(const QString &account, const QString &credential);

    // Returns StatusNotFound when nothing was stored for the account (callers
    // typically treat that the same as StatusSuccess).
    Q_INVOKABLE Status deleteCredential(const QString &account);

    Q_INVOKABLE Status hasCredential(const QString &account) const;

    // Returns {"status": Status, "credential": QString}. Synchronous, never prompts.
    Q_INVOKABLE QVariantMap getCredential(const QString &account) const;

signals:
    void serviceChanged();
    void availableChanged();

private:
    QString m_service;

    // Lazy availability probe result used by platform backends (-1 = not probed yet).
    mutable int m_availableCache = -1;
};
