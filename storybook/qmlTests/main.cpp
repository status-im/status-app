#include <QDebug>
#include <QDirIterator>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QUrl>
#include <QtQuickTest>

#include <memory>

#include <StatusQ/typesregistration.h>

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

        // Register the same context-property mocks the storybook app uses (e.g. userProfile),
        // so components that read them (via Utils) behave the same under test.
        QDirIterator mocksIt(QML_IMPORT_ROOT u"/stubs/nim/sectionmocks"_s, QDirIterator::Subdirectories);
        while (mocksIt.hasNext()) {
            mocksIt.next();
            if (!mocksIt.fileInfo().isFile() || mocksIt.fileInfo().suffix() != u"qml"_s)
                continue;

            QQmlComponent component(engine, QUrl::fromLocalFile(mocksIt.filePath()));
            if (component.status() != QQmlComponent::Ready) {
                qWarning() << "Failed to load mock for" << mocksIt.filePath() << component.errorString();
                continue;
            }

            auto objPtr = std::unique_ptr<QObject>(component.create());
            if (!objPtr || !objPtr->property("contextPropertyName").isValid())
                continue;

            const auto contextPropertyName = objPtr->property("contextPropertyName").toString();
            auto obj = objPtr.release();
            obj->setParent(engine);
            engine->rootContext()->setContextProperty(contextPropertyName, obj);
        }

        QStandardPaths::setTestModeEnabled(true);

        QLocale::setDefault(QLocale(QLocale::English, QLocale::UnitedStates));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(QmlTests, Setup)

#include "main.moc"
