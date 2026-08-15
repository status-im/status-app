#include <QDebug>
#include <QDirIterator>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QUrl>
#include <QtQuickTest>

#include <memory>

#include <StatusQ/typesregistration.h>

#include <registration.h>

using namespace Qt::Literals::StringLiterals;

extern "C" void statusq_installBoostedIncubationController(void* engine, int msPerTick,
                                                           int gentlePeriodMs, int boostGapMs);

class Setup : public QObject
{
    Q_OBJECT

public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        Q_INIT_RESOURCE(storybook);

        QGuiApplication::setOrganizationName(u"Status"_s);
        QGuiApplication::setOrganizationDomain(u"status.im"_s);

        qputenv("QT_QUICK_CONTROLS_HOVER_ENABLED", "1"_ba);

        // Same controller the application installs (src/nim_status_client.nim).
        // Without it async Loaders incubate on Qt's render-loop budget, which
        // under offscreen rendering makes a section load take tens of seconds —
        // tests would be pinning a configuration the app never runs.
        statusq_installBoostedIncubationController(engine, 20, 300, 0);


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

        registerStorybookMocks(*engine);

        // Register the same context-property mocks the storybook app uses (e.g. userProfile),
        // so components that read them (via Utils) behave the same under test.
        engine->rootContext()->setContextProperty(u"storybookSmallProfile"_s, true);
        loadContextPropertiesMocks(*engine, QString::fromLatin1(QML_IMPORT_ROOT));

        QStandardPaths::setTestModeEnabled(true);

        QLocale::setDefault(QLocale(QLocale::English, QLocale::UnitedStates));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(QmlTests, Setup)

#include "main.moc"
