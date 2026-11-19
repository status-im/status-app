#include <StatusQ/openedfileintake.h>

#include <QHash>
#include <QMutex>
#include <QMutexLocker>
#include <QUrl>

namespace {

struct Description
{
    QString name;
    QString mimeType;
    bool readable = false;
    int tabs = 1;
};

// Described from the Android UI thread, read from the Qt thread.
QMutex &lock()
{
    static QMutex mutex;
    return mutex;
}

QHash<QString, Description> &descriptions()
{
    static QHash<QString, Description> map;
    return map;
}

// The same URL as JNI hands it over and as QUrl prints it.
QString keyOf(const QString &fileUrl)
{
    return QUrl(fileUrl).toString(QUrl::FullyEncoded);
}

} // namespace

void Status::OpenedFileIntake::describe(const QString &fileUrl, const QString &name,
                                        const QString &mimeType, bool readable)
{
    QMutexLocker locker(&lock());
    const auto it = descriptions().find(keyOf(fileUrl));
    const int tabs = it == descriptions().end() ? 1 : it->tabs + 1;
    descriptions().insert(keyOf(fileUrl), {name, mimeType, readable, tabs});
}

QVariantMap Status::OpenedFileIntake::description(const QString &fileUrl)
{
    QMutexLocker locker(&lock());
    const auto it = descriptions().constFind(keyOf(fileUrl));
    if (it == descriptions().constEnd())
        return {};
    return {{"name", it->name}, {"mimeType", it->mimeType}, {"readable", it->readable}};
}

QString Status::OpenedFileIntake::releaseKey(const QString &fileUrl)
{
    if (!description(fileUrl).isEmpty())
        return fileUrl;
    return QUrl(fileUrl).toLocalFile();
}

void Status::OpenedFileIntake::forget(const QString &fileUrl)
{
    QMutexLocker locker(&lock());
    const auto it = descriptions().find(keyOf(fileUrl));
    if (it != descriptions().end() && --it->tabs == 0)
        descriptions().erase(it);
}
