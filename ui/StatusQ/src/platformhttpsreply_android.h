#pragma once

#include <QNetworkRequest>
#include <QString>

class QNetworkReply;
class QObject;

namespace Status {

// GETs an https URL through Android's own TLS stack (HttpURLConnection), so the UI process
// never loads OpenSSL. The platform response cache replaces QNetworkDiskCache for these.
QNetworkReply* createPlatformHttpsReply(const QNetworkRequest& request, QObject* parent);
void installPlatformHttpsCache(const QString& cacheDir, qint64 maxCacheSize);

} // namespace Status
