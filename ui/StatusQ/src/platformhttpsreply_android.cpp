#include "platformhttpsreply_android.h"

#include <QHash>
#include <QJniEnvironment>
#include <QJniObject>
#include <QMutex>
#include <QNetworkReply>
#include <QPointer>

#include <jni.h>

namespace Status {

namespace {

constexpr auto JavaClass = "app/status/mobile/PlatformHttps";

// A GET answered by PlatformHttps.java; the whole body arrives at once
class PlatformHttpsReply : public QNetworkReply
{
public:
    PlatformHttpsReply(const QNetworkRequest& request, QObject* parent);
    ~PlatformHttpsReply() override;

    void complete(int status, const QString& contentType, const QByteArray& body,
                  const QString& message);

    void abort() override;
    qint64 bytesAvailable() const override
    {
        return m_body.size() - m_pos + QNetworkReply::bytesAvailable();
    }
    bool isSequential() const override { return true; }

protected:
    qint64 readData(char* data, qint64 maxSize) override;

private:
    qint64 m_id;
    QByteArray m_body;
    qint64 m_pos = 0;
};

QMutex s_mutex;
QHash<qint64, PlatformHttpsReply*> s_replies;
qint64 s_nextId = 1;

void nativeFinished(JNIEnv* env, jclass, jlong id, jint status, jstring contentType, jbyteArray body,
                    jstring error)
{
    QByteArray bytes;
    if (body) {
        bytes.resize(env->GetArrayLength(body));
        env->GetByteArrayRegion(body, 0, bytes.size(), reinterpret_cast<jbyte*>(bytes.data()));
    }
    const QString type = contentType ? QJniObject(contentType).toString() : QString();
    const QString message = error ? QJniObject(error).toString() : QString();

    // Posted under the lock, so a reply being destroyed concurrently drops the event
    QMutexLocker lock(&s_mutex);
    if (auto* reply = s_replies.value(id))
        QMetaObject::invokeMethod(
            reply, [reply, status, type, bytes, message] { reply->complete(status, type, bytes, message); },
            Qt::QueuedConnection);
}

void registerNatives()
{
    static const bool registered = [] {
        const JNINativeMethod methods[] = {
            {"nativeFinished", "(JILjava/lang/String;[BLjava/lang/String;)V",
             reinterpret_cast<void*>(nativeFinished)}};
        QJniEnvironment env;
        return env.registerNativeMethods(JavaClass, methods, 1);
    }();
    Q_UNUSED(registered)
}

PlatformHttpsReply::PlatformHttpsReply(const QNetworkRequest& request, QObject* parent)
    : QNetworkReply(parent)
{
    setRequest(request);
    setUrl(request.url());
    setOperation(QNetworkAccessManager::GetOperation);
    open(QIODevice::ReadOnly);

    {
        QMutexLocker lock(&s_mutex);
        m_id = s_nextId++;
        s_replies.insert(m_id, this);
    }
    QJniObject::callStaticMethod<void>(
        JavaClass, "fetch", "(JLjava/lang/String;Ljava/lang/String;)V", jlong(m_id),
        QJniObject::fromString(request.url().toString(QUrl::FullyEncoded)).object<jstring>(),
        QJniObject::fromString(QString::fromLatin1(request.rawHeader("Accept"))).object<jstring>());
}

PlatformHttpsReply::~PlatformHttpsReply()
{
    QMutexLocker lock(&s_mutex);
    s_replies.remove(m_id);
}

void PlatformHttpsReply::complete(int status, const QString& contentType, const QByteArray& body,
                                  const QString& message)
{
    if (isFinished())
        return;

    if (status > 0) {
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, status);
        if (!contentType.isEmpty())
            setHeader(QNetworkRequest::ContentTypeHeader, contentType);
        setHeader(QNetworkRequest::ContentLengthHeader, body.size());
        m_body = body;
    }

    if (status <= 0)
        setError(UnknownNetworkError, message);
    else if (status == 404)
        setError(ContentNotFoundError, QStringLiteral("HTTP %1").arg(status));
    else if (status >= 400)
        setError(UnknownContentError, QStringLiteral("HTTP %1").arg(status));

    setFinished(true);
    emit metaDataChanged();
    if (!m_body.isEmpty()) {
        emit downloadProgress(m_body.size(), m_body.size());
        emit readyRead();
    }
    if (error() != NoError)
        emit errorOccurred(error());
    emit finished();
}

void PlatformHttpsReply::abort()
{
    if (isFinished())
        return;
    setError(OperationCanceledError, QStringLiteral("Operation canceled"));
    setFinished(true);
    emit errorOccurred(OperationCanceledError);
    emit finished();
}

qint64 PlatformHttpsReply::readData(char* data, qint64 maxSize)
{
    const qint64 n = qMin(maxSize, m_body.size() - m_pos);
    if (n <= 0)
        return isFinished() ? -1 : 0;
    memcpy(data, m_body.constData() + m_pos, n);
    m_pos += n;
    return n;
}

} // namespace

void installPlatformHttpsCache(const QString& cacheDir, qint64 maxCacheSize)
{
    QJniObject::callStaticMethod<void>(JavaClass, "installCache", "(Ljava/lang/String;J)V",
                                       QJniObject::fromString(cacheDir).object<jstring>(),
                                       jlong(maxCacheSize));
}

QNetworkReply* createPlatformHttpsReply(const QNetworkRequest& request, QObject* parent)
{
    registerNatives();
    return new PlatformHttpsReply(request, parent);
}

} // namespace Status
