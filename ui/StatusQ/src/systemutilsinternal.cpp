#include "StatusQ/systemutilsinternal.h"

#include <QDesktopServices>
#include <QGuiApplication>
#include <QMimeDatabase>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QJniObject>
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

SystemUtilsInternal::SystemUtilsInternal(QObject *parent)
    : QObject{parent}
{
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
                QStringLiteral("dd-MM-yyyy_hh-mm-ss"));

    // Get the preferred extension
    QMimeDatabase mimeDb;
    auto ext = mimeDb.mimeTypeForData(imageData).preferredSuffix();
    if (ext.isEmpty())
        ext = QStringLiteral("jpg");

    // Construct the target path
    const auto targetFile = QStringLiteral("%1/image_%2.%3").arg(
                targetDir, dateTimeString, ext);

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

void SystemUtilsInternal::downloadImageByUrl(
        const QUrl& url, const QString& path) const
{
    static thread_local QNetworkAccessManager manager;
    manager.setAutoDeleteReplies(true);

    QNetworkReply *reply = manager.get(QNetworkRequest(url));

    // accept both "file:/foo/bar" and "/foo/bar"
    auto targetDir = QUrl::fromUserInput(path)
#ifndef Q_OS_ANDROID
                         .toLocalFile();
#else
                         .toString(); // don't touch the "content://" URI
#endif

    if (targetDir.isEmpty())
        targetDir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);

    QObject::connect(reply, &QNetworkReply::finished, this, [reply, targetDir] {
        if(reply->error() != QNetworkReply::NoError) {
            qWarning() << "SystemUtilsInternal::downloadImageByUrl: Downloading image"
                       << reply->request().url() << "failed!";
            return;
        }

        // Extract the image data to be able to load and save it
        const auto btArray = reply->readAll();
        Q_ASSERT(!btArray.isEmpty());
#ifdef Q_OS_IOS
        saveImageToPhotosAlbum(btArray);
#else
        save(btArray, targetDir);
#endif
    });
}


void SystemUtilsInternal::openAppSettings() const
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

void SystemUtilsInternal::androidMinimizeToBackground()
{
#ifdef Q_OS_ANDROID
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (activity.isValid()) {
        activity.callMethod<jboolean>("moveTaskToBack", "(Z)Z", jboolean(true));
    }
#endif
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

void SystemUtilsInternal::setAndroidSplashScreenReady()
{
#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "app/status/mobile/StatusQtActivity",
        "hideSplashScreen",
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

#include "systemutilsinternal.moc"
