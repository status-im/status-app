#include <StatusQ/browsercertdistrust.h>
#include <StatusQ/browserprofileutils.h>

#include <QByteArray>
#include <QSslCertificate>
#include <QTest>

namespace {

// Public certificate for `emSign ECC Root CA - G3` (from the Chrome Root Store).
constexpr char kEmSignEccRootG3Pem[] =
    "-----BEGIN CERTIFICATE-----\n"
    "MIICTjCCAdOgAwIBAgIKPPYHqWhwDtqLhDAKBggqhkjOPQQDAzBrMQswCQYDVQQG\n"
    "EwJJTjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNo\n"
    "bm9sb2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0g\n"
    "RzMwHhcNMTgwMjE4MTgzMDAwWhcNNDMwMjE4MTgzMDAwWjBrMQswCQYDVQQGEwJJ\n"
    "TjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNobm9s\n"
    "b2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0gRzMw\n"
    "djAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3iAhKAnjlfSU2fySU0\n"
    "WXTsuwYc58Byr+iuL+FBVIcUqEqy6HyC5ltqtdyzdc6LBtCGI79G1Y4PPwT01xyS\n"
    "fvalY8L1X44uT6EYGQIrMgqCZH0Wk9GjQjBAMB0GA1UdDgQWBBR8XQKEE9TMipuB\n"
    "zhccLikenEhjQjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAKBggq\n"
    "hkjOPQQDAwNpADBmAjEAvvNhzwIQHWSVB7gYboiFBS+DCBeQyh+KTOgNG3qxrdWB\n"
    "CUfvO6wIBHxcmbHtRwfSAjEAnbpV/KlK6O3t5nYBQnvI+GDZjVGLVTv7jHvrZQnD\n"
    "+JbNR6iC8hZVdyR+EhCVBCyj\n"
    "-----END CERTIFICATE-----\n";

// Public certificate for the compromised `EM OV TLS CA - G3C` intermediate
// (from Chromium's `net/data/ssl/blocklist/cb6e15165ac802e9b3f993f16c25d41f4e81c21ebde71ae1b012ac00bf9c7c3f.pem`).
constexpr char kCompromisedEmOvTlsCaG3CPem[] =
    "-----BEGIN CERTIFICATE-----\n"
    "MIIDaDCCAu6gAwIBAgIPKWkmwiejoVJjkrGUgqUEMAoGCCqGSM49BAMDMFYxCzAJ\n"
    "BgNVBAYTAklOMSUwIwYDVQQKDBxlTXVkaHJhIFRlY2hub2xvZ2llcyBMaW1pdGVk\n"
    "MSAwHgYDVQQDDBdlbVNpZ24gUm9vdCBUTFMgQ0EgLSBHMzAeFw0yNTA0MzAxNTM3\n"
    "NDFaFw00MDA0MjgxODMwMDBaMEAxCzAJBgNVBAYTAlVTMRQwEgYDVQQKDAtlTXVk\n"
    "aHJhIEluYzEbMBkGA1UEAwwSRU0gT1YgVExTIENBIC0gRzNDMHYwEAYHKoZIzj0C\n"
    "AQYFK4EEACIDYgAEE4JRzVKskpjByKrZdzId65fnCb0LTKCspV3IrVHc/J0ViaFZ\n"
    "fjpRIOHv1jHGPhg1ysrimGmmLhYx6KKBgatWYW3EXZGKvAnzqw5jz3kqpNztc4e+\n"
    "N7ulaVSfHAKycO1no4IBljCCAZIwHwYDVR0jBBgwFoAU4TqrIXzx401UrtRyt/2L\n"
    "WUIgkFQwHQYDVR0OBBYEFDTq6gzryQra+dDF4u2beMmHnhtsMB0GA1UdJQQWMBQG\n"
    "CCsGAQUFBwMBBggrBgEFBQcDAjBdBgNVHSAEVjBUMDkGCysGAQQBg44hAQABMCow\n"
    "KAYIKwYBBQUHAgEWHGh0dHA6Ly9yZXBvc2l0b3J5LmVtc2lnbi5jb20wDQYLKwYB\n"
    "BAGDjiEBAm4wCAYGZ4EMAQICMHUGCCsGAQUFBwEBBGkwZzAkBggrBgEFBQcwAYYY\n"
    "aHR0cDovL29jc3AtYy5lbXNpZ24uY29tMD8GCCsGAQUFBzAChjNodHRwOi8vcmVw\n"
    "b3NpdG9yeS5lbXNpZ24uY29tL2NlcnRzL0VNT1ZUTFNDQUczQy5wN2MwNwYDVR0f\n"
    "BDAwLjAsoCqgKIYmaHR0cDovL2NybC5lbXNpZ24uY29tLz9yb290dGxzY2FnMy5j\n"
    "cmwwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwCgYIKoZIzj0E\n"
    "AwMDaAAwZQIxAMSZt2xsPeumRdeSMSQ3CbzIZeQ/q7GDCWfeE1Pq+mhgA6gRM44c\n"
    "NVF3xJ+wsxJk+wIwFJbaDMokD8Ei6eNOiA8yUMYvfzQyngmrhZQMdPCK1SewrR79\n"
    "4rSb9vGqxZzelQth\n"
    "-----END CERTIFICATE-----\n";

// Synthetic certificate carrying the exact SPKI of `EM OV TLS CA - G3C`
// (`63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8`),
// but with neutral Subject/Issuer CNs (`Neutral Subject CA` / `Neutral Issuer CA`)
// and a distinct DER fingerprint — isolates the primary SPKI hash check.
constexpr char kSameSpkiNeutralCnPem[] =
    "-----BEGIN CERTIFICATE-----\n"
    "MIIBRDCB66ADAgECAgMBhp8wCgYIKoZIzj0EAwIwHDEaMBgGA1UEAwwRTmV1dHJh\n"
    "bCBJc3N1ZXIgQ0EwHhcNMjYwMTAxMDAwMDAwWhcNMzUxMjMwMDAwMDAwWjAdMRsw\n"
    "GQYDVQQDDBJOZXV0cmFsIFN1YmplY3QgQ0EwdjAQBgcqhkjOPQIBBgUrgQQAIgNi\n"
    "AAQTglHNUqySmMHIqtl3Mh3rl+cJvQtMoKylXcitUdz8nRWJoVl+OlEg4e/WMcY+\n"
    "GDXKyuKYaaYuFjHoooGBq1ZhbcRdkYq8CfOrDmPPeSqk3O1zh743u6VpVJ8cArJw\n"
    "7WcwCgYIKoZIzj0EAwIDSAAwRQIhAMDfGJDq75ZiO6L6ieAu4M8Q1fTlKaNOzLMh\n"
    "NPoPss4EAiAjIWh9i3fd6wdTVB0c8GbsrKbsOoDwqzBi3VY6WHwjOQ==\n"
    "-----END CERTIFICATE-----\n";

// Synthetic leaf certificate signed with a throwaway random key whose issuer is
// `CN=EM OV TLS CA - G3C` (simulating a leaf-only TLS handshake where the
// server omits intermediate certificates).
constexpr char kLeafIssuedByCompromisedIntermediatePem[] =
    "-----BEGIN CERTIFICATE-----\n"
    "MIIBJDCBy6ADAgECAgECMAoGCCqGSM49BAMCMB0xGzAZBgNVBAMMEkVNIE9WIFRM\n"
    "UyBDQSAtIEczQzAeFw0yNjAxMDEwMDAwMDBaFw0zNTEyMzAwMDAwMDBaMBsxGTAX\n"
    "BgNVBAMMEGxlYWYuZXhhbXBsZS5vcmcwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNC\n"
    "AARGtCBSuZIqw23gSDy2WxJSrRJZEMghO5Htftgd9HcE94Ol7Ko1Ya0xLh55lAGx\n"
    "OsOHlYX/+qAUb3MhdY7OiyHxMAoGCCqGSM49BAMCA0gAMEUCICYycRTB/cFu5nAr\n"
    "zAWwzdkSh2fYAKYxBR7gqi35l0qTAiEApDGtweVF2dGU5jFnGs81XiJuTLN40XPc\n"
    "aWM9yJV/K9s=\n"
    "-----END CERTIFICATE-----\n";

// Unrelated test certificate (`CN=example.org`, issuer `CN=Example Test Root CA`).
constexpr char kBenignCertPem[] =
    "-----BEGIN CERTIFICATE-----\n"
    "MIIBIjCByKADAgECAgEBMAoGCCqGSM49BAMCMB8xHTAbBgNVBAMMFEV4YW1wbGUg\n"
    "VGVzdCBSb290IENBMB4XDTI2MDEwMTAwMDAwMFoXDTM1MTIzMDAwMDAwMFowFjEU\n"
    "MBIGA1UEAwwLZXhhbXBsZS5vcmcwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAS6\n"
    "KK0YeD91uXvvU44RlmiX6u7rV5wrpiGbQtQRiHRDPGvf6Lea4F+48DCbtEUh6rGW\n"
    "C+AYNjnCh0xP0U+2wJHkMAoGCCqGSM49BAMCA0kAMEYCIQD+jbTDuuQnohEC0shc\n"
    "c2Z7d7H9lcYdYwFbQg7ewUjHSQIhAIpTraBEjtS5Kl7y+8fDhwA3MIg87UFC3xTo\n"
    "Gme6ohgp\n"
    "-----END CERTIFICATE-----\n";

constexpr char kExpectedCrsFlag[] =
    "--test-crs-constraints=86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b:maxversionexclusive=0";

} // namespace

