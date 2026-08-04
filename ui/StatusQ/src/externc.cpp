#include <QtGlobal>
#include <QObject>
#include <QString>
#include <QByteArray>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include <StatusQ/networkaccessfactory.h>
#include <StatusQ/typesregistration.h>
#include <StatusQ/osnotification.h>
#include <StatusQ/urlschemeevent.h>
#ifdef MONITORING
#include <QProcessEnvironment>
#include <QtQml>
#include "StatusDesktop/Monitoring/Monitor.h"
#endif
#include <MobileUI>

#ifdef STATUSQ_HAS_QTWEBENGINE
#include <QtWebEngineQuick>
#endif

// --- Qt/QML message-handler forwarding (ported from DOtherSide myMessageOutput) ----------
typedef void (*StatusQMessageHandler)(int type, const char* message, const char* category,
                                      const char* file, const char* function, int line);

static StatusQMessageHandler g_statusqMessageHandler = nullptr;

static void statusq_messageOutput(QtMsgType type, const QMessageLogContext &context,
                                  const QString &msg) {
    if (g_statusqMessageHandler == nullptr)
        return;
    const QByteArray localMessage = msg.toLocal8Bit();
    const char* message = localMessage.constData();
    const char* category = context.category ? context.category : "";
    const char* file = context.file ? context.file : "";
    const char* function = context.function ? context.function : "";
    g_statusqMessageHandler(int(type), message, category, file, function, context.line);
}

extern "C" {

Q_DECL_EXPORT void statusq_registerQmlTypes() {
    registerStatusQTypes();
}

Q_DECL_EXPORT float statusq_getMobileUIScaleFactor(float baseWidth, float baseDpi, float baseScale) {
    return MobileUI::getSmartScaleFactor(baseWidth, baseDpi, baseScale);
}

Q_DECL_EXPORT void statusq_installMessageHandler(StatusQMessageHandler cb) {
    g_statusqMessageHandler = cb;
    qInstallMessageHandler(statusq_messageOutput);
}

// `engine` is a QQmlApplicationEngine* (nimqml engine.vptr).
Q_DECL_EXPORT void statusq_setupNetworkAccessManagerFactory(void* engine, const char* tmpPath,
                                                            qint64 maxCacheSize) {
    Status::setupNetworkAccessManagerFactory(static_cast<QQmlApplicationEngine*>(engine),
                                             QString::fromUtf8(tmpPath), maxCacheSize);
}

Q_DECL_EXPORT void statusq_initializeWebEngine() {
#ifdef STATUSQ_HAS_QTWEBENGINE
    QtWebEngineQuick::initialize();
#endif
}

Q_DECL_EXPORT void* statusq_osnotification_create() {
    return new Status::OSNotification();
}

Q_DECL_EXPORT void statusq_osnotification_show_notification(void* obj, const char* title,
                                                            const char* message, const char* identifier) {
    if (auto* n = static_cast<Status::OSNotification*>(obj))
        n->showNotification(QString::fromUtf8(title), QString::fromUtf8(message),
                            QString::fromUtf8(identifier));
}

Q_DECL_EXPORT void statusq_osnotification_show_badge_notification(void* obj, int notificationsCount) {
    if (auto* n = static_cast<Status::OSNotification*>(obj))
        n->showIconBadgeNotification(notificationsCount);
}

Q_DECL_EXPORT void statusq_osnotification_delete(void* obj) {
    if (auto* q = static_cast<QObject*>(obj))
        q->deleteLater();
}

Q_DECL_EXPORT void statusq_invoke_method_queued(void* obj, const char* method, const char* arg) {
    QMetaObject::invokeMethod(static_cast<QObject*>(obj), method, Qt::QueuedConnection,
                              Q_ARG(QString, QString::fromUtf8(arg)));
}

Q_DECL_EXPORT void* statusq_urlscheme_create() {
    auto* ev = new Status::UrlSchemeEvent();
    ev->registerUrlHandler();
    ev->watchApplicationState();
    return ev;
}

Q_DECL_EXPORT void statusq_urlscheme_set_instance(void* obj) {
    Status::UrlSchemeEvent::setInstance(static_cast<Status::UrlSchemeEvent*>(obj));
}

Q_DECL_EXPORT void statusq_urlscheme_install_event_filter(void* obj) {
    qGuiApp->installEventFilter(static_cast<QObject*>(obj));
}

Q_DECL_EXPORT void statusq_urlscheme_emit_deeplink(void* obj, const char* url) {
    static_cast<Status::UrlSchemeEvent*>(obj)->emitDeepLinkToQt(QString::fromUtf8(url));
}

Q_DECL_EXPORT void statusq_urlscheme_emit_appforegrounded(void* obj) {
    static_cast<Status::UrlSchemeEvent*>(obj)->emitAppForegroundedToQt();
}

Q_DECL_EXPORT void statusq_urlscheme_emit_appbackgrounded(void* obj) {
    static_cast<Status::UrlSchemeEvent*>(obj)->emitAppBackgroundedToQt();
}

Q_DECL_EXPORT void statusq_urlscheme_delete(void* obj) {
    static_cast<QObject*>(obj)->deleteLater();
}

#ifdef MONITORING
Q_DECL_EXPORT void statusq_registerMonitoringType() {
    qmlRegisterSingletonType<Monitor>("Monitoring", 1, 0, "Monitor", &Monitor::qmlInstance);
}

Q_DECL_EXPORT void statusq_initializeMonitoring(void* engine) {
    auto disabled = QStringLiteral("0");
    if (QProcessEnvironment::systemEnvironment().value(
            QStringLiteral("DISABLE_MONITORING_WINDOW"), disabled) == disabled)
        Monitor::instance().initialize(static_cast<QQmlApplicationEngine*>(engine));
}
#endif

} // extern "C"
