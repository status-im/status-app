#include "StatusQ/systemutilsinternal.h"

#include <QDesktopServices>
#include <QGuiApplication>
#include <QMimeDatabase>
#include <QDir>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSslError>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QDebug>
#include <QMetaObject>
#include <mutex>

#ifdef Q_OS_ANDROID
#include <QFile>
#include <QJniObject>
#include <QJniEnvironment>
#include <QtCore/qnativeinterface.h>
#endif

#ifdef Q_OS_IOS
#include "ios_utils.h"
#endif

class QuitFilter : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    bool eventFilter(QObject* obj, QEvent* ev) override
    {
        if (ev->type() == QEvent::Quit)
            emit quit(ev->spontaneous());

        return false;
    }

signals:
    void quit(bool spontaneous);
};

static SystemUtilsInternal* s_systemUtilsInternal = nullptr;

#ifdef Q_OS_IOS
static void iosShakeDetected();
#endif

#ifdef Q_OS_ANDROID
extern "C" {
static void jni_nativeShakeDetected(JNIEnv*, jclass);
}
#endif

SystemUtilsInternal::SystemUtilsInternal(QObject *parent)
    : QObject{parent}
{
    s_systemUtilsInternal = this;
    auto app = QCoreApplication::instance();
    auto filter = new QuitFilter(this);
    app->installEventFilter(filter);

    QObject::connect(filter, &QuitFilter::quit, this, &SystemUtilsInternal::quit);

#ifdef Q_OS_ANDROID
    // Poll keyboard state on Android and emit property change signals
    auto keyboardTimer = new QTimer(this);
    keyboardTimer->setInterval(50); // 20 FPS polling rate
    QObject::connect(keyboardTimer, &QTimer::timeout, this, [this]() {
        // Get the Android activity
        auto activity = QNativeInterface::QAndroidApplication::context();
        
        int height = QJniObject::callStaticMethod<jint>(
            "app/status/mobile/KeyboardUtil",
            "getKeyboardHeight",
            "(Landroid/app/Activity;)I",
            activity.object()
        );
        bool visible = QJniObject::callStaticMethod<jboolean>(
            "app/status/mobile/KeyboardUtil",
            "isKeyboardVisible",
            "(Landroid/app/Activity;)Z",
            activity.object()
        );
        
        if (m_androidKeyboardHeight != height) {
            m_androidKeyboardHeight = height;
            emit androidKeyboardHeightChanged();
        }
        
        if (m_androidKeyboardVisible != visible) {
            m_androidKeyboardVisible = visible;
            emit androidKeyboardVisibleChanged();
        }
    });
    keyboardTimer->start();
#endif

#ifdef Q_OS_IOS
    // Set up iOS keyboard tracking
    ::setupIOSKeyboardTracking();
    
    // Poll iOS keyboard state and emit property change signals
    m_iosKeyboardPollTimer = new QTimer(this);
    m_iosKeyboardPollTimer->setInterval(50); // 20 FPS polling rate
    QObject::connect(m_iosKeyboardPollTimer, &QTimer::timeout, this, [this]() {
        int height = ::getIOSKeyboardHeight();
        bool visible = ::isIOSKeyboardVisible();
        
        if (m_iosKeyboardHeight != height) {
            m_iosKeyboardHeight = height;
            emit iosKeyboardHeightChanged();
        }
        
        if (m_iosKeyboardVisible != visible) {
            m_iosKeyboardVisible = visible;
            emit iosKeyboardVisibleChanged();
        }
    });
    m_iosKeyboardPollTimer->start();

#endif
}

QString SystemUtilsInternal::qtRuntimeVersion() const {
    return qVersion();
}

void SystemUtilsInternal::restartApplication() const
{
#if QT_CONFIG(process)
    QProcess::startDetached(QCoreApplication::applicationFilePath(), {});
#endif
    QMetaObject::invokeMethod(QCoreApplication::instance(), &QCoreApplication::exit, Qt::QueuedConnection, EXIT_SUCCESS);
}

