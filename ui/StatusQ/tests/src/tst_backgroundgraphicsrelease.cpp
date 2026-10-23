#include <QGuiApplication>
#include <QLoggingCategory>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSGRendererInterface>
#include <QSignalSpy>
#include <QTest>

#include <StatusQ/backgroundgraphicsrelease.h>

class tst_BackgroundGraphicsRelease : public QObject
{
    Q_OBJECT

    // Shows the window until its scene graph is up, then hides it. A plain
    // hide() keeps a persistent scene graph, like a backgrounded Android window.
    static void renderOnceThenHide(QQuickWindow& window)
    {
        QSignalSpy initialized(&window, &QQuickWindow::sceneGraphInitialized);
        window.resize(100, 100);
        window.show();
        QVERIFY(QTest::qWaitForWindowExposed(&window));
        QTRY_VERIFY(initialized.count() > 0);
        window.hide();
        QTRY_VERIFY(!window.isExposed());
    }

private slots:
    void initTestCase()
    {
        QQuickWindow probe;
        probe.resize(10, 10);
        probe.show();
        QVERIFY(QTest::qWaitForWindowExposed(&probe));
        if (QQuickWindow::sceneGraphBackend() == QLatin1String("software")
                || probe.rendererInterface()->graphicsApi() == QSGRendererInterface::Software)
            QSKIP("The software scene graph has no graphics to release");
    }

    void init()
    {
        QLoggingCategory::setFilterRules(QStringLiteral("status.backgroundGraphicsRelease.info=false"));
    }

    void cleanup()
    {
        QLoggingCategory::setFilterRules(QString());
    }

    void suspendInvalidatesTheSceneGraphOfAnUnexposedWindow()
    {
        QQuickWindow window;
        renderOnceThenHide(window);
        if (QTest::currentTestFailed())
            return;
        QSignalSpy invalidated(&window, &QQuickWindow::sceneGraphInvalidated);
        QCOMPARE(invalidated.count(), 0);

        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationSuspended);

        QTRY_COMPARE(invalidated.count(), 1);
        QTRY_VERIFY(!window.rhi());
    }

    void suspendLogsReleasedAndSkippedWindows()
    {
        QQuickWindow hidden;
        renderOnceThenHide(hidden);
        if (QTest::currentTestFailed())
            return;
        QQuickWindow exposed;
        exposed.resize(100, 100);
        exposed.show();
        QVERIFY(QTest::qWaitForWindowExposed(&exposed));

        QLoggingCategory::setFilterRules(QString());
        QTest::ignoreMessage(QtInfoMsg, QRegularExpression(
            QStringLiteral("^suspended: released 1 windows, kept 0 \\(no GPU resources freed\\), "
                           "skipped 1 still exposed, took \\d+ ms$")));

        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationSuspended);
    }

    void suspendLogsAWindowWithoutGraphicsAsKept()
    {
        QQuickWindow window;
        renderOnceThenHide(window);
        if (QTest::currentTestFailed())
            return;
        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationSuspended);
        QVERIFY(!window.rhi());

        QLoggingCategory::setFilterRules(QString());
        QTest::ignoreMessage(QtInfoMsg, QRegularExpression(
            QStringLiteral("^suspended: released 0 windows, kept 1 \\(no GPU resources freed\\), "
                           "skipped 0 still exposed, took \\d+ ms$")));

        release.onApplicationStateChanged(Qt::ApplicationSuspended);
    }

    void suspendKeepsThePersistenceFlags_data()
    {
        QTest::addColumn<bool>("persistentGraphics");
        QTest::addColumn<bool>("persistentSceneGraph");
        QTest::newRow("both") << true << true;
        QTest::newRow("neither") << false << false;
        QTest::newRow("graphics only") << true << false;
        QTest::newRow("scene graph only") << false << true;
    }

    void suspendKeepsThePersistenceFlags()
    {
        QFETCH(bool, persistentGraphics);
        QFETCH(bool, persistentSceneGraph);
        QQuickWindow window;
        renderOnceThenHide(window);
        if (QTest::currentTestFailed())
            return;
        window.setPersistentGraphics(persistentGraphics);
        window.setPersistentSceneGraph(persistentSceneGraph);

        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationSuspended);

        QCOMPARE(window.isPersistentGraphics(), persistentGraphics);
        QCOMPARE(window.isPersistentSceneGraph(), persistentSceneGraph);
    }

    void suspendKeepsTheSceneGraphOfAnExposedWindow()
    {
        QQuickWindow window;
        QSignalSpy initialized(&window, &QQuickWindow::sceneGraphInitialized);
        window.resize(100, 100);
        window.show();
        QVERIFY(QTest::qWaitForWindowExposed(&window));
        QTRY_VERIFY(initialized.count() > 0);
        QSignalSpy invalidated(&window, &QQuickWindow::sceneGraphInvalidated);

        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationSuspended);

        QCOMPARE(invalidated.count(), 0);
    }

    void otherStatesKeepTheSceneGraph()
    {
        QQuickWindow window;
        renderOnceThenHide(window);
        if (QTest::currentTestFailed())
            return;
        QSignalSpy invalidated(&window, &QQuickWindow::sceneGraphInvalidated);

        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationInactive);
        release.onApplicationStateChanged(Qt::ApplicationHidden);
        release.onApplicationStateChanged(Qt::ApplicationActive);

        QCOMPARE(invalidated.count(), 0);
    }

    void showingAgainRebuildsTheSceneGraph()
    {
        QQuickWindow window;
        renderOnceThenHide(window);
        if (QTest::currentTestFailed())
            return;
        Status::BackgroundGraphicsRelease release;
        release.onApplicationStateChanged(Qt::ApplicationSuspended);

        QSignalSpy initialized(&window, &QQuickWindow::sceneGraphInitialized);
        QSignalSpy swapped(&window, &QQuickWindow::frameSwapped);
        window.show();
        QVERIFY(QTest::qWaitForWindowExposed(&window));
        QTRY_COMPARE(initialized.count(), 1);
        QTRY_VERIFY(swapped.count() > 0);
    }

    void followsTheApplicationState()
    {
        QQuickWindow window;
        renderOnceThenHide(window);
        if (QTest::currentTestFailed())
            return;
        QSignalSpy invalidated(&window, &QQuickWindow::sceneGraphInvalidated);

        Status::BackgroundGraphicsRelease release;
        emit qApp->applicationStateChanged(Qt::ApplicationSuspended);

        QTRY_COMPARE(invalidated.count(), 1);
    }
};

int main(int argc, char* argv[])
{
    // Only the threaded render loop tears the scene graph down on request.
    qputenv("QSG_RENDER_LOOP", "threaded");
    QGuiApplication app(argc, argv);
    tst_BackgroundGraphicsRelease test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_backgroundgraphicsrelease.moc"