class tst_BrowserCertDistrust : public QObject
{
    Q_OBJECT

private slots:
    void applyChromiumCertDistrustFlags_populatesEmptyEnvAndIsIdempotent()
    {
        const QByteArray savedFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
        qunsetenv("QTWEBENGINE_CHROMIUM_FLAGS");

        BrowserCertDistrust::applyChromiumFlags();
        const QByteArray first = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
        QCOMPARE(first, QByteArray(kExpectedCrsFlag));

        // Second call must not duplicate the switch.
        BrowserCertDistrust::applyChromiumFlags();
        QCOMPARE(qgetenv("QTWEBENGINE_CHROMIUM_FLAGS"), first);

        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", savedFlags);
    }

    void applyChromiumCertDistrustFlags_preservesExistingSwitches()
    {
        const QByteArray savedFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-seccomp-filter-sandbox");

        BrowserCertDistrust::applyChromiumFlags();
        const QByteArray flags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
        QVERIFY(flags.contains("--disable-seccomp-filter-sandbox"));
        QVERIFY(flags.contains(kExpectedCrsFlag));

        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", savedFlags);
    }

    void isCertificateChainDistrusted_detectsSpkiFingerprintAndCnFallback()
    {
        QVERIFY(!BrowserCertDistrust::isCertificateChainDistrusted({}));

        BrowserProfileUtils utils;
        QVERIFY(!utils.isDistrustedCertificateError(QWebEngineCertificateError()));

        const auto benign = QSslCertificate::fromData(QByteArray(kBenignCertPem));
        QCOMPARE(benign.size(), 1);
        QVERIFY(!BrowserCertDistrust::isCertificateChainDistrusted(benign));

        // 1. Root certificate (matches SPKI, DER SHA-256, and CN).
        const auto emSignRoot = QSslCertificate::fromData(QByteArray(kEmSignEccRootG3Pem));
        QCOMPARE(emSignRoot.size(), 1);
        QVERIFY(BrowserCertDistrust::isCertificateChainDistrusted(emSignRoot));

        // 2. Real compromised intermediate `EM OV TLS CA - G3C` (matches SPKI and DER SHA-256).
        const auto realIntermediate =
            QSslCertificate::fromData(QByteArray(kCompromisedEmOvTlsCaG3CPem));
        QCOMPARE(realIntermediate.size(), 1);
        QVERIFY(BrowserCertDistrust::isCertificateChainDistrusted(realIntermediate));

        // 3. Re-issued cert with compromised SPKI but neutral CNs and different DER hash
        //    (proves the primary SPKI check fires independently of CN and cert fingerprint).
        const auto sameSpkiNeutralCn =
            QSslCertificate::fromData(QByteArray(kSameSpkiNeutralCnPem));
        QCOMPARE(sameSpkiNeutralCn.size(), 1);
        QVERIFY(BrowserCertDistrust::isCertificateChainDistrusted(sameSpkiNeutralCn));

        // 4. Leaf-only handshake with random key and compromised issuer CN.
        const auto leafFromCompromisedCa =
            QSslCertificate::fromData(QByteArray(kLeafIssuedByCompromisedIntermediatePem));
        QCOMPARE(leafFromCompromisedCa.size(), 1);
        QVERIFY(BrowserCertDistrust::isCertificateChainDistrusted(leafFromCompromisedCa));
    }
};

QTEST_MAIN(tst_BrowserCertDistrust)
#include "tst_browsercertdistrust.moc"
