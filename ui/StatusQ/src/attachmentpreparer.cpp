#include "StatusQ/attachmentpreparer.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJSEngine>
#include <QPointer>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QUuid>

namespace {

constexpr auto dataUrlBase64Marker = ";base64,";
constexpr qint64 staleFileAgeSecs = 60 * 60;

QByteArray readInput(const QString& input)
{
    if (input.startsWith(QLatin1String("data:"))) {
        const auto idx = input.indexOf(QLatin1String(dataUrlBase64Marker));
        if (idx < 0)
            return {};
        return QByteArray::fromBase64(input.mid(idx + int(qstrlen(dataUrlBase64Marker))).toLatin1());
    }
    QFile file(input);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return file.readAll();
}

QString suffixFor(const QByteArray& format)
{
    if (format == "jpeg")
        return QStringLiteral("jpg");
    if (format.isEmpty())
        return QStringLiteral("img");
    return QString::fromLatin1(format);
}

void sweepStaleFiles(const QString& directory)
{
    const QDir dir(directory);
    const auto cutoff = QDateTime::currentDateTime().addSecs(-staleFileAgeSecs);
    const auto files = dir.entryInfoList(QDir::Files);
    for (const auto& file : files) {
        if (file.lastModified() < cutoff)
            QFile::remove(file.absoluteFilePath());
    }
}

} // namespace

AttachmentPreparer::AttachmentPreparer(QObject* parent)
    : QObject(parent)
{
    setDirectory(QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                 + QStringLiteral("/status-attachments"));
}

AttachmentPreparer::~AttachmentPreparer()
{
    m_pool.clear();
    m_pool.waitForDone();
}

void AttachmentPreparer::setLimits(const ImagePreparation::Limits& limits)
{
    m_limits = limits;
}

void AttachmentPreparer::setDirectory(const QString& directory)
{
    m_directory = directory;
    QDir().mkpath(m_directory);
    sweepStaleFiles(m_directory);
}

QString AttachmentPreparer::directory() const
{
    return m_directory;
}

bool AttachmentPreparer::waitForDone(int msecs)
{
    return m_pool.waitForDone(msecs);
}

void AttachmentPreparer::prepare(const QString& source, const QString& input)
{
    if (source.isEmpty() || m_entries.contains(source))
        return;

    const auto generation = ++m_generation;
    m_entries.insert(source, Entry{State::Pending, {}, {}, generation});
    emit started(source);

    const QPointer<AttachmentPreparer> self(this);
    const auto limits = m_limits;
    const auto directory = m_directory;
    const bool isDataUrl = input.startsWith(QLatin1String("data:"));

    m_pool.start([self, source, input, generation, limits, directory, isDataUrl] {
        const auto bytes = readInput(input);
        auto result = bytes.isEmpty() ? ImagePreparation::Result{} : ImagePreparation::prepare(bytes, limits);

        QString path;
        const bool rejected = result.kind == ImagePreparation::Result::Kind::Rejected;
        // A data: URI sent as it is still needs a file: writing its bytes keeps them as they are.
        const bool writeOriginal = result.kind == ImagePreparation::Result::Kind::Original
                                   && isDataUrl && !bytes.isEmpty();
        if (result.kind == ImagePreparation::Result::Kind::Prepared || writeOriginal) {
            path = directory + QLatin1Char('/') + QUuid::createUuid().toString(QUuid::WithoutBraces)
                   + QLatin1Char('.') + suffixFor(result.suffix);
            QFile file(path);
            if (!file.open(QIODevice::WriteOnly)
                || file.write(writeOriginal ? bytes : result.data) < 0) {
                qWarning() << "AttachmentPreparer: cannot write" << path << file.errorString();
                path.clear(); // fall back to sending the source
            }
        }

        QMetaObject::invokeMethod(self, [self, source, generation, path, reason = result.reason, rejected] {
            if (self)
                self->onFinished(source, generation, path, reason, rejected);
        }, Qt::QueuedConnection);
    });
}

void AttachmentPreparer::onFinished(const QString& source, quint64 generation, const QString& path,
                                    ImagePreparation::Result::Reason reason, bool isRejected)
{
    auto it = m_entries.find(source);
    if (it == m_entries.end() || it->generation != generation) {
        if (!path.isEmpty())
            QFile::remove(path); // forgotten while being prepared
        return;
    }

    if (isRejected) {
        it->state = State::Rejected;
        it->reason = reasonText(reason, m_limits);
        notifyWaiters();
        emit rejected(source, it->reason);
        return;
    }

    it->state = State::Ready;
    it->path = path;
    notifyWaiters();
    emit prepared(source);
}

bool AttachmentPreparer::isPending(const QString& source) const
{
    const auto it = m_entries.constFind(source);
    return it != m_entries.cend() && it->state == State::Pending;
}

bool AttachmentPreparer::isRejected(const QString& source) const
{
    const auto it = m_entries.constFind(source);
    return it != m_entries.cend() && it->state == State::Rejected;
}

QString AttachmentPreparer::rejectionReason(const QString& source) const
{
    const auto it = m_entries.constFind(source);
    return it != m_entries.cend() ? it->reason : QString();
}

QString AttachmentPreparer::resolve(const QString& source, const QString& fallback) const
{
    const auto it = m_entries.constFind(source);
    if (it != m_entries.cend() && it->state == State::Ready && !it->path.isEmpty())
        return it->path;
    return fallback;
}

void AttachmentPreparer::whenPrepared(const QStringList& sources, const QJSValue& callback)
{
    m_waiters.append(Waiter{sources, callback});
    notifyWaiters();
}

void AttachmentPreparer::forget(const QString& source)
{
    m_entries.remove(source);
    notifyWaiters(); // a waiter may have been waiting for it
}

void AttachmentPreparer::notifyWaiters()
{
    QList<Waiter> ready;
    for (auto it = m_waiters.begin(); it != m_waiters.end();) {
        const bool pending = std::any_of(it->sources.cbegin(), it->sources.cend(),
                                         [this](const QString& s) { return isPending(s); });
        if (pending) {
            ++it;
            continue;
        }
        ready.append(*it);
        it = m_waiters.erase(it);
    }
    for (auto& waiter : ready) {
        if (waiter.callback.isCallable()) {
            const auto result = waiter.callback.call();
            if (result.isError())
                qWarning() << "AttachmentPreparer: whenPrepared callback failed:" << result.toString();
        }
    }
}

QString AttachmentPreparer::reasonText(ImagePreparation::Result::Reason reason,
                                       const ImagePreparation::Limits& limits)
{
    switch (reason) {
    case ImagePreparation::Result::Reason::AnimationTooLarge:
        return tr("Animated images can be at most %1 KB and %2 px").arg(limits.maxBytes / 1000).arg(limits.longSide);
    case ImagePreparation::Result::Reason::Unreadable:
        return tr("This image can't be sent");
    case ImagePreparation::Result::Reason::None:
        break;
    }
    return {};
}

QObject* AttachmentPreparer::qmlInstance(QQmlEngine* engine, QJSEngine*)
{
    return new AttachmentPreparer(engine);
}