void save(const QByteArray& imageData, const QString& targetDir)
{
    // Get current Date/Time information to use in naming of the image file
    const auto dateTimeString = QDateTime::currentDateTime().toString(
                QStringLiteral("yyyy-MM-dd_HH-mm-ss"));

    // Get the preferred extension
    QMimeDatabase mimeDb;
    auto ext = mimeDb.mimeTypeForData(imageData).preferredSuffix();
    if (ext.isEmpty())
        ext = QStringLiteral("jpg");

    // Construct the target path
    const auto targetFile = QStringLiteral("%1/image_%2.%3").arg(
                targetDir, dateTimeString, ext);

    if (!QDir().mkpath(targetDir)) {
        qWarning() << "SystemUtilsInternal::downloadImageByUrl: "
                      "Failed to create target directory:"
                   << targetDir;
        return;
    }

    // Save the image in a safe way
    QSaveFile image(targetFile);
    if (!image.open(QIODevice::WriteOnly)) {
        qWarning() << "SystemUtilsInternal::downloadImageByUrl: "
                        "Downloading image failed while opening the save file:"
                    << targetFile;
        return;
    }

    if (image.write(imageData) != -1)
        image.commit();
    else
        qWarning() << "SystemUtilsInternal::downloadImageByUrl: "
                        "Downloading image failed while saving to file:"
                    << targetFile;
}

#ifdef Q_OS_ANDROID
static void saveToAndroidGallery(const QByteArray& imageData)
{
    QMimeDatabase mimeDb;
    const auto mimeType = mimeDb.mimeTypeForData(imageData);
    auto ext = mimeType.preferredSuffix();
    if (ext.isEmpty())
        ext = QStringLiteral("jpg");
    auto mime = mimeType.name();
    if (mime.isEmpty())
        mime = QStringLiteral("image/jpeg");

    const auto dateTimeString = QDateTime::currentDateTime().toString(
                QStringLiteral("yyyy-MM-dd_HH-mm-ss"));
    const auto displayName = QStringLiteral("image_%1.%2").arg(dateTimeString, ext);

    const auto tempPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                          + QChar('/') + displayName;
    {
        QFile tempFile(tempPath);
        if (!tempFile.open(QIODevice::WriteOnly)) {
            qWarning() << "saveToAndroidGallery: failed to open temp file:" << tempPath;
            return;
        }
        if (tempFile.write(imageData) == -1) {
            qWarning() << "saveToAndroidGallery: failed to write temp file:" << tempPath;
            QFile::remove(tempPath);
            return;
        }
    } // tempFile flushed and closed here before JNI reads it

    QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    const bool ok = QJniObject::callStaticMethod<jboolean>(
        "app/status/mobile/MediaStoreHelper",
        "insertImageFromPath",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Z",
        ctx.object(),
        QJniObject::fromString(tempPath).object<jstring>(),
        QJniObject::fromString(mime).object<jstring>(),
        QJniObject::fromString(displayName).object<jstring>()
    );
    QFile::remove(tempPath);

    if (!ok)
        qWarning() << "saveToAndroidGallery: MediaStore insertion failed for" << displayName;
}

#endif

void SystemUtilsInternal::downloadImageByUrl(
        const QUrl& url, const QString& path) const
{
    static thread_local QNetworkAccessManager manager;
    manager.setAutoDeleteReplies(true);

    QNetworkReply *reply = manager.get(QNetworkRequest(url));

    // The image may be served from the local Status Go node (https://localhost:…)
    // which uses a self-signed certificate. Accept SSL errors only for localhost
    // so we match the behaviour of the engine's QML network access manager.
    if (url.host() == QLatin1String("localhost") || url.host() == QLatin1String("127.0.0.1")) {
        QObject::connect(reply, &QNetworkReply::sslErrors, reply,
                         [reply](const QList<QSslError>&) { reply->ignoreSslErrors(); });
    }

    // accept both "file:/foo/bar" and "/foo/bar"
    const auto parsedPath = QUrl::fromUserInput(path);

    auto targetDir = parsedPath.toLocalFile();

    if (targetDir.isEmpty())
        targetDir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);

    QObject::connect(reply, &QNetworkReply::finished, this, [reply, targetDir] {
        if(reply->error() != QNetworkReply::NoError) {
            qWarning() << "SystemUtilsInternal::downloadImageByUrl: Downloading image"
                       << reply->request().url() << "failed:" << reply->errorString();
            return;
        }

        // Extract the image data to be able to load and save it
        const auto btArray = reply->readAll();
        Q_ASSERT(!btArray.isEmpty());
#ifdef Q_OS_IOS
        saveImageToPhotosAlbum(btArray);
#elif defined(Q_OS_ANDROID)
        saveToAndroidGallery(btArray);
#else
        save(btArray, targetDir);
#endif
    });
}


void SystemUtilsInternal::openAppSettings()
{
#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/StatusQtActivity",
        "openAppSettings",
        "()V"
    );
#elif defined(Q_OS_IOS)
    // iOS implementation
    QUrl url(QStringLiteral("app-settings:"));
    QDesktopServices::openUrl(url);
