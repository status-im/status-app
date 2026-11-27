#ifndef STATUSQ_OPENED_FILE_INTAKE_H
#define STATUSQ_OPENED_FILE_INTAKE_H

#include <QString>

#include <functional>

namespace Status::OpenedFileIntake
{
    // Files the OS hands to Status through "Open with". On iOS each arrives as
    // a file URL the app can read: the original under its security scope when
    // it is opened in place, otherwise a copy (an Inbox copy, or ours when the
    // scope does not start). Files that came before the receiver are passed to
    // it from the event loop. No-op where files arrive another way.
    void setReceiver(std::function<void(const QString &fileUrl, bool copied)> receiver);

    // The Tab showing `localPath` is gone: end its scope, or delete its copy.
    void release(const QString &localPath);
}

#endif // STATUSQ_OPENED_FILE_INTAKE_H
