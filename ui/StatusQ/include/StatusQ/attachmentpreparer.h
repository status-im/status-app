#pragma once

#include "StatusQ/imagepreparation.h"

#include <QHash>
#include <QJSValue>
#include <QList>
#include <QObject>
#include <QStringList>
#include <QThreadPool>

class QJSEngine;
class QQmlEngine;

// Prepares image Attachments in the background as soon as they are attached, so that sending
// only has to hand status-go a file it can pass through (see ImagePreparation and
// docs/adr/0008-client-side-image-preparation.md).
//
// Attachments are identified by their `source` as the chat input holds it (a file/content URL
// or a data: URI). Prepared files are written to a temporary directory. A file is deleted when
// its Attachment is removed (forget), or handed over to the send (release), which deletes it
// once status-go has read it. Files left behind (e.g. by a crash) are swept once stale.
class AttachmentPreparer : public QObject
{
    Q_OBJECT

public:
    explicit AttachmentPreparer(QObject* parent = nullptr);
    ~AttachmentPreparer() override;

    // Starts preparing `source` unless it is already prepared or in progress. `input` is the
    // local file path (resolved by UrlUtils.convertUrlToLocalPath) or the data: URI itself.
    Q_INVOKABLE void prepare(const QString& source, const QString& input);

    Q_INVOKABLE bool isPending(const QString& source) const;
    Q_INVOKABLE bool isRejected(const QString& source) const;
    Q_INVOKABLE QString rejectionReason(const QString& source) const;

    // What to send for `source`: the prepared file's path, or `fallback` when the source is
    // sent as it is (or wasn't prepared).
    Q_INVOKABLE QString resolve(const QString& source, const QString& fallback) const;

    // Calls `callback` once none of `sources` is being prepared (right away if none is).
    Q_INVOKABLE void whenPrepared(const QStringList& sources, const QJSValue& callback);

    // Drops the state of a removed Attachment and deletes its prepared file.
    Q_INVOKABLE void forget(const QString& source);

    // Drops the state of a sent Attachment, keeping its prepared file: the send owns it now
    // and deletes it once sent. Call after resolve().
    Q_INVOKABLE void release(const QString& source);

    // Where prepared files are written by default (the send deletes files found there).
    static QString defaultDirectory();

    // For tests.
    void setLimits(const ImagePreparation::Limits& limits);
    void setDirectory(const QString& directory);
    QString directory() const;
    bool waitForDone(int msecs = -1);

    static QObject* qmlInstance(QQmlEngine* engine, QJSEngine* scriptEngine);

signals:
    void started(const QString& source);
    void prepared(const QString& source);
    void rejected(const QString& source, const QString& reason);

private:
    enum class State { Pending, Ready, Rejected };

    struct Entry
    {
        State state = State::Pending;
        QString path; // prepared file, empty when sent as it is
        QString reason;
        quint64 generation = 0;
    };

    struct Waiter
    {
        QStringList sources;
        QJSValue callback;
    };

    void onFinished(const QString& source, quint64 generation, const QString& path,
                    ImagePreparation::Result::Reason reason, bool isRejected);
    void notifyWaiters();
    static QString reasonText(ImagePreparation::Result::Reason reason, const ImagePreparation::Limits& limits);

    QHash<QString, Entry> m_entries;
    QList<Waiter> m_waiters;
    ImagePreparation::Limits m_limits;
    QString m_directory;
    quint64 m_generation = 0;
    QThreadPool m_pool;
};
