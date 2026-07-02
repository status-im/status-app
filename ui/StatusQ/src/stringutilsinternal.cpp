#include "StatusQ/stringutilsinternal.h"

#include <QDebug>
#include <QFile>
#include <QSaveFile>
#include <QKeySequence>
#include <QUrl>
#include <QTextDocumentFragment>

StringUtilsInternal::StringUtilsInternal(QObject* parent) : QObject(parent)
{
}

QString StringUtilsInternal::escapeHtml(const QString& unsafe) const
{
    return unsafe.toHtmlEscaped();
}

QString StringUtilsInternal::readTextFile(const QString& filePath) const
{
    QString adjustedFilePath = filePath;
    if (adjustedFilePath.startsWith(QLatin1String("qrc:/")))
        adjustedFilePath.remove(0, qstrlen("qrc"));

    auto maybeFileUrl = QUrl::fromUserInput(adjustedFilePath);
    if (!maybeFileUrl.isLocalFile()) {
        qWarning() << Q_FUNC_INFO << "Error, opening remote files is not supported" << maybeFileUrl;
        return {};
    }

    QFile file(maybeFileUrl.toLocalFile()); // support local file URLs (e.g. "file:///foo/bar/baz.txt")
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << Q_FUNC_INFO << "Error opening existing file" << maybeFileUrl << "for reading";
        return {};
    }

    return file.readAll();
}

bool StringUtilsInternal::writeTextFile(const QString &filePath, const QString& data) const
{
    qWarning() << "!!! WRITING TO FILE:" << filePath << "; data:" << data;

    auto maybeFileUrl = QUrl::fromUserInput(filePath);
    if (!maybeFileUrl.isLocalFile()) {
        qWarning() << Q_FUNC_INFO << "Error, opening remote files is not supported" << maybeFileUrl;
        return false;
    }

    QSaveFile file(maybeFileUrl.toLocalFile());

    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        qWarning() << Q_FUNC_INFO << "Error opening file" << file.fileName() << "for writing";
        return false;
    }
    if (file.write(data.toUtf8()) == -1) {
        qWarning() << Q_FUNC_INFO << "Error writing to file" << file.fileName();
        return false;
    }
    if (!file.commit()) {
        qWarning() << Q_FUNC_INFO << "Error committing writing to file" << file.fileName();
        return false;
    }
    return true;
}

QString StringUtilsInternal::extractDomainFromLink(const QString& link) const
{
    const auto url = QUrl::fromUserInput(link);
    if (!url.isValid()) {
        qWarning() << Q_FUNC_INFO << "Invalid URL:" << link;
        return {};
    }
    return url.host();
}

QString StringUtilsInternal::plainText(const QString& htmlFragment) const
{
    return QTextDocumentFragment::fromHtml(htmlFragment).toPlainText();
}

static QKeySequence variantToKeySequence(const QVariant &var)
{
    if (var.metaType().id() == QMetaType::Int)
        return QKeySequence(static_cast<QKeySequence::StandardKey>(var.toInt()));
    return QKeySequence::fromString(var.toString());
}

QString StringUtilsInternal::shortcutToText(const QVariant &shortcut)
{
    const auto seq = variantToKeySequence(shortcut);

    if (seq.isEmpty())
        return {};
    return seq.toString(QKeySequence::NativeText);
}
