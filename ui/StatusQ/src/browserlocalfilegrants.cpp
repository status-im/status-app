#include "StatusQ/browserlocalfilegrants.h"

#include <QDir>
#include <QFileInfo>
#include <QMutexLocker>

BrowserLocalFileGrants::BrowserLocalFileGrants(QObject *parent)
    : QObject(parent)
{
}

void BrowserLocalFileGrants::grant(QObject *view, const QString &localPath)
{
    const QString path = canonicalPath(localPath);
    if (!view || path.isEmpty())
        return;

    QMutexLocker locker(&m_mutex);
    const bool watched = m_grants.contains(view);
    m_grants.insert(view, path);
    locker.unlock();

    if (!watched)
        connect(view, &QObject::destroyed, this, [this, view] { revoke(view); });
}

void BrowserLocalFileGrants::revoke(QObject *view)
{
    QMutexLocker locker(&m_mutex);
    m_grants.remove(view);
}

bool BrowserLocalFileGrants::covers(const QString &localPath) const
{
    const QString path = canonicalPath(localPath);
    if (path.isEmpty())
        return false;

    QMutexLocker locker(&m_mutex);
    for (const QString &granted : m_grants)
        if (path == granted || isUnder(path, granted))
            return true;
    return false;
}

QString BrowserLocalFileGrants::canonicalPath(const QString &path)
{
    if (path.isEmpty())
        return {};
    const QString cleaned = QDir::cleanPath(QDir(path).absolutePath());
    QString existing = cleaned;
    QString rest;
    while (!QFileInfo::exists(existing)) {
        const qsizetype slash = existing.lastIndexOf(QLatin1Char('/'));
        if (slash <= 0)
            return cleaned;
        rest.prepend(existing.mid(slash));
        existing.truncate(slash);
    }
    const QString canonical = QFileInfo(existing).canonicalFilePath();
    return canonical.isEmpty() ? cleaned : canonical + rest;
}

bool BrowserLocalFileGrants::isUnder(const QString &path, const QString &dir)
{
    return !dir.isEmpty() && path.startsWith(dir + QLatin1Char('/'));
}
