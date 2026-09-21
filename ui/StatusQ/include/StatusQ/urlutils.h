#pragma once

#include <QObject>
#include <QMimeDatabase>

class UrlUtils : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString validImageNameFilters READ validImageNameFilters FINAL CONSTANT) // "*.jpg *.jpe *.jp *.jpeg *.png *.webp *.gif *.svg"
    Q_PROPERTY(QStringList validPreferredImageExtensions READ validPreferredImageExtensions FINAL CONSTANT) // ["jpg", "png", "webp", "gif", "svg"]
    Q_PROPERTY(QStringList allValidImageExtensions READ allValidImageExtensions FINAL CONSTANT) // ["jpg", "jpe", "jp", "jpeg", "png", "webp", "gif", "svg"]

public:
    explicit UrlUtils(QObject* parent = nullptr);

    Q_INVOKABLE bool isValidImageUrl(const QUrl &url) const;
    Q_INVOKABLE static qint64 getFileSize(const QUrl &url);

    Q_INVOKABLE QString convertUrlToLocalPath(const QString& url) const;
    Q_INVOKABLE QStringList convertUrlsToLocalPaths(const QStringList& urls) const;

    Q_INVOKABLE QUrl urlFromUserInput(const QString& input) const;

    // True for input addressing the device rather than the network: file: and,
    // on Android, content:. A scheme test only — nothing is resolved or opened.
    Q_INVOKABLE static bool isLocalUrl(const QString& input);

    // Returns a user-friendly label to show for a backup location.
    // On Android for SAF tree URIs (content://) this will map to a readable form like
    // "Internal storage/Documents/...". Otherwise returns a local path if applicable.
    Q_INVOKABLE QString displayPathLabel(const QString& path) const;

private:
    QMimeDatabase m_mimeDb;

    QStringList m_validImageMimeTypes{QStringLiteral("image/jpeg"),
                                      QStringLiteral("image/png"),
                                      QStringLiteral("image/gif"),
                                      QStringLiteral("image/svg")};

    // "*.jpg *.jpe *.jp *.jpeg *.png *.webp *.gif *.svg"
    QString m_imgFilters;
    QString validImageNameFilters() const { return m_imgFilters; }

    // ["jpg", "png", "webp", "gif", "svg"]
    QStringList m_imgExtensions;
    QStringList validPreferredImageExtensions() const { return m_imgExtensions; }

    // ["jpg", "jpe", "jp", "jpeg", "png", "webp", "gif", "svg"]
    QStringList m_allImgExtensions;
    QStringList allValidImageExtensions() const { return m_allImgExtensions; }

#ifdef Q_OS_ANDROID
    QString resolveAndroidContentUrl(const QString& urlPath) const;
#endif
};
