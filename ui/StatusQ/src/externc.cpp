#include <QtGlobal>
#include <QObject>
#include <QString>
#include <QByteArray>
#include <QBasicTimer>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QHash>
#include <QPointer>
#include <QQmlApplicationEngine>
#include <QQmlIncubator>
#include <QTimerEvent>

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

// --- Boosted QML incubation --------------------------------------------------
// The QQuickWindow default incubation controller only incubates for a few ms
// per rendered frame, so a large asynchronously-loaded section (Loader
// asynchronous:true) takes seconds of wall time on slow devices while the
// running skeleton animation keeps the frame loop busy. This controller
// drives incubation from the event loop with a fixed budget per tick
// instead: loads finish several times faster and input events still get
// processed between ticks.
//
// Every incubation burst starts with a gentle phase: small, paced bites that
// leave the frame loop enough headroom to run the section-switch slide
// animation at full rate. Once the gentle period is over (the transition is
// done and only the loading skeleton is on screen) the throttle opens.
class BoostedIncubationController : public QObject, public QQmlIncubationController {
public:
    BoostedIncubationController(int msPerTick, int gentlePeriodMs, int boostGapMs, QObject* parent)
        : QObject(parent), m_msPerTick(msPerTick), m_gentlePeriodMs(gentlePeriodMs),
          m_boostGapMs(boostGapMs) {
        // Liveness backstop: the timer never fully stops. Even if a count
        // notification is missed (cancelled/chained incubations), pending
        // incubators are picked up at most one idle tick later — a wedged
        // controller stalls every async Loader in the app.
        m_timer.start(kIdleIntervalMs, this);
    }

    // Explicit gentle hints from the UI (StatusQ.IncubationHints): while a
    // transition animation runs, pacing stays gentle regardless of how long
    // the current incubation burst has been going.
    void pushGentleHint() {
        ++m_gentleHints;
    }

    void popGentleHint() {
        m_gentleHints = qMax(0, m_gentleHints - 1);
    }

    bool gentleHintActive() const {
        return m_gentleHints > 0;
    }

    // Debug HUD introspection (see StatusQ.IncubationHints.stats())
    int debugCount() { return incubatingObjectCount(); }
    int debugPhase() const { return m_lastPhase; }   // 0 idle, 1 gentle, 2 boost
    int debugHints() const { return m_gentleHints; }
    int debugGentleIntervalMs() const { return m_gentleIntervalMs; }
    int debugGentleBudgetMs() const { return m_gentleBudgetMs; }

protected:
    void incubatingObjectCountChanged(int count) override {
        // fast path out of the idle cadence; phase management happens in
        // timerEvent based on the actual count. A user-initiated open finds the
        // controller idle, so this wake is dead latency in front of every warm
        // open - which is why the gentle interval is short (issues/0016).
        if (count > 0 && m_interval == kIdleIntervalMs)
            restart(m_gentleIntervalMs);
    }

    void timerEvent(QTimerEvent* event) override {
        if (event->timerId() != m_timer.timerId())
            return;

        if (incubatingObjectCount() == 0) {
            m_inBurst = false;
            m_lastPhase = 0;
            if (m_interval != kIdleIntervalMs)
                restart(kIdleIntervalMs);
            return;
        }

        if (!m_inBurst) {
            m_inBurst = true;
            m_burstStart.start();
        }

        // gentle first: small paced bites leave the frame loop enough
        // headroom for the section-switch transition; then open the throttle.
        // An active hint keeps the pacing gentle beyond the burst-start
        // window — bursts can outlive it when incubation never drains.
        const bool gentle = m_gentleHints > 0
                            || (m_gentlePeriodMs > 0
                                && m_burstStart.elapsed() < m_gentlePeriodMs);
        const int wantedInterval = gentle ? m_gentleIntervalMs : m_boostGapMs;
        if (m_interval != wantedInterval)
            restart(wantedInterval);

        m_lastPhase = gentle ? 1 : 2;
        incubateFor(gentle ? m_gentleBudgetMs : m_msPerTick);
    }

private:
    void restart(int interval) {
        m_interval = interval;
        m_timer.start(interval, this);
    }

    // idle poll: cheap (one count check), bounds the wedge-recovery latency
    static constexpr int kIdleIntervalMs = 128;

    // Gentle pacing is a duty cycle in absolute time, not a division of the
    // frame period: the bite bounds how long a posted event waits behind
    // incubation, the interval bounds how much of the GUI thread incubation
    // takes. Neither is a property of the refresh rate. Measured
    // (issues/0016): the frame-derived 4ms-every-16ms cadence spent 76% of
    // every load waiting for the next tick, and the bite is not the stall
    // floor anyway - a bite overshoots into the object it is midway through
    // creating, and that overshoot is what sets the block size.
    static constexpr int kGentleIntervalMs = 4;
    static constexpr int kGentleBudgetMs = 2;

    QBasicTimer m_timer;
    QElapsedTimer m_burstStart;
    bool m_inBurst = false;
    int m_interval = kIdleIntervalMs;
    int m_gentleIntervalMs = kGentleIntervalMs;
    int m_gentleBudgetMs = kGentleBudgetMs;
    int m_gentleHints = 0;
    int m_lastPhase = 0;
    const int m_msPerTick;
    const int m_gentlePeriodMs;
    const int m_boostGapMs;
};

namespace {
// engine → its installed controller, for the gentle-hint entry points
QHash<QQmlEngine*, QPointer<BoostedIncubationController>> s_incubationControllers;
}

// Must be installed before the root window is created (QQuickWindow only
// installs its own controller when the engine has none).
Q_DECL_EXPORT void statusq_installBoostedIncubationController(void* engine, int msPerTick,
                                                              int gentlePeriodMs, int boostGapMs) {
    // QQmlEngine, not QQmlApplicationEngine: the test harness owns a plain one
    auto* qmlEngine = static_cast<QQmlEngine*>(engine);
    auto* controller = new BoostedIncubationController(qMax(1, msPerTick),
                                                       qMax(0, gentlePeriodMs),
                                                       qMax(0, boostGapMs), qmlEngine);
    qmlEngine->setIncubationController(controller);
    s_incubationControllers.insert(qmlEngine, controller);
}

Q_DECL_EXPORT void statusq_incubationPushGentleHint(void* engine) {
    if (auto controller = s_incubationControllers.value(static_cast<QQmlEngine*>(engine)))
        controller->pushGentleHint();
}

Q_DECL_EXPORT void statusq_incubationPopGentleHint(void* engine) {
    if (auto controller = s_incubationControllers.value(static_cast<QQmlEngine*>(engine)))
        controller->popGentleHint();
}

Q_DECL_EXPORT bool statusq_incubationGentleHintActive(void* engine) {
    auto controller = s_incubationControllers.value(static_cast<QQmlEngine*>(engine));
    return controller && controller->gentleHintActive();
}

// Fills the debug-HUD snapshot; returns false when no boosted controller is
// installed on the engine.
Q_DECL_EXPORT bool statusq_incubationDebugStats(void* engine, int* count, int* phase,
                                                int* hints, int* gentleIntervalMs,
                                                int* gentleBudgetMs) {
    auto controller = s_incubationControllers.value(static_cast<QQmlEngine*>(engine));
    if (!controller)
        return false;
    *count = controller->debugCount();
    *phase = controller->debugPhase();
    *hints = controller->debugHints();
    *gentleIntervalMs = controller->debugGentleIntervalMs();
    *gentleBudgetMs = controller->debugGentleBudgetMs();
    return true;
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
