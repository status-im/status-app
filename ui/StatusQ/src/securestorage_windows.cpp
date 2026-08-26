#include "StatusQ/securestorage.h"

#include <QCryptographicHash>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryFile>

#include <windows.h>

#include <wincrypt.h>

namespace {

// Blobs live in the LOCAL (non-roaming) per-user application data directory
// (AppData/Local). This must never be a roaming location: with roaming profiles both the
// blob and the DPAPI user key roam, so the credential would become decryptable on other
// machines — the auto-login credential is meant to be strictly device-local.
QString storageDir()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (base.isEmpty())
        return {};

    return base + QStringLiteral("/securestorage");
}

// File name derived from the item identity — no service/account material on disk.
QString blobPath(const QString &service, const QString &account)
{
    const QByteArray identity = (service + QLatin1Char('|') + account).toUtf8();
    const QByteArray name = QCryptographicHash::hash(identity, QCryptographicHash::Sha256).toHex();
    return storageDir() + QLatin1Char('/') + QString::fromLatin1(name) + QStringLiteral(".cred");
}

// Additional DPAPI entropy binds each blob to its (service, account) identity: a blob
// copied over another entry's file cannot be decrypted under that entry's identity, so it
// cannot be replayed as a different credential.
QByteArray entropyFor(const QString &service, const QString &account)
{
    const QByteArray identity = QByteArrayLiteral("StatusDesktop.securestorage.v1|")
                                + service.toUtf8() + '|' + account.toUtf8();
    return QCryptographicHash::hash(identity, QCryptographicHash::Sha256);
}

} // namespace

bool SecureStorage::available() const
{
    if (m_availableCache < 0) {
        // DPAPI itself is always present; availability only requires a writable per-user
        // data directory. Failures here are environmental and possibly transient — report
        // unavailable but do NOT cache the verdict, so a later call can retry.
        const QString dir = storageDir();
        if (dir.isEmpty()) {
            qWarning() << "SecureStorage: no writable application data location";
            return false;
        }
        if (!QDir().mkpath(dir)) {
            qWarning() << "SecureStorage: cannot create storage directory" << dir;
            return false;
        }
        // mkpath() also succeeds when the directory already exists, even if its ACLs or
        // filesystem state forbid creating files — prove actual write access before
        // caching the verdict.
        QTemporaryFile probe(dir + QStringLiteral("/probe-XXXXXX"));
        if (!probe.open()) {
            qWarning() << "SecureStorage: storage directory is not writable:" << probe.errorString();
            return false;
        }
        m_availableCache = 1;
    }

    return m_availableCache == 1;
}

SecureStorage::Status SecureStorage::setCredential(const QString &account, const QString &credential)
{
    if (!available())
        return StatusUnavailable;

    QByteArray plain = credential.toUtf8();
    QByteArray entropy = entropyFor(m_service, account);

    DATA_BLOB dataIn{static_cast<DWORD>(plain.size()), reinterpret_cast<BYTE *>(plain.data())};
    DATA_BLOB entropyIn{static_cast<DWORD>(entropy.size()), reinterpret_cast<BYTE *>(entropy.data())};
    DATA_BLOB dataOut{0, nullptr};

    // Current-user scope (no CRYPTPROTECT_LOCAL_MACHINE): only this Windows account can
    // decrypt. CRYPTPROTECT_UI_FORBIDDEN upholds the class contract of never prompting.
    const BOOL ok = CryptProtectData(&dataIn,
                                     L"Status Desktop credential",
                                     &entropyIn,
                                     nullptr,
                                     nullptr,
                                     CRYPTPROTECT_UI_FORBIDDEN,
                                     &dataOut);
    SecureZeroMemory(plain.data(), plain.size());

    if (!ok) {
        qWarning() << "SecureStorage: CryptProtectData failed, error=" << GetLastError();
        return StatusGenericError;
    }

    const QByteArray blob(reinterpret_cast<const char *>(dataOut.pbData),
                          static_cast<int>(dataOut.cbData));
    LocalFree(dataOut.pbData);

    QSaveFile file(blobPath(m_service, account));
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "SecureStorage: cannot open blob file for writing:" << file.errorString();
        return StatusGenericError;
    }
    if (file.write(blob) != blob.size() || !file.commit()) {
        qWarning() << "SecureStorage: writing blob file failed:" << file.errorString();
        return StatusGenericError;
    }

    return StatusSuccess;
}

SecureStorage::Status SecureStorage::deleteCredential(const QString &account)
{
    if (!available())
        return StatusUnavailable;

    QFile file(blobPath(m_service, account));
    if (!file.exists())
        return StatusNotFound;

    if (!file.remove()) {
        qWarning() << "SecureStorage: cannot remove blob file:" << file.errorString();
        return StatusGenericError;
    }

    return StatusSuccess;
}

SecureStorage::Status SecureStorage::hasCredential(const QString &account) const
{
    if (!available())
        return StatusUnavailable;

    return QFile::exists(blobPath(m_service, account)) ? StatusSuccess : StatusNotFound;
}

QVariantMap SecureStorage::getCredential(const QString &account) const
{
    QString credential;

    const auto result = [&credential](Status status) {
        return QVariantMap{{QStringLiteral("status"), static_cast<int>(status)},
                           {QStringLiteral("credential"), credential}};
    };

    if (!available())
        return result(StatusUnavailable);

    QFile file(blobPath(m_service, account));
    if (!file.exists())
        return result(StatusNotFound);

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "SecureStorage: cannot open blob file for reading:" << file.errorString();
        return result(StatusGenericError);
    }

    QByteArray blob = file.readAll();
    QByteArray entropy = entropyFor(m_service, account);

    DATA_BLOB dataIn{static_cast<DWORD>(blob.size()), reinterpret_cast<BYTE *>(blob.data())};
    DATA_BLOB entropyIn{static_cast<DWORD>(entropy.size()), reinterpret_cast<BYTE *>(entropy.data())};
    DATA_BLOB dataOut{0, nullptr};

    if (!CryptUnprotectData(&dataIn,
                            nullptr,
                            &entropyIn,
                            nullptr,
                            nullptr,
                            CRYPTPROTECT_UI_FORBIDDEN,
                            &dataOut)) {
        // Different Windows user, corrupted file, or a blob copied from another entry
        // (entropy mismatch) — unreadable either way.
        qWarning() << "SecureStorage: CryptUnprotectData failed, error=" << GetLastError();
        return result(StatusGenericError);
    }

    credential = QString::fromUtf8(reinterpret_cast<const char *>(dataOut.pbData),
                                   static_cast<int>(dataOut.cbData));
    SecureZeroMemory(dataOut.pbData, dataOut.cbData);
    LocalFree(dataOut.pbData);

    return result(StatusSuccess);
}
