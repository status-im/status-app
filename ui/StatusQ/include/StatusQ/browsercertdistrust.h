#pragma once

#include <QList>
#include <QSslCertificate>

#include <QtWebEngineCore/QWebEngineCertificateError>

// Certificate-distrust policy for the desktop browser (Qt WebEngine).
namespace BrowserCertDistrust {

void applyChromiumFlags();
bool isCertificateChainDistrusted(const QList<QSslCertificate> &chain);
bool isDistrustedCertificateError(const QWebEngineCertificateError &error);

} // namespace BrowserCertDistrust
