// RED (stack PR #21921): once the gentle window of the boosted incubation
// controller expires, the controller re-arms itself with a zero-interval
// timer and calls incubateFor(msPerTick) on every event-loop pass. A zero
// timer never lets the dispatcher sleep, so the GUI thread runs a
// back-to-back block/incubate duty cycle for the remainder of the burst:
// one core is pinned and every posted event (input, UpdateRequest) waits up
// to a full tick (20 ms in the shipped configuration). The boosted phase
// must be paced with a non-zero interval so the event loop breathes between
// ticks.

#include <QtTest>

#include <QAbstractEventDispatcher>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlIncubator>

#include <algorithm>
#include <memory>
#include <vector>

extern "C" void statusq_installBoostedIncubationController(void* engine, int msPerTick,
                                                           int gentlePeriodMs);

namespace {

// Enough plain Items that a single asynchronous incubation spans several
// controller ticks
QByteArray largeComponentQml()
{
    QByteArray qml = "import QtQuick\nItem{";
    for (int i = 0; i < 30000; ++i)
        qml += "Item{}";
    qml += "}";
    return qml;
}

int minRegisteredTimerIntervalMs(QObject* object)
{
    int minInterval = std::numeric_limits<int>::max();
    auto* dispatcher = QAbstractEventDispatcher::instance();
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    const auto timers = dispatcher->timersForObject(object);
    for (const auto& info : timers) {
        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(info.interval);
        minInterval = std::min(minInterval, int(ms.count()));
    }
#else
    const auto timers = dispatcher->registeredTimers(object);
    for (const auto& info : timers)
        minInterval = std::min(minInterval, info.interval);
#endif
    return minInterval;
}

QObject* installController(QQmlEngine& engine, int msPerTick, int gentlePeriodMs)
{
    const QObjectList childrenBefore = engine.children();
    statusq_installBoostedIncubationController(&engine, msPerTick, gentlePeriodMs);

    QObject* controller = nullptr;
    for (QObject* child : engine.children()) {
        if (!childrenBefore.contains(child))
            controller = child;
    }
    return controller;
}

} // namespace

class TestIncubationController : public QObject
{
    Q_OBJECT

private slots:
    // With the gentle phase disabled the controller is in the boosted phase
    // from its very first tick. A small per-tick budget stretches one
    // incubation over many ticks, so the pacing interval the controller
    // re-arms itself with is observable from the outside.
    void boostedPhaseMustNotUseAZeroIntervalTimer()
    {
        QQmlEngine engine;
        QObject* controller = installController(engine, 1, 0);
        QVERIFY2(controller, "the installed controller must be a child of the engine");

        QQmlComponent component(&engine);
        component.setData(largeComponentQml(), QUrl(QStringLiteral("inline://large.qml")));
        QTRY_VERIFY_WITH_TIMEOUT(component.status() != QQmlComponent::Loading, 30000);
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));

        QQmlIncubator incubator(QQmlIncubator::Asynchronous);
        component.create(incubator);

        bool zeroIntervalSeen = false;
        int samples = 0;
        QElapsedTimer wall;
        wall.start();

        while (incubator.isLoading() && wall.elapsed() < 15000) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
            if (!incubator.isLoading())
                break;
            ++samples;
            if (minRegisteredTimerIntervalMs(controller) == 0)
                zeroIntervalSeen = true;
        }

        QVERIFY2(incubator.isReady(), "incubation must finish");
        delete incubator.object();

        QVERIFY2(samples > 0, "the incubation window must be long enough to observe the timer");
        QVERIFY2(!zeroIntervalSeen,
                 "the boosted phase re-armed with a zero-interval timer: the event "
                 "loop never sleeps and incubateFor() blocks the GUI thread "
                 "back-to-back for the whole burst");
    }

    // Shipped configuration (20 ms budget, 300 ms gentle window): once a
    // burst outlives the gentle window the throttle opens. Chained
    // incubations keep the burst alive past the window, exactly like a
    // stream of async delegates during a section load.
    void shippedConfigMustStayPacedAfterGentleWindow()
    {
        QQmlEngine engine;
        QObject* controller = installController(engine, 20, 300);
        QVERIFY2(controller, "the installed controller must be a child of the engine");

        QQmlComponent component(&engine);
        component.setData(largeComponentQml(), QUrl(QStringLiteral("inline://large2.qml")));
        QTRY_VERIFY_WITH_TIMEOUT(component.status() != QQmlComponent::Loading, 30000);
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));

        // A pool of overlapping incubators keeps incubatingObjectCount() above
        // zero for the whole window, so the controller sees one long burst.
        std::vector<std::unique_ptr<QQmlIncubator>> pool;
        const auto topUpPool = [&] {
            pool.erase(std::remove_if(pool.begin(), pool.end(), [](const auto& inc) {
                if (inc->isLoading())
                    return false;
                delete inc->object();
                return true;
            }), pool.end());
            while (pool.size() < 2) {
                pool.push_back(std::make_unique<QQmlIncubator>(QQmlIncubator::Asynchronous));
                component.create(*pool.back());
            }
        };
        topUpPool();

        bool zeroIntervalSeen = false;
        int samplesPastGentle = 0;
        QElapsedTimer wall;
        wall.start();

        while (wall.elapsed() < 1200) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
            topUpPool();

            if (wall.elapsed() > 500) {
                ++samplesPastGentle;
                if (minRegisteredTimerIntervalMs(controller) == 0)
                    zeroIntervalSeen = true;
            }
        }

        for (const auto& inc : pool)
            inc->clear();

        QVERIFY2(samplesPastGentle > 0, "must sample the controller after the gentle window");
        QVERIFY2(!zeroIntervalSeen,
                 "after the 300 ms gentle window the shipped configuration re-armed "
                 "with a zero-interval timer: ~100% CPU and up to 20 ms of added "
                 "input/frame latency for the rest of the load");
    }
};

int main(int argc, char** argv)
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    TestIncubationController test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_incubationcontroller.moc"
