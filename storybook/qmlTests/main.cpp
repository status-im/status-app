#include <QAbstractItemModel>
#include <QAbstractItemModelTester>
#include <QQmlEngine>
#include <QQmlContext>
#include <QtQuickTest>

#include <StatusQ/typesregistration.h>

#ifdef BENCH_MODELS
extern "C" {
    void NimMain();
    void* createBenchHarness();
    void* getOldModelPtr();
    void* getNewModelPtr();
}
#endif

using namespace Qt::Literals::StringLiterals;

class Setup : public QObject
{
    Q_OBJECT

public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        Q_INIT_RESOURCE(storybook);

        QGuiApplication::setOrganizationName(u"Status"_s);
        QGuiApplication::setOrganizationDomain(u"status.im"_s);

        qputenv("QT_QUICK_CONTROLS_HOVER_ENABLED", "1"_ba);
        
        const QStringList additionalImportPaths {
            STATUSQ_MODULE_IMPORT_PATH,
            u"qrc:/"_s,
            QML_IMPORT_ROOT u"/../ui/app"_s,
            QML_IMPORT_ROOT u"/../ui/imports"_s,
            QML_IMPORT_ROOT u"/../ui/StatusQ/tests/qml"_s,
            QML_IMPORT_ROOT u"/stubs"_s,
            QML_IMPORT_ROOT u"/src"_s
        };

        for (const auto& path : additionalImportPaths)
            engine->addImportPath(path);

        registerStatusQTypes();

        QStandardPaths::setTestModeEnabled(true);

        QLocale::setDefault(QLocale(QLocale::English, QLocale::UnitedStates));

#ifdef BENCH_MODELS
        // Initialize Nim runtime once before touching any Nim-allocated
        // object.  Then construct the BenchHarness QObject in Nim and
        // expose it to QML as a context property.  The pointer returned
        // from createBenchHarness() is the underlying DOtherSide QObject*,
        // which is a real C++ QObject.
        NimMain();
        QObject* harness = reinterpret_cast<QObject*>(createBenchHarness());
        if (harness) {
            engine->rootContext()->setContextProperty(
                u"benchHarness"_s, harness);
        }

        // Attach a QAbstractItemModelTester to BOTH model variants.
        // The tester monitors all begin*/end* signal pairs and
        // rowCount/index/data calls, asserting Qt's model contract.  Any
        // violation (e.g. stale rowCount between begin and end, dangling
        // QModelIndex, signal pair mismatch) becomes a test failure via
        // QFAIL/QVERIFY.  This is what would have caught the staleness bug
        // we fixed by switching the model from CowSeq to a plain seq
        // mirror.
        if (auto* oldModel = reinterpret_cast<QAbstractItemModel*>(getOldModelPtr())) {
            new QAbstractItemModelTester(
                oldModel,
                QAbstractItemModelTester::FailureReportingMode::QtTest,
                engine);
        }
        if (auto* newModel = reinterpret_cast<QAbstractItemModel*>(getNewModelPtr())) {
            new QAbstractItemModelTester(
                newModel,
                QAbstractItemModelTester::FailureReportingMode::QtTest,
                engine);
        }
#endif
    }
};

QUICK_TEST_MAIN_WITH_SETUP(QmlTests, Setup)

#include "main.moc"
