#include "StatusQ/browsercertdistrust.h"

#include <QByteArray>
#include <QCryptographicHash>
#include <QSet>
#include <QSslKey>
#include <QString>

namespace {

// Chrome Root Store constraint override that disables trust in
// `emSign ECC Root CA - G3` (SHA-256: 86a1ecba...bbe6b), the root certificate
// above the eight compromised eMudhra G3 intermediate CAs disclosed in Oct 2026.
//
// TODO(QTBUG-58059): `--test-crs-constraints` is marked as a test-only switch
// in Chromium (`TrustStoreChrome::kTestCrsConstraintsSwitch`). Remove this
// workaround once Qt ships a `QtWebEngineCore` build that backports the
// upstream eMudhra SPKI blocklist / removes `emSign ECC Root CA - G3` from the
// compiled-in Chrome Root Store. Re-run https://github.com/friofry/qtwebengine-emudhra-repro
// whenever upgrading Qt to verify the switch (or native blocklist) still blocks
// chains anchored at `emSign ECC Root CA - G3`.
constexpr char kEmSignEccRootG3CrsConstraintFlag[] =
    "--test-crs-constraints=86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b:maxversionexclusive=0";

// Primary check: SHA-256 of SubjectPublicKeyInfo DER (lowercase hex) for the
// 8 compromised eMudhra G3 intermediate keys (matching Chromium's
// `net/cert/cert_verify_proc_blocklist.inc`) plus `emSign Root TLS CA - G3` and
// `emSign ECC Root CA - G3`. Matching by SPKI catches any re-issued or
// cross-signed certificate sharing the same key pair (e.g. both the self-signed
// and root-signed variants of `emSign Root TLS CA - G3`).
const QSet<QByteArray> &distrustedSpkiSha256Hex()
{
    static const QSet<QByteArray> kSet = {
        QByteArrayLiteral("49dd353dc2b919a3770645117d0e60c16115e7d1bc259eefe734b00ea434fe5f"), // EM DV TLS CA - G3C
        QByteArrayLiteral("ebed6475c2c2d80fcb199f3fe8dd6e6b3ce60b77eb15d4e42c3dec0c6f5b5105"), // EM DV TLS CA - G3B
        QByteArrayLiteral("5c0660a2b164910d8ff589c18e14552e9e0ec237dcefe2cb736d41a4811f81a0"), // EM EV TLS CA - G3C
        QByteArrayLiteral("92c063d67e8f14db71d288e11266ffdaf69cbf115f7bab14f3bc2f68d25e0e30"), // EM OV CS CA - G3C
        QByteArrayLiteral("43bffa19d6ef651451f6841e019931e96f6f2eaeff28ab4b6f1ce4576de2717b"), // EM OV TLS CA - G3B
        QByteArrayLiteral("ec4ffa1ad0ac88081314b7aaffef6a91f97cd57291bb5ba686c5415f5eb4f6b6"), // EM OV CS CA - G3B
        QByteArrayLiteral("63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8"), // EM OV TLS CA - G3C
        QByteArrayLiteral("e0254c7fcdc265e2f0f8a428dabb75ab4ae039b4872d62f5ee57f0877d5a8a41"), // EM EV TLS CA - G3B
        QByteArrayLiteral("c619e4780ed8e0abeda24ad732567de4383a7ea941338f6d1a7d1b49ac792fe9"), // emSign Root TLS CA - G3
        QByteArrayLiteral("8d417db2dd8bf5e3084d1e3f196d583849d81bdd4c00c70b9d39369e96b8c782"), // emSign ECC Root CA - G3
    };
    return kSet;
}

// Secondary check: exact certificate DER SHA-256 fingerprints (lowercase hex)
// from Chromium's `net/data/ssl/blocklist/` plus the cross-signed
// `emSign Root TLS CA - G3` and `emSign ECC Root CA - G3`.
const QSet<QByteArray> &distrustedCertSha256Hex()
{
    static const QSet<QByteArray> kSet = {
        QByteArrayLiteral("0164d7ceae5bb909c272af151ff44b1177ae9b47d9424b94f1d9558c30934d19"), // EM DV TLS CA - G3C
        QByteArrayLiteral("42c4accd12c4f59597925e1a08a7a90102608543809308d50ec427e118ba1493"), // EM DV TLS CA - G3B
        QByteArrayLiteral("432ec25f0d28de9006d97bf752f17bbb2cd41f669933fcb072d9a1148d0261f3"), // EM EV TLS CA - G3C
        QByteArrayLiteral("4b2460a466f95fd40113bcdcca2ceb29b3b093921de45474da7df48874c630b1"), // EM OV CS CA - G3C
        QByteArrayLiteral("98b896625c0c230adeec3eb2cf6aad5001ecf9156a68644e82374ce5833bc25b"), // EM OV TLS CA - G3B
        QByteArrayLiteral("9e39de2881273acc225a149c72ba3e0f51424963669ab633ee1dc7df5db067b4"), // EM OV CS CA - G3B
        QByteArrayLiteral("cb6e15165ac802e9b3f993f16c25d41f4e81c21ebde71ae1b012ac00bf9c7c3f"), // EM OV TLS CA - G3C
        QByteArrayLiteral("e7568fe6e12331f4fd7de61da4c7559d0f8eb192a218d4741a3ba75184333838"), // EM EV TLS CA - G3B
        QByteArrayLiteral("3094025792039a68af6e553686410bdab7c0d4a36b9084cba64202e35d6ebbdd"), // emSign Root TLS CA - G3
        QByteArrayLiteral("86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b"), // emSign ECC Root CA - G3
    };
    return kSet;
}

// Fallback check: CA Common Names for leaf-only handshakes where the server
// omits intermediate certificates from the TLS handshake (only the leaf's
// issuer CN is then visible in `error.certificateChain()`).
const QSet<QString> &distrustedCaCommonNames()
{
    static const QSet<QString> kNames = {
        QStringLiteral("emSign ECC Root CA - G3"),
        QStringLiteral("emSign Root TLS CA - G3"),
        QStringLiteral("emSign Root CS CA - G3"),
        QStringLiteral("EM DV TLS CA - G3B"),
        QStringLiteral("EM DV TLS CA - G3C"),
        QStringLiteral("EM OV TLS CA - G3B"),
        QStringLiteral("EM OV TLS CA - G3C"),
        QStringLiteral("EM EV TLS CA - G3B"),
        QStringLiteral("EM EV TLS CA - G3C"),
        QStringLiteral("EM OV CS CA - G3B"),
        QStringLiteral("EM OV CS CA - G3C"),
    };
    return kNames;
}

} // namespace

