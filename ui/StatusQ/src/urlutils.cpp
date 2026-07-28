#include "StatusQ/urlutils.h"
#include "StatusQ/safutils.h"
#include <cstdlib>

#include <QDir>
#include <QFile>
#include <QImageReader>
#include <QStandardPaths>
#include <QUrl>

#ifdef Q_OS_IOS
#include "ios_utils.h"
#endif

namespace {
constexpr auto webpMime = "image/webp";
}

UrlUtils::UrlUtils(QObject *parent): QObject(parent) {
    const auto webpSupported = QImageReader::supportedMimeTypes().contains(webpMime);
    if (webpSupported)
        m_validImageMimeTypes.append(webpMime);

    QStringList imgFilters;
    for (const auto& mime: std::as_const(m_validImageMimeTypes)) {
        const auto mimeData = m_mimeDb.mimeTypeForName(mime);
        imgFilters.append(mimeData.globPatterns());
        m_imgExtensions.append(mimeData.preferredSuffix());
        m_allImgExtensions.append(mimeData.suffixes());
    }

    m_imgFilters = imgFilters.join(' ');
    m_imgFilters.append(QStringLiteral(" "));
    m_imgFilters.append(m_imgFilters.toUpper()); // include the uppercase extensions too for case sensitive file systems
}

bool UrlUtils::isValidImageUrl(const QUrl &url) const
{
    const auto urlEndsWithSupportedExtension = [&](const QString& url) {
        const auto suffix = url.mid(url.lastIndexOf('.')+1);
        if (suffix.isEmpty())
            return false;
        return m_allImgExtensions.contains(suffix, Qt::CaseInsensitive);
    };

    // don't convert "content:/" like URLs to an empty path
    const auto filePath = url.isLocalFile() ? url.toLocalFile() : url.toString();

    if (url.scheme().startsWith(QLatin1String("http"))) // truly remote URLs, not virtual like Android content://
        return urlEndsWithSupportedExtension(filePath); // QMimeDatabase::mimeTypeForUrl(url) returns 'application/octet-stream'

    const auto mimeType = m_mimeDb.mimeTypeForFile(filePath, QMimeDatabase::MatchContent).name();

    return m_validImageMimeTypes.contains(mimeType);
}

qint64 UrlUtils::getFileSize(const QUrl& url)
{
    // don't convert "content:/" like URLs to an empty path
    const auto filePath = url.isLocalFile() ? url.toLocalFile() : url.toString();
    return QFile(filePath).size(); // will return 0 for unknown file paths
}

QString UrlUtils::convertUrlToLocalPath(const QString &url) const {
#ifdef Q_OS_ANDROID
    return resolveAndroidContentUrl(url);
#endif

    const auto localFileOrUrl = urlFromUserInput(url); // accept both "file:/foo/bar" and "/foo/bar"
    if (localFileOrUrl.isLocalFile()) {
#ifdef Q_OS_IOS
        return resolveIOSPhotoAsset(localFileOrUrl.toLocalFile());
#endif
        return localFileOrUrl.toLocalFile();
    }
    return {};
}

