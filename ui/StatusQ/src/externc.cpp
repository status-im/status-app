#include <QtGlobal>
#include <QString>
#include <QByteArray>
#include <QQmlApplicationEngine>
#include <QQmlNetworkAccessManagerFactory>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>

#include <StatusQ/typesregistration.h>
#include <StatusQ/osnotification.h>
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

// --- Disk-cache network factory (ported from DOtherSide QMLNetworkAccessFactory) ----------
class StatusQNetworkAccessFactory : public QQmlNetworkAccessManagerFactory {
public:
    explicit StatusQNetworkAccessFactory(const QString &cacheDir) : m_cacheDir(cacheDir) {}

    QNetworkAccessManager* create(QObject* parent) override {
        auto* manager = new QNetworkAccessManager(parent);
        auto* cache = new QNetworkDiskCache(manager);
        cache->setCacheDirectory(m_cacheDir);
        manager->setCache(cache);
        return manager;
    }

private:
    QString m_cacheDir;
};

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

// `engine` is a QQmlApplicationEngine* (nimqml engine.vptr). The factory must outlive the
// engine; it is intentionally not deleted (process-lifetime, as in DOtherSide).
Q_DECL_EXPORT void statusq_setupNetworkAccessManagerFactory(void* engine, const char* tmpPath) {
    auto* qmlEngine = static_cast<QQmlApplicationEngine*>(engine);
    qmlEngine->setNetworkAccessManagerFactory(
        new StatusQNetworkAccessFactory(QString::fromUtf8(tmpPath)));
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

} // extern "C"
