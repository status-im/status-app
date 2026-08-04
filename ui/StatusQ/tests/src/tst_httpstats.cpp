#include <QCoreApplication>
#include <QNetworkDiskCache>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QThread>

#include <StatusQ/httpstats.h>
#include <StatusQ/typesregistration.h>

class tst_HttpStats : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        registerStatusQTypes();
    }

    void livesOnGuiThread_whenFirstTouchedFromWorker()
    {
        auto* worker = QThread::create([] {
            HttpStats::instance().record(QStringLiteral("example.com"), 42, false);
        });
        worker->start();
        QVERIFY(worker->wait(5000));
        delete worker;

        // Drain the queued changed() from the worker touch above.
        QCoreApplication::processEvents();

        QCOMPARE(HttpStats::instance().thread(), QCoreApplication::instance()->thread());

        // QQmlEngine refuses Connections to a QObject on a non-engine thread.
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            import StatusQ
            Item {
                id: root
                property int ticks: 0
                Connections {
                    target: HttpStats
                    function onChanged() { root.ticks += 1 }
                }
            }
        )", QUrl(QStringLiteral("qrc:/tst_HttpStats.qml")));

        QScopedPointer<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));

        const int before = root->property("ticks").toInt();
        HttpStats::instance().record(QStringLiteral("example.com"), 1, false);
        QTRY_COMPARE(root->property("ticks").toInt(), before + 1);
    }

    void record_fromWorker_deliversChangedOnGuiThread()
    {
        // Drop any queued changed() left by the previous slot.
        QCoreApplication::processEvents();

        QSignalSpy spy(&HttpStats::instance(), &HttpStats::changed);
        QVERIFY(spy.isValid());

        auto* worker = QThread::create([] {
            HttpStats::instance().record(QStringLiteral("cdn.example"), 100, true);
        });
        worker->start();
        QVERIFY(worker->wait(5000));
        delete worker;

        QTRY_COMPARE(spy.count(), 1);
        QCOMPARE(HttpStats::instance().thread(), QCoreApplication::instance()->thread());
    }

    void clearCache_withNoCaches_stillReports()
    {
        // The screen re-measures the directory on cacheCleared(), so the signal
        // has to arrive even when there was nothing registered to clear.
        QSignalSpy spy(&HttpStats::instance(), &HttpStats::cacheCleared);
        QVERIFY(spy.isValid());

        HttpStats::instance().clearCache();

        QTRY_COMPARE(spy.count(), 1);
    }

    void clearCache_reportsAfterTheCacheIsEmpty()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        QNetworkDiskCache cache;
        cache.setCacheDirectory(dir.path());
        HttpStats::instance().registerCache(&cache);

        QSignalSpy cleared(&HttpStats::instance(), &HttpStats::cacheCleared);
        QSignalSpy changed(&HttpStats::instance(), &HttpStats::changed);
        QVERIFY(cleared.isValid());

        HttpStats::instance().clearCache();

        QTRY_COMPARE(cleared.count(), 1);
        // Not changed(): that one fires on every reply, which is exactly what a
        // directory walk must not be hung on.
        QCOMPARE(changed.count(), 0);
    }
};

QTEST_MAIN(tst_HttpStats)
#include "tst_httpstats.moc"
