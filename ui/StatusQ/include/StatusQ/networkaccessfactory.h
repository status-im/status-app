#pragma once

#include <QNetworkRequest>
#include <QQmlNetworkAccessManagerFactory>
#include <QString>
#include <QtGlobal>

class QNetworkAccessManager;
class QQmlEngine;

namespace Status {

/*!
 * Returns \a request with an \c Accept header claiming the image formats Qt can
 * actually decode, or unchanged when the header does not apply.
 *
 * Cloudinary's \c f_auto picks a format from \c Accept; Qt image loading sends
 * none, so without this the delivery hints written by \c Utils.resizedMediaSource
 * come back as PNG (see docs/adr/0006-qt-http-cache.md). The list is
 * narrow on purpose: \c f_auto would otherwise return AVIF or JPEG XL, which Qt
 * decodes neither of. Scoped to the two Cloudinary delivery paths that carry those
 * hints — the same manager also serves status-go, XHR and everything else the QML
 * layer fetches.
 *
 * A request that already carries an \c Accept header is returned untouched: the
 * caller stated its own terms and they win.
 */
QNetworkRequest withAcceptedImageFormats(const QNetworkRequest& request);

/*!
 * Hands the QML engine network access managers that cache to disk and report
 * every reply to \c HttpStats.
 *
 * Every manager the factory creates shares one cache directory, so \a maxCacheSize
 * is the budget for the whole QML layer rather than a per-manager allowance.
 */
class NetworkAccessFactory : public QQmlNetworkAccessManagerFactory
{
public:
    NetworkAccessFactory(const QString& cacheDir, qint64 maxCacheSize);

    QNetworkAccessManager* create(QObject* parent) override;

private:
    QString m_cacheDir;
    qint64 m_maxCacheSize;
};

/*!
 * Installs a \c NetworkAccessFactory on \a engine. Call from the GUI thread,
 * before the engine loads anything.
 *
 * The factory must outlive the engine and is intentionally never deleted
 * (process lifetime, as in DOtherSide).
 */
void setupNetworkAccessManagerFactory(QQmlEngine* engine, const QString& cacheDir,
                                      qint64 maxCacheSize);

} // namespace Status
