#include <QElapsedTimer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSignalSpy>
#include <QTest>

#include <StatusQ/delegatepool.h>
#include <StatusQ/typesregistration.h>

// Asynchronous incubators only progress when a controller drives them; plain
// QQmlEngine has none, so each test installs StatusQ's event-loop controller.
extern "C" void statusq_installBoostedIncubationController(void* engine, int msPerTick,
                                                           int gentlePeriodMs, int boostGapMs);

namespace {

constexpr auto kBackgroundIntervalMs = 150;

struct PoolHarness
{
    QQmlEngine engine;
    QQmlComponent component{&engine};
    QScopedPointer<QObject> root;
    DelegatePool* pool = nullptr;

    explicit PoolHarness(const QByteArray& qml)
    {
        statusq_installBoostedIncubationController(&engine, 8, 0, 0);
        component.setData(qml, QUrl(QStringLiteral("qrc:/tst_DelegatePool.qml")));
        root.reset(component.create());
        pool = qobject_cast<DelegatePool*>(root.data());
    }
};

QByteArray singleKindPool(int target, int backgroundIntervalMs = kBackgroundIntervalMs)
{
    return QByteArrayLiteral(R"(
        import QtQuick
        import StatusQ

        DelegatePool {
            backgroundIntervalMs: %1
            DelegatePoolKind {
                kind: "message"
                target: %2
                delegate: Component { Item { property string boundText } }
            }
        }
    )").replace("%1", QByteArray::number(backgroundIntervalMs))
       .replace("%2", QByteArray::number(target));
}

} // namespace