#else
    // Desktop - we shouldn't be here
    qWarning() << "openAppSettings not implemented for this platform";
#endif
}

void SystemUtilsInternal::synthetizeRightClick(QQuickItem* item, qreal x, qreal y, Qt::KeyboardModifiers modifiers) const
{
    if (!item)
        return;

    // Synthesize a right click event on the given item
    auto leftClickRelease = new QMouseEvent(QEvent::MouseButtonRelease, {x, y}, Qt::LeftButton, Qt::NoButton, modifiers);
    auto rightClickPress = new QMouseEvent(QEvent::MouseButtonPress, {x, y}, Qt::RightButton, Qt::NoButton, modifiers);
    auto rightClickRelease = new QMouseEvent(QEvent::MouseButtonRelease, {x, y}, Qt::RightButton, Qt::NoButton, modifiers);
    
    QCoreApplication::postEvent(item, leftClickRelease);
    QCoreApplication::postEvent(item, rightClickPress);
    QCoreApplication::postEvent(item, rightClickRelease);
}

Qt::KeyboardModifiers SystemUtilsInternal::queryKeyboardModifiers()
{
    return QGuiApplication::queryKeyboardModifiers();
}

Qt::MouseButtons SystemUtilsInternal::mouseButtons()
{
    return QGuiApplication::mouseButtons();
}

void SystemUtilsInternal::setAndroidStatusBarIconColor(bool lightIcons)
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (activity.isValid()) {
        QJniObject::callStaticMethod<void>(
            "app/status/mobile/StatusBarUtil",
            "setStatusBarIconColor",
            "(Landroid/app/Activity;Z)V",
            activity.object<jobject>(),
            lightIcons
        );
    }
#else
    Q_UNUSED(lightIcons);
#endif
}

void SystemUtilsInternal::setMainWindowReady()
{
#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/StatusQtActivity",
        "mainWindowReady",
        "()V"
    );
#endif
}

int SystemUtilsInternal::androidKeyboardHeight() const
{
    return m_androidKeyboardHeight;
}

bool SystemUtilsInternal::androidKeyboardVisible() const
{
    return m_androidKeyboardVisible;
}

void SystemUtilsInternal::requestAndroidKeyboardShow()
{
#ifdef Q_OS_ANDROID
    auto activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) {
        return;
    }
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/KeyboardUtil",
        "requestKeyboardShow",
        "(Landroid/app/Activity;)V",
        activity.object()
    );
#endif
}

int SystemUtilsInternal::iosKeyboardHeight() const
{
#ifdef Q_OS_IOS
    return m_iosKeyboardHeight;
#else
    return 0;
#endif
}

bool SystemUtilsInternal::iosKeyboardVisible() const
{
#ifdef Q_OS_IOS
    return m_iosKeyboardVisible;
#else
    return false;
#endif
}

void SystemUtilsInternal::setupIOSKeyboardTracking()
{
#ifdef Q_OS_IOS
    ::setupIOSKeyboardTracking();
#endif
}

void SystemUtilsInternal::iosShareFile(const QUrl& fileUrl) const
{
#ifdef Q_OS_IOS
    const QString localPath = fileUrl.isLocalFile() ? fileUrl.toLocalFile() : QString();
    if (localPath.isEmpty())
        return;
    ::presentIOSShareSheetForFilePath(localPath);
#else
    Q_UNUSED(fileUrl);
#endif
}

void SystemUtilsInternal::iosShareFiles(const QVariantList& fileUrls) const
{
#ifdef Q_OS_IOS
    QStringList paths;
    paths.reserve(fileUrls.size());
    for (const auto& v : fileUrls) {
        if (v.canConvert<QUrl>()) {
            const QUrl url = v.toUrl();
            const QString p = url.isLocalFile() ? url.toLocalFile() : QString();
            if (!p.isEmpty())
                paths.push_back(p);
        } else if (v.canConvert<QString>()) {
            // Allow passing either a raw local path or a file:// URL string.
            const QString s = v.toString();
            if (s.isEmpty())
                continue;
            const QUrl url = QUrl::fromUserInput(s);
            const QString p = url.isLocalFile() ? url.toLocalFile() : s;
            if (!p.isEmpty())
                paths.push_back(p);
        }
    }
    if (paths.isEmpty())
        return;
    qInfo() << "[iOS Share] SystemUtilsInternal::iosShareFiles paths=" << paths.size()
            << " sample=" << (paths.size() > 0 ? paths.first() : QString());
    ::presentIOSShareSheetForFilePaths(paths);
#else
    Q_UNUSED(fileUrls);
#endif
}