namespace BrowserCertDistrust {

void applyChromiumFlags()
{
    QByteArray flags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    const QByteArray constraintFlag(kEmSignEccRootG3CrsConstraintFlag);
    if (!flags.contains(constraintFlag)) {
        if (!flags.isEmpty() && !flags.endsWith(' '))
            flags.append(' ');
        flags.append(constraintFlag);
        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", flags);
    }
}

bool isCertificateChainDistrusted(const QList<QSslCertificate> &chain)
{
    const auto &spkiHashes = distrustedSpkiSha256Hex();
    const auto &certHashes = distrustedCertSha256Hex();
    const auto &caNames = distrustedCaCommonNames();

    for (const QSslCertificate &cert : chain) {
        if (cert.isNull())
            continue;

        const QByteArray spkiDer = cert.publicKey().toDer();
        if (!spkiDer.isEmpty()) {
            const QByteArray spkiSha256 =
                QCryptographicHash::hash(spkiDer, QCryptographicHash::Sha256).toHex();
            if (spkiHashes.contains(spkiSha256))
                return true;
        }

        const QByteArray certSha256 = cert.digest(QCryptographicHash::Sha256).toHex();
        if (certHashes.contains(certSha256))
            return true;

        const QStringList issuerCns = cert.issuerInfo(QSslCertificate::CommonName);
        for (const QString &cn : issuerCns) {
            if (caNames.contains(cn))
                return true;
        }

        const QStringList subjectCns = cert.subjectInfo(QSslCertificate::CommonName);
        for (const QString &cn : subjectCns) {
            if (caNames.contains(cn))
                return true;
        }
    }

    return false;
}

bool isDistrustedCertificateError(const QWebEngineCertificateError &error)
{
    return isCertificateChainDistrusted(error.certificateChain());
}

} // namespace BrowserCertDistrust
