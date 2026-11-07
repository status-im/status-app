#include "StatusQ/mediabackend.h"

#ifdef Q_OS_ANDROID
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QHash>
#include <QJniEnvironment>
#include <QJniObject>
#include <QLoggingCategory>
#include <QStandardPaths>

#include <dlfcn.h>
#include <jni.h>

#include <mutex>

namespace {
Q_LOGGING_CATEGORY(lcMedia, "status.media")

#if defined(__aarch64__)
constexpr auto abi = "arm64-v8a";
#elif defined(__arm__)
constexpr auto abi = "armeabi-v7a";
#elif defined(__x86_64__)
constexpr auto abi = "x86_64";
#else
constexpr auto abi = "x86";
#endif

// SoundPool needs a file: copy a qrc sound to the cache dir once per run
QString localSoundPath(const QUrl& source)
{
    static QHash<QUrl, QString> paths;
    if (auto it = paths.constFind(source); it != paths.cend())
        return *it;
    QString path;
    if (source.isLocalFile()) {
        path = source.toLocalFile();
    } else if (source.scheme() == QLatin1String("qrc")) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                + QStringLiteral("/sounds");
        QDir().mkpath(dir);
        path = dir + QLatin1Char('/') + source.fileName();
        QFile::remove(path);
        if (!QFile::copy(QLatin1Char(':') + source.path(), path)) {
            qCWarning(lcMedia) << "cannot extract" << source;
            path.clear();
        }
    }
    paths.insert(source, path);
    return path;
}

bool avcodecMapped()
{
    QFile maps(QStringLiteral("/proc/self/maps"));
    return maps.open(QIODevice::ReadOnly) && maps.readAll().contains("libavcodec.so");
}
} // namespace

void MediaBackend::ensureLoaded()
{
    static std::once_flag once;
    std::call_once(once, [] {
        QElapsedTimer timer;
        timer.start();
        const bool mappedBefore = avcodecMapped();
        const auto name = QByteArray("libplugins_multimedia_ffmpegmediaplugin_") + abi + ".so";
        void* handle = dlopen(name.constData(), RTLD_NOW);
        if (!handle) {
            qCWarning(lcMedia) << "dlopen" << name << "failed:" << dlerror();
            return;
        }
        using OnLoad = jint (*)(JavaVM*, void*);
        auto onLoad = reinterpret_cast<OnLoad>(dlsym(handle, "JNI_OnLoad"));
        QJniEnvironment env; // attaches this thread, JNI_OnLoad needs GetEnv to succeed
        const jint rc = onLoad ? onLoad(QJniEnvironment::javaVM(), nullptr) : JNI_ERR;
        qCInfo(lcMedia) << "ffmpeg backend loaded on first use in" << timer.elapsed() << "ms,"
                        << "JNI_OnLoad" << (rc == JNI_ERR ? "failed" : "ok")
                        << ", avcodec mapped before:" << mappedBefore;
    });
}
#else
void MediaBackend::ensureLoaded() {}
#endif

NativeSound::NativeSound(QObject* parent)
    : QObject(parent)
{}

#ifdef Q_OS_ANDROID
bool NativeSound::available() const
{
    return true;
}

void NativeSound::play(const QUrl& source, qreal volume)
{
    const QString path = localSoundPath(source);
    if (path.isEmpty())
        return;
    QJniObject::callStaticMethod<void>("app/status/mobile/SoundPlayer", "play",
                                       "(Ljava/lang/String;F)V",
                                       QJniObject::fromString(path).object<jstring>(),
                                       jfloat(volume));
}

void NativeSound::stop(const QUrl& source)
{
    const QString path = localSoundPath(source);
    if (path.isEmpty())
        return;
    QJniObject::callStaticMethod<void>("app/status/mobile/SoundPlayer", "stop",
                                       "(Ljava/lang/String;)V",
                                       QJniObject::fromString(path).object<jstring>());
}
#else
bool NativeSound::available() const
{
    return false;
}

void NativeSound::play(const QUrl&, qreal) {}

void NativeSound::stop(const QUrl&) {}
#endif

MediaBackendUtils::MediaBackendUtils(QObject* parent)
    : QObject(parent)
{}

void MediaBackendUtils::ensureLoaded() const
{
    MediaBackend::ensureLoaded();
}

MediaHost::MediaHost(QQuickItem* parent)
    : QQuickItem(parent)
{
    MediaBackend::ensureLoaded();
}