#ifdef Q_OS_ANDROID
QString UrlUtils::resolveAndroidContentUrl(const QString& urlPath) const {
    // test if we already have a real (resolved) path
    if (urlPath.startsWith('/'))
        return urlPath;

    // test if we already have a real (resolved) path in URL form
    if (urlPath.startsWith(QStringLiteral("file:/")))
        return urlFromUserInput(urlPath).toLocalFile();

    QDir dir(urlPath);
    if (urlPath.endsWith('/') || dir.exists())
        return urlPath; // a directory, just return it

    QFile fileIn(urlPath);
    if (!fileIn.open(QIODevice::ReadOnly))
        return urlPath;

    // save to a temp file, and return the filepath
    const auto newFilePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + '/' + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QFile fileOut(newFilePath);
    if (!fileOut.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return urlPath;
    if (fileOut.write(fileIn.readAll()) != -1)
        return fileOut.fileName(); // return the real filename, not the virtual "content:/" URI

    return urlPath;
}
#endif

QStringList UrlUtils::convertUrlsToLocalPaths(const QStringList &urls) const {
    QStringList result;
    for (const auto& url: urls) {
        const auto localPath = convertUrlToLocalPath(url);
        if (!localPath.isEmpty())
            result << localPath;
    }
    return result;
}

QUrl UrlUtils::urlFromUserInput(const QString &input) const
{
    return QUrl::fromUserInput(input);
}

QString UrlUtils::displayPathLabel(const QString& path) const
{
    if (path.isEmpty())
        return QString();

#ifdef Q_OS_ANDROID
    // Handle cases where a content URI gets wrapped inside a file URL/path, e.g.:
    // "file:///data/.../content:/com.android.externalstorage.documents/tree/primary%3ADocuments%2FBackups"
    int contentIdx = path.indexOf(QLatin1String("content:"));
    if (contentIdx >= 0) {
        QString content = path.mid(contentIdx); // e.g. "content:/com.android.externalstorage.documents/tree/primary%3ADocuments%2FBackups"

        // Normalize to content://
        if (content.startsWith(QLatin1String("content:/")) && !content.startsWith(QLatin1String("content://"))) {
            content = QLatin1String("content://") + content.mid(9); // skip "content:/"
        }

        // First, try to produce a friendly label locally by parsing the tree docId
        const int treePos = content.indexOf(QLatin1String("/tree/"));
        if (treePos > 0) {
            const QString docIdEnc = content.mid(treePos + 6); // after "/tree/"
            const QString docId = QUrl::fromPercentEncoding(docIdEnc.toUtf8()); // e.g. "primary:Documents/patate"

            const int colon = docId.indexOf(':');
            const QString volume = colon >= 0 ? docId.left(colon) : QString();
            QString relPath = colon >= 0 ? docId.mid(colon + 1) : docId;
            while (relPath.startsWith('/')) relPath.remove(0, 1);

            QString volLabel;
            if (volume.compare(QLatin1String("primary"), Qt::CaseInsensitive) == 0)
                volLabel = tr("Internal storage");
            else if (!volume.isEmpty())
                volLabel = tr("SD card");
            else
                volLabel = tr("Storage");

            return relPath.isEmpty() ? volLabel : volLabel + QLatin1Char('/') + relPath;
        }

        // Fallback to Java helper if present
        const char* c = statusq_saf_getReadableTreePath(content.toUtf8().constData());
        if (c) {
            QString s = QString::fromUtf8(c);
            delete [] c;
            if (!s.isEmpty()) return s;
        }
        // Fallback to showing the normalized content URI
        return content;
    }

    // Native content:// (not wrapped)
    if (path.startsWith(QLatin1String("content://"))) {
        // Try local parse first
        const int treePos = path.indexOf(QLatin1String("/tree/"));
        if (treePos > 0) {
            const QString docIdEnc = path.mid(treePos + 6);
            const QString docId = QUrl::fromPercentEncoding(docIdEnc.toUtf8());
            const int colon = docId.indexOf(':');
            const QString volume = colon >= 0 ? docId.left(colon) : QString();
            QString relPath = colon >= 0 ? docId.mid(colon + 1) : docId;
            while (relPath.startsWith('/')) relPath.remove(0, 1);
            QString volLabel;
            if (volume.compare(QLatin1String("primary"), Qt::CaseInsensitive) == 0)
                volLabel = QLatin1String("Internal storage");
            else if (!volume.isEmpty())
                volLabel = QLatin1String("SD card");
            else
                volLabel = QLatin1String("Storage");
            return relPath.isEmpty() ? volLabel : volLabel + QLatin1Char('/') + relPath;
        }

        const char* c = statusq_saf_getReadableTreePath(path.toUtf8().constData());
        if (c) {
            QString s = QString::fromUtf8(c);
            delete [] c;
            if (!s.isEmpty()) return s;
        }
        return path;
    }
#endif

    // Desktop and non-SAF: show a local filesystem path if possible
    // Don't call urlFromUserInput on paths that are already absolute file paths
    if (path.startsWith('/') || path.startsWith(QLatin1String("file://"))) {
        QUrl url(path);
        if (url.isLocalFile())
            return url.toLocalFile();
        return path;
    }

    const auto localFileOrUrl = urlFromUserInput(path);
    if (localFileOrUrl.isLocalFile())
        return localFileOrUrl.toLocalFile();
    return path;
}