void SystemUtilsInternal::iosSharePaths(const QStringList& filePaths) const
{
#ifdef Q_OS_IOS
    QStringList paths;
    paths.reserve(filePaths.size());
    for (const auto& s : filePaths) {
        if (s.isEmpty())
            continue;
        const QUrl url = QUrl::fromUserInput(s);
        const QString p = url.isLocalFile() ? url.toLocalFile() : s;
        if (!p.isEmpty())
            paths.push_back(p);
    }
    if (paths.isEmpty())
        return;
    qInfo() << "[iOS Share] SystemUtilsInternal::iosSharePaths paths=" << paths.size()
            << " sample=" << (paths.size() > 0 ? paths.first() : QString());
    ::presentIOSShareSheetForFilePaths(paths);
#else
    Q_UNUSED(filePaths);
#endif
}

void SystemUtilsInternal::androidSharePaths(const QStringList& filePaths) const
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid())
        return;

    QJniObject arrayList("java/util/ArrayList");
    if (!arrayList.isValid())
        return;

    for (const auto& s : filePaths) {
        if (s.isEmpty())
            continue;
        QJniObject jStr = QJniObject::fromString(s);
        arrayList.callMethod<jboolean>("add", "(Ljava/lang/Object;)Z", jStr.object<jstring>());
    }

    const int count = arrayList.callMethod<jint>("size", "()I");
    if (count <= 0)
        return;

    QJniObject::callStaticMethod<void>(
        "app/status/mobile/ShareUtils",
        "sharePaths",
        "(Landroid/app/Activity;Ljava/util/ArrayList;)V",
        activity.object<jobject>(),
        arrayList.object<jobject>()
    );
#else
    Q_UNUSED(filePaths);
#endif
}

void SystemUtilsInternal::sharePaths(const QStringList& filePaths) const
{
#if defined(Q_OS_IOS)
    iosSharePaths(filePaths);
#elif defined(Q_OS_ANDROID)
    androidSharePaths(filePaths);
#else
    Q_UNUSED(filePaths);
#endif
}

void SystemUtilsInternal::debugLog(const QString& message) const
{
    qInfo() << "[QML]" << message;
}

void SystemUtilsInternal::startShakeDetection()
{
#ifdef Q_OS_ANDROID
    static std::once_flag regOnce;
    std::call_once(regOnce, []{
        // Set up Android shake detection and event-driven native callback
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (activity.isValid()) {
            QJniObject::callStaticMethod<void>(
                "app/status/mobile/ShakeDetector",
                "start",
                "(Landroid/app/Activity;)V",
                activity.object<jobject>()
            );
        }
        QJniEnvironment env;
        jclass clazz = env->FindClass("app/status/mobile/ShakeDetector");
        if (!clazz) return;

        const JNINativeMethod methods[] = {
            { const_cast<char*>("nativeShakeDetected"),
              const_cast<char*>("()V"),
              reinterpret_cast<void*>(jni_nativeShakeDetected) },
        };

        jint rc = env->RegisterNatives(clazz, methods, jint(std::size(methods)));
        env->DeleteLocalRef(clazz);

        if (rc != 0) {
            qWarning() << "[Android Shake] RegisterNatives failed:" << rc;
        }
    });
#endif

#ifdef Q_OS_IOS
    ::setIOSShakeCallback(&iosShakeDetected);
    ::setIOSShakeToEditEnabled(false);
    // Set up iOS shake detection
    ::setupIOSShakeDetection();
#endif
}

#include "systemutilsinternal.moc"

#ifdef Q_OS_IOS
static void iosShakeDetected()
{
    if (!s_systemUtilsInternal)
        return;
    QMetaObject::invokeMethod(s_systemUtilsInternal, []() {
        qInfo() << "[iOS Shake] SystemUtilsInternal: shakeDetected signal emitted";
        emit s_systemUtilsInternal->shakeDetected();
    }, Qt::QueuedConnection);
}
#endif

#ifdef Q_OS_ANDROID
static void jni_nativeShakeDetected(JNIEnv*, jclass)
{
    if (!s_systemUtilsInternal)
        return;
    QMetaObject::invokeMethod(s_systemUtilsInternal, []() {
        qInfo() << "[Android Shake] SystemUtilsInternal: shakeDetected signal emitted";
        emit s_systemUtilsInternal->shakeDetected();
    }, Qt::QueuedConnection);
}
#endif
