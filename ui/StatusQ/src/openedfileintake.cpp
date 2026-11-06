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
    descriptions().insert(keyOf(fileUrl), {name, mimeType, readable});
}

QVariantMap Status::OpenedFileIntake::description(const QString &fileUrl)
{
    QMutexLocker locker(&lock());
    const auto it = descriptions().constFind(keyOf(fileUrl));
    if (it == descriptions().constEnd())
        return {};
    return {{"name", it->name}, {"mimeType", it->mimeType}, {"readable", it->readable}};
}

void Status::OpenedFileIntake::forget(const QString &fileUrl)
{
    QMutexLocker locker(&lock());
    descriptions().remove(keyOf(fileUrl));
}