class tst_DelegatePool : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        registerStatusQTypes();
    }

    void fillsToTargetWithDistinctReadyItems()
    {
        PoolHarness harness(singleKindPool(3, 0));
        QVERIFY2(harness.pool, qPrintable(harness.component.errorString()));

        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 3);

        auto* first = harness.pool->acquire(QStringLiteral("message"));
        auto* second = harness.pool->acquire(QStringLiteral("message"));
        auto* third = harness.pool->acquire(QStringLiteral("message"));
        QVERIFY(first && second && third);
        QVERIFY(first != second && second != third && first != third);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 0);
    }

    void acquireNeverCreatesSynchronously()
    {
        PoolHarness harness(singleKindPool(3, 0));
        QVERIFY(harness.pool);

        // nothing incubated yet: a dry pool hands out null, it never builds
        QCOMPARE(harness.pool->acquire(QStringLiteral("message")), nullptr);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 0);
    }

    void unknownKindReturnsNull()
    {
        PoolHarness harness(singleKindPool(1, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);

        QCOMPARE(harness.pool->acquire(QStringLiteral("no-such-kind")), nullptr);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("no-such-kind")), 0);
    }

    void availabilitySignalFiresAsItemsIncubate()
    {
        PoolHarness harness(singleKindPool(3, 0));
        QVERIFY(harness.pool);

        QSignalSpy spy(harness.pool, &DelegatePool::availabilityChanged);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 3);

        QCOMPARE(spy.count(), 3);
        for (auto i = 0; i < spy.count(); ++i) {
            QCOMPARE(spy.at(i).at(0).toString(), QStringLiteral("message"));
            QCOMPARE(spy.at(i).at(1).toInt(), i + 1);
        }
    }

    void releaseAcquireRoundTrips()
    {
        PoolHarness harness(singleKindPool(2, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 2);

        auto* item = harness.pool->acquire(QStringLiteral("message"));
        QVERIFY(item);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);

        harness.pool->release(item);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 2);

        // LIFO: the released item comes back first
        QCOMPARE(harness.pool->acquire(QStringLiteral("message")), item);
    }

    void doubleReleaseIsIdempotent()
    {
        PoolHarness harness(singleKindPool(1, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);

        auto* item = harness.pool->acquire(QStringLiteral("message"));
        harness.pool->release(item);
        harness.pool->release(item);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);
    }

    void foreignItemReleaseIsIgnored()
    {
        PoolHarness harness(singleKindPool(1, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);

        QQuickItem foreign;
        QTest::ignoreMessage(QtWarningMsg,
                             QRegularExpression(QStringLiteral("not built by this pool")));
        harness.pool->release(&foreign);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);
    }

    void parkedItemsAreInvisibleAndDisabled()
    {
        PoolHarness harness(singleKindPool(1, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);

        auto* item = harness.pool->acquire(QStringLiteral("message"));
        QVERIFY(item);
        QVERIFY(item->parentItem());

        // effective visibility follows the parent chain: only under a window's
        // content item can the acquired item's own flags be observed
        QQuickWindow window;
        item->setParentItem(window.contentItem());
        QVERIFY(item->isVisible());
        QVERIFY(item->isEnabled());

        harness.pool->release(item);
        QVERIFY(item->parentItem() != window.contentItem());
        QVERIFY(!item->isVisible());
        QVERIFY(!item->isEnabled());
    }

    void growOnlyTarget()
    {
        PoolHarness harness(singleKindPool(3, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 3);

        harness.pool->setTarget(QStringLiteral("message"), 1);
        QTest::qWait(50);
        QCOMPARE(harness.pool->readyCount(QStringLiteral("message")), 3);

        harness.pool->setTarget(QStringLiteral("message"), 5);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 5);
    }

    void backgroundBuildYieldsAndBoostAccelerates()
    {
        QElapsedTimer timer;
        timer.start();

        PoolHarness harness(singleKindPool(3, kBackgroundIntervalMs));
        QVERIFY(harness.pool);

        // background pacing: one item per interval, so 3 items take >= 2 gaps
        // beyond the first spaced start — far above any incubation cost
        QTRY_COMPARE_WITH_TIMEOUT(harness.pool->readyCount(QStringLiteral("message")), 3, 5000);
        const auto backgroundElapsed = timer.elapsed();
        QVERIFY2(backgroundElapsed >= 2 * kBackgroundIntervalMs,
                 qPrintable(QStringLiteral("background build finished in %1ms")
                                .arg(backgroundElapsed)));

        harness.pool->setTarget(QStringLiteral("message"), 6);
        harness.pool->boost(QStringLiteral("message"), 6);
        QVERIFY(harness.pool->boosted());

        timer.restart();
        QTRY_COMPARE_WITH_TIMEOUT(harness.pool->readyCount(QStringLiteral("message")), 6, 5000);
        const auto boostedElapsed = timer.elapsed();
        QVERIFY2(boostedElapsed < 2 * kBackgroundIntervalMs,
                 qPrintable(QStringLiteral("boosted build took %1ms").arg(boostedElapsed)));

        // need met: priority drops back
        QVERIFY(!harness.pool->boosted());
    }

    void boostAlreadySatisfiedIsInert()
    {
        PoolHarness harness(singleKindPool(2, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 2);

        harness.pool->boost(QStringLiteral("message"), 2);
        QVERIFY(!harness.pool->boosted());
    }

    void boostWithNothingToBuildClears()
    {
        PoolHarness harness(singleKindPool(1, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 1);

        // all items lent out and the target is reached: nothing to accelerate
        auto* item = harness.pool->acquire(QStringLiteral("message"));
        QVERIFY(item);
        harness.pool->boost(QStringLiteral("message"), 1);

        QTRY_VERIFY(!harness.pool->boosted());
    }

    void destroyedItemIsRebuilt()
    {
        PoolHarness harness(singleKindPool(2, 0));
        QVERIFY(harness.pool);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 2);

        auto* item = harness.pool->acquire(QStringLiteral("message"));
        QVERIFY(item);
        delete item;

        // the pool is grow-only on live items: a destroyed one leaves a
        // deficit that background building refills
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 2);
    }

    void multipleKindsFillIndependently()
    {
        PoolHarness harness(QByteArrayLiteral(R"(
            import QtQuick
            import StatusQ

            DelegatePool {
                backgroundIntervalMs: 0
                DelegatePoolKind {
                    kind: "message"
                    target: 2
                    delegate: Component { Item {} }
                }
                DelegatePoolKind {
                    kind: "system"
                    target: 1
                    delegate: Component { Item {} }
                }
            }
        )"));
        QVERIFY(harness.pool);

        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("message")), 2);
        QTRY_COMPARE(harness.pool->readyCount(QStringLiteral("system")), 1);

        auto* message = harness.pool->acquire(QStringLiteral("message"));
        auto* system = harness.pool->acquire(QStringLiteral("system"));
        QVERIFY(message && system);
        QVERIFY(message != system);
    }
};

QTEST_MAIN(tst_DelegatePool)
#include "tst_delegatepool.moc"
