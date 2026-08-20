// The gentle cadence of the boosted incubation controller is a contract two
// other things depend on, so it is pinned here rather than left as a constant
// nobody may touch without re-running a bench.
//
// Measured on the wallet section and asset detail load benches (issues/0016):
//  - the bite bounds the stall floor, because a bite runs to the end of the
//    object it is midway through creating;
//  - the duty cycle (bite / interval) is what a metered load's wall clock is
//    divided by - at the old 4 ms every 16 ms, 76% of every load was the
//    controller waiting for its next tick;
//  - the interval is also the dead latency in front of a warm open, which finds
//    the controller on its idle cadence.

#include <QtTest>

#include <QGuiApplication>
#include <QQmlEngine>

extern "C" void statusq_installBoostedIncubationController(void* engine, int msPerTick,
                                                           int gentlePeriodMs, int boostGapMs);
extern "C" bool statusq_incubationDebugStats(void* engine, int* count, int* phase, int* hints,
                                             int* gentleIntervalMs, int* gentleBudgetMs);

class TestIncubationCadence : public QObject
{
    Q_OBJECT

private slots:
    void gentleCadenceMustStayPreemptibleAndDense()
    {
        QQmlEngine engine;
        // The shipped configuration (src/nim_status_client.nim).
        statusq_installBoostedIncubationController(&engine, 20, 300, 0);

        int count = 0, phase = 0, hints = 0, intervalMs = 0, budgetMs = 0;
        QVERIFY2(statusq_incubationDebugStats(&engine, &count, &phase, &hints,
                                              &intervalMs, &budgetMs),
                 "the boosted controller must be introspectable");

        QVERIFY2(budgetMs <= 2,
                 qPrintable(QStringLiteral("gentle bite is %1 ms: no surface can produce a "
                                           "GUI-thread block shorter than one bite, so this is "
                                           "the stall floor every surface budget sits above")
                            .arg(budgetMs)));

        QVERIFY2(budgetMs * 2 >= intervalMs,
                 qPrintable(QStringLiteral("gentle duty cycle is %1/%2: metered work takes "
                                           "interval/bite times its own cost in wall clock, "
                                           "which is the tax every preemptibility fix pays")
                            .arg(budgetMs).arg(intervalMs)));

        QVERIFY2(intervalMs <= 8,
                 qPrintable(QStringLiteral("gentle interval is %1 ms: a warm open finds the "
                                           "controller idle, so the whole interval is dead "
                                           "latency before its first bite")
                            .arg(intervalMs)));
    }
};

int main(int argc, char** argv)
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    TestIncubationCadence test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_incubationcadence.moc"
