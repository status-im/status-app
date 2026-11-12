#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLoggingCategory>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSemaphore>
#include <QTemporaryDir>
#include <QTest>
#include <QThread>
#include <QTimer>

#include <array>
#include <atomic>

#include <private/qhooks_p.h>

#include <StatusQ/qmlinventory.h>

namespace QmlInventory = Status::QmlInventory;

namespace
{
constexpr bool UnitsAvailable = QT_VERSION >= QT_VERSION_CHECK(6, 11, 0)
        && QT_VERSION < QT_VERSION_CHECK(6, 12, 0);

QThread* s_mainThread = nullptr;
std::atomic<QObject*> s_chainedAdd = nullptr;
std::atomic<QObject*> s_chainedRemove = nullptr;

void chainedAdd(QObject* object)
{
    if (QThread::currentThread() == s_mainThread)
        s_chainedAdd = object;
}

void chainedRemove(QObject* object)
{
    if (QThread::currentThread() == s_mainThread)
        s_chainedRemove = object;
}
} // namespace

class tst_QmlInventory : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;

    struct Fixture
    {
        QUrl leaf;
        QUrl orphan;
        QUrl unused;
        QUrl main;
        QUrl plain;
    };

    Fixture writeFixture()
    {
        return {
            writeQml(QStringLiteral("Leaf.qml"),
                     "import QtQuick\n"
                     "Item { property int tag; Rectangle {} }\n"),
            writeQml(QStringLiteral("Orphan.qml"),
                     "import QtQml\n"
                     "QtObject { property int tag }\n"),
            writeQml(QStringLiteral("Unused.qml"),
                     "import QtQuick\n"
                     "Item { property int tag }\n"),
            writeQml(QStringLiteral("Main.qml"),
                     "import QtQuick\n"
                     "Item {\n"
                     "    component Row: Item { property int row }\n"
                     "    property var orphan: Qt.createComponent(\"Orphan.qml\").createObject(null)\n"
                     "    Repeater { model: 3; delegate: Leaf {} }\n"
                     "    Leaf { property int extra }\n"
                     "    Row {}\n"
                     "    Row {}\n"
                     "    Plain {}\n"
                     "    Repeater { model: 3; delegate: Rectangle {} }\n"
                     "    Loader { sourceComponent: Component { Text {} } }\n"
                     "}\n"),
            writeQml(QStringLiteral("Plain.qml"),
                     "import QtQuick\n"
                     "Item {}\n"),
        };
    }

    QUrl writeQml(const QString& name, const QByteArray& source)
    {
        QFile file(m_dir.filePath(name));
        if (!file.open(QIODevice::WriteOnly))
            return {};
        file.write(source);
        return QUrl::fromLocalFile(file.fileName());
    }

    static QString urlOf(const QUrl& url)
    {
        return url.toString();
    }

    static int objectCount(const QJsonObject& snapshot, const QString& type,
                           const QString& creationFile, const QString& owningFile)
    {
        for (const QJsonValue& value : snapshot[QStringLiteral("objects")].toArray()) {
            const QJsonObject group = value.toObject();
            if (group[QStringLiteral("type")].toString() == type
                    && group[QStringLiteral("creationFile")].toString() == creationFile
                    && group[QStringLiteral("owningFile")].toString() == owningFile)
                return group[QStringLiteral("count")].toInt();
        }
        return 0;
    }

    static int typeCount(const QJsonObject& snapshot, const QString& type)
    {
        int count = 0;
        for (const QJsonValue& value : snapshot[QStringLiteral("objects")].toArray()) {
            const QJsonObject group = value.toObject();
            if (group[QStringLiteral("type")].toString() == type)
                count += group[QStringLiteral("count")].toInt();
        }
        return count;
    }

    static QJsonObject unitFor(const QJsonObject& snapshot, const QUrl& url)
    {
        for (const QJsonValue& value : snapshot[QStringLiteral("compilationUnits")].toArray()) {
            const QJsonObject unit = value.toObject();
            if (unit[QStringLiteral("url")].toString() == urlOf(url))
                return unit;
        }
        return {};
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QLoggingCategory::setFilterRules(QStringLiteral("status.qmlInventory.info=false"));
    }

    void parseSchedule_data()
    {
        QTest::addColumn<QByteArray>("value");
        QTest::addColumn<QList<int>>("expected");

        QTest::newRow("unset") << QByteArray() << QList<int>{};
        QTest::newRow("single") << QByteArray("60") << QList<int>{60};
        QTest::newRow("several") << QByteArray("5, 30,120") << QList<int>{5, 30, 120};
        QTest::newRow("garbage") << QByteArray("soon") << QList<int>{};
        QTest::newRow("negative") << QByteArray("10,-1") << QList<int>{};
    }

    void parseSchedule()
    {
        QFETCH(QByteArray, value);
        QFETCH(QList<int>, expected);

        QCOMPARE(QmlInventory::parseSchedule(value), expected);
    }

    void nothingIsInstalledWithoutTheEnvironmentVariable()
    {
        QVERIFY(qEnvironmentVariableIsEmpty(QmlInventory::EnvVar));
        QVERIFY(!QmlInventory::installFromEnvironment());
        QVERIFY(!QmlInventory::isInstalled());
        QCOMPARE(qtHookData[QHooks::AddQObject], quintptr(0));
        QCOMPARE(qtHookData[QHooks::RemoveQObject], quintptr(0));
    }

    // Runs before any other test installs the inventory: install() is one-shot.
    void chainsToPreviouslyInstalledHooks()
    {
        s_mainThread = QThread::currentThread();
        qtHookData[QHooks::AddQObject] = reinterpret_cast<quintptr>(&chainedAdd);
        qtHookData[QHooks::RemoveQObject] = reinterpret_cast<quintptr>(&chainedRemove);

        QmlInventory::install();
        QVERIFY(QmlInventory::isInstalled());
        QVERIFY(qtHookData[QHooks::AddQObject] != reinterpret_cast<quintptr>(&chainedAdd));

        const int timersBefore = typeCount(QmlInventory::snapshot(), QStringLiteral("QTimer"));
        auto timer = std::make_unique<QTimer>();
        QCOMPARE(s_chainedAdd.load(), timer.get());
        QCOMPARE(typeCount(QmlInventory::snapshot(), QStringLiteral("QTimer")), timersBefore + 1);

        QObject* const removed = timer.get();
        timer.reset();
        QCOMPARE(s_chainedRemove.load(), removed);
        QCOMPARE(typeCount(QmlInventory::snapshot(), QStringLiteral("QTimer")), timersBefore);
    }

    void groupsLiveObjectsAndCompilationUnits()
    {
        const auto [leaf, orphan, unused, main, plain] = writeFixture();
        QmlInventory::install();
        QVERIFY(QmlInventory::isInstalled());

        QQmlEngine engine;
        QQmlComponent mainComponent(&engine, main);
        std::unique_ptr<QObject> root(mainComponent.create());
        QVERIFY2(root, qPrintable(mainComponent.errorString()));

        QJsonObject snapshot = QmlInventory::snapshot();

        // A component instance is declared in the file that uses it and owned by
        // whoever instantiated that file; its insides are declared in its own file.
        // Leaf { property int extra } derives a class from Leaf's, with a second counter.
        QCOMPARE(objectCount(snapshot, QStringLiteral("Leaf"), urlOf(main), QString()), 4);
        QCOMPARE(objectCount(snapshot, QStringLiteral("QQuickRectangle"), urlOf(leaf), urlOf(main)), 4);
        QCOMPARE(objectCount(snapshot, QStringLiteral("Row"), urlOf(main), QString()), 2);
        QCOMPARE(objectCount(snapshot, QStringLiteral("Plain"), urlOf(main), QString()), 1);
        QCOMPARE(objectCount(snapshot, QStringLiteral("Main"), urlOf(main), QString()), 1);

        // Delegate roots are document roots of the declaring file, not instances of it.
        QCOMPARE(objectCount(snapshot, QStringLiteral("QQuickRectangle"), urlOf(main), QString()), 3);
        QCOMPARE(objectCount(snapshot, QStringLiteral("QQuickText"), urlOf(main), QString()), 1);
        QCOMPARE(objectCount(snapshot, QStringLiteral("QQuickRepeater"), urlOf(main), QString()), 2);
        QCOMPARE(objectCount(snapshot, QStringLiteral("Orphan"), urlOf(orphan), urlOf(main)), 1);
        QCOMPARE(typeCount(snapshot, QStringLiteral("QQmlEngine")), 1);

        const QJsonArray objects = snapshot[QStringLiteral("objects")].toArray();
        const auto orphanGroup = std::find_if(objects.begin(), objects.end(), [](const QJsonValue& v) {
            return v.toObject()[QStringLiteral("type")].toString() == QStringLiteral("Orphan");
        });
        QVERIFY(orphanGroup != objects.end());
        QCOMPARE(orphanGroup->toObject()[QStringLiteral("parentless")].toInt(), 1);

        root.reset();
        QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
        snapshot = QmlInventory::snapshot();

        QCOMPARE(typeCount(snapshot, QStringLiteral("Leaf")), 0);
        QCOMPARE(typeCount(snapshot, QStringLiteral("QQuickRectangle")), 0);
        QCOMPARE(typeCount(snapshot, QStringLiteral("QQuickRepeater")), 0);
        QCOMPARE(typeCount(snapshot, QStringLiteral("Row")), 0);
    }

    void listsCompilationUnitsWithTheirLiveObjects()
    {
        if (!UnitsAvailable)
            QSKIP("Compilation units are only read on Qt 6.11");

        const auto [leaf, orphan, unused, main, plain] = writeFixture();
        QmlInventory::install();

        QQmlEngine engine;
        QQmlComponent unusedComponent(&engine, unused);
        QVERIFY2(unusedComponent.isReady(), qPrintable(unusedComponent.errorString()));
        QQmlComponent mainComponent(&engine, main);
        std::unique_ptr<QObject> root(mainComponent.create());
        QVERIFY2(root, qPrintable(mainComponent.errorString()));

        QJsonObject snapshot = QmlInventory::snapshot();

        // 4 Leaf instances and the Rectangle inside each.
        const QJsonObject leafUnit = unitFor(snapshot, leaf);
        QVERIFY(!leafUnit.isEmpty());
        QCOMPARE(leafUnit[QStringLiteral("liveObjects")].toInt(), 8);
        QVERIFY(leafUnit[QStringLiteral("unitBytes")].toInt() > 0);
        QVERIFY(leafUnit[QStringLiteral("totalBytes")].toInt()
                >= leafUnit[QStringLiteral("unitBytes")].toInt());

        const QJsonObject unusedUnit = unitFor(snapshot, unused);
        QVERIFY(!unusedUnit.isEmpty());
        QCOMPARE(unusedUnit[QStringLiteral("liveObjects")].toInt(), 0);

        QVERIFY(unitFor(snapshot, main)[QStringLiteral("liveObjects")].toInt() > 0);

        root.reset();
        QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
        snapshot = QmlInventory::snapshot();
        QCOMPARE(unitFor(snapshot, leaf)[QStringLiteral("liveObjects")].toInt(), 0);
    }

    void objectsOfOtherThreadsAreOnlyCounted()
    {
        const QString otherThread = QStringLiteral("<other thread>");
        const int before = typeCount(QmlInventory::snapshot(), otherThread);

        QSemaphore created;
        QSemaphore finish;
        std::unique_ptr<QThread> thread(QThread::create([&] {
            const std::array<QObject, 10> objects;
            created.release();
            finish.acquire();
        }));
        thread->start();
        created.acquire();

        const int during = typeCount(QmlInventory::snapshot(), otherThread);
        finish.release();
        QVERIFY(thread->wait());

        // The thread's event dispatcher is another of its objects.
        QVERIFY(during >= before + 10);
        QCOMPARE(typeCount(QmlInventory::snapshot(), otherThread), before);
    }

    void writesTheSnapshotToTheOutputDir()
    {
        QTemporaryDir out;
        QVERIFY(out.isValid());
        QmlInventory::setOutputDir(out.path());

        const QUrl written = writeQml(QStringLiteral("Written.qml"),
                                      "import QtQuick\n"
                                      "Item { property int tag; Rectangle {} Rectangle {} }\n");
        QQmlEngine engine;
        QQmlComponent component(&engine, written);
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));

        const QString path = QmlInventory::writeSnapshot(2);

        QVERIFY(path.startsWith(out.path()));
        QVERIFY(QFileInfo(path).fileName().startsWith(QStringLiteral("qml-inventory-")));
        QVERIFY(path.endsWith(QStringLiteral("-2.json")));
        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QJsonObject json = QJsonDocument::fromJson(file.readAll()).object();
        QCOMPARE(objectCount(json, QStringLiteral("Written"), urlOf(written), QString()), 1);
        QCOMPARE(objectCount(json, QStringLiteral("QQuickRectangle"), urlOf(written), QString()), 2);
        if (UnitsAvailable)
            QCOMPARE(unitFor(json, written)[QStringLiteral("liveObjects")].toInt(), 3);
    }

    void theEnvironmentScheduleWritesEachSnapshot()
    {
        QTemporaryDir out;
        QVERIFY(out.isValid());
        QmlInventory::setOutputDir(out.path());
        qputenv(QmlInventory::EnvVar, "0,0");

        QVERIFY(QmlInventory::installFromEnvironment());
        qunsetenv(QmlInventory::EnvVar);

        const QDir dir(out.path());
        QTRY_COMPARE(dir.entryList({QStringLiteral("qml-inventory-*-1.json")}, QDir::Files).size(), 1);
        QTRY_COMPARE(dir.entryList({QStringLiteral("qml-inventory-*-2.json")}, QDir::Files).size(), 1);
    }
};

QTEST_MAIN(tst_QmlInventory)
#include "tst_qmlinventory.moc"
