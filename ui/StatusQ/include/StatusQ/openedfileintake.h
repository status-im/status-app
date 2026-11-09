#ifndef STATUSQ_OPENED_FILE_INTAKE_H
#define STATUSQ_OPENED_FILE_INTAKE_H

#include <QString>
#include <QVariantMap>

#include <functional>

namespace Status::OpenedFileIntake
{
    // Files the OS hands to Status through "Open with". On iOS each arrives as
    // a file URL the app can read: the original under its security scope when
    // it is opened in place, otherwise a copy (an Inbox copy, or ours when the
    // scope does not start). Files that came before the receiver are passed to
    // it from the event loop. No-op where files arrive another way.
    void setReceiver(std::function<void(const QString &fileUrl, bool copied)> receiver);

    // What the platform knows of a file whose URL names no file Status can
    // check (an Android content:// URI), or that Status must not read: its
    // name, MIME type and whether it can be read.
    void describe(const QString &fileUrl, const QString &name, const QString &mimeType,
                  bool readable);

    // {name, mimeType, readable} of a described file, empty otherwise.
    QVariantMap description(const QString &fileUrl);

    void forget(const QString &fileUrl);

    // The Tab showing `openedFile` (a local path, or the URL of a described
    // file) is gone: end its scope, or delete its copy, and forget it.
    void release(const QString &openedFile);

    // What release() takes for a file handed over as `fileUrl`.
    QString releaseKey(const QString &fileUrl);
}

#endif // STATUSQ_OPENED_FILE_INTAKE_H
