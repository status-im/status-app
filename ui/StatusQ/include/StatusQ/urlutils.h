#pragma once

#include <QObject>
#include <QMimeDatabase>

class UrlUtils : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString validImageNameFilters READ validImageNameFilters FINAL CONSTANT) // "*.jpg *.jpe *.jp *.jpeg *.png *.webp *.gif"
    Q_PROPERTY(QStringList validPreferredImageExtensions READ validPreferredImageExtensions FINAL CONSTANT) // ["jpg", "png", "webp", "gif"]
    Q_PROPERTY(QStringList allValidImageExtensions READ allValidImageExtensions FINAL CONSTANT) // ["jpg", "jpe", "jp", "jpeg", "png", "webp", "gif"]
    // Chat Attachments additionally accept SVG, which is rasterised before sending (AttachmentPreparer)
    Q_PROPERTY(QString validChatImageNameFilters READ validChatImageNameFilters FINAL CONSTANT)
    Q_PROPERTY(QStringList validChatPreferredImageExtensions READ validChatPreferredImageExtensions FINAL CONSTANT)

public:
    explicit UrlUtils(QObject* parent = nullptr);

    Q_INVOKABLE bool isValidImageUrl(const QUrl &url) const;
    Q_INVOKABLE bool isValidChatImageUrl(const QUrl &url) const;
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

    struct ImageTypes
    {
        QStringList mimeTypes;
        QString nameFilters;           // "*.jpg *.jpe *.jp *.jpeg *.png *.webp *.gif" (+ uppercase)
        QStringList preferredSuffixes; // ["jpg", "png", "webp", "gif"]
        QStringList allSuffixes;       // ["jpg", "jpe", "jp", "jpeg", "png", "webp", "gif"]
    };
    ImageTypes makeImageTypes(const QStringList& mimeTypes) const;
    bool isValidImageUrl(const QUrl& url, const ImageTypes& types) const;

    // Images status-go can decode (webp only when Qt can display it)
    ImageTypes m_imageTypes;
    // + SVG, which only chat Attachments accept (rasterised by AttachmentPreparer)
    ImageTypes m_chatImageTypes;

    QString validImageNameFilters() const { return m_imageTypes.nameFilters; }
    QStringList validPreferredImageExtensions() const { return m_imageTypes.preferredSuffixes; }
    QStringList allValidImageExtensions() const { return m_imageTypes.allSuffixes; }
    QString validChatImageNameFilters() const { return m_chatImageTypes.nameFilters; }
    QStringList validChatPreferredImageExtensions() const { return m_chatImageTypes.preferredSuffixes; }

#ifdef Q_OS_ANDROID
    QString resolveAndroidContentUrl(const QString& urlPath) const;
#endif
};
