#pragma once

#include <QHash>
#include <QMutex>
#include <QObject>
#include <QString>

// The Read Grants of the local-preview Tabs (ADR 0006 §8): each view may reach
// one file, or a directory holding what it shows, for as long as the view
// lives. Written on the UI thread and read on whichever thread WebEngine
// intercepts requests on.
class BrowserLocalFileGrants final : public QObject
{
public:
    explicit BrowserLocalFileGrants(QObject *parent = nullptr);

    // Replaces `view`'s grant with `localPath`; it ends when `view` is destroyed.
    void grant(QObject *view, const QString &localPath);

    // Whether a live grant is `localPath` or a directory above it.
    bool covers(const QString &localPath) const;

    // Symlinks resolved as far as the path exists, so /var and /private/var
    // compare equal; the part that does not exist yet is only cleaned.
    static QString canonicalPath(const QString &path);
    // `path` lies below `dir`; "/a/Downloads-evil" is not below "/a/Downloads".
    static bool isUnder(const QString &path, const QString &dir);

private:
    void revoke(QObject *view);

    mutable QMutex m_mutex;
    QHash<QObject *, QString> m_grants;
};
