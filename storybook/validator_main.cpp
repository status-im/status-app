#include <QDir>
#include <QGuiApplication>
#include <QLibraryInfo>
#include <QQmlApplicationEngine>

#include <StatusQ/typesregistration.h>

using namespace Qt::Literals::StringLiterals;

int main(int argc, char *argv[])
{
    Q_INIT_RESOURCE(storybook);

    QGuiApplication app(argc, argv);

    // FIXME: revert when full integration is done
    // (https://github.com/status-im/status-app/pull/20178)
    qputenv("QT_FILE_SELECTORS", "noWebEngine");

    QGuiApplication::setOrganizationName(u"Status"_s);
    QGuiApplication::setOrganizationDomain(u"status.im"_s);

    const QString pagesPath = QML_IMPORT_ROOT u"/pages"_s;
    QDir pagesDir(pagesPath);
    const QFileInfoList files = pagesDir.entryInfoList({u"*Page.qml"_s},
                                                       QDir::Files,
                                                       QDir::Name);

    const QStringList additionalImportPaths{STATUSQ_MODULE_IMPORT_PATH,
                                            u"qrc:/"_s,
                                            QML_IMPORT_ROOT u"/../ui/app"_s,
                                            QML_IMPORT_ROOT u"/../ui/imports"_s,
                                            QML_IMPORT_ROOT u"/src"_s,
                                            QML_IMPORT_ROOT u"/stubs"_s};

    int errorCount = 0;
    QStringList warnings;
    QStringList failedPages;

    qInfo() << ">>> StoryBook page verification started; Qt runtime version:"
            << qVersion() << "; built against version:"
            << QLibraryInfo::version().toString();

    registerStatusQTypes();
    
    for (const auto &fileInfo : files) {
        warnings.clear();
        QQmlApplicationEngine engine;
        engine.setOutputWarningsToStandardError(false);
        engine.setBaseUrl(QUrl::fromLocalFile(pagesPath + QDir::separator()));

        for (const auto &path : additionalImportPaths)
            engine.addImportPath(path);

        QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app,
                         [&warnings](const QList<QQmlError> &qmlWarnings) {
            for (const auto &qmlWarning: qmlWarnings)
                warnings.append(qmlWarning.toString());
        });

        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                         &app, [&errorCount, &warnings, &failedPages](QObject *obj, const QUrl &objUrl) {
            if (!obj) {
                errorCount++;
                failedPages << objUrl.toLocalFile();

                for (const auto &warning: std::as_const(warnings))
                    qWarning() << "    " << warning;
            }
        });

        auto fileName = fileInfo.filePath();
        qInfo() << ">>> Checking StoryBook page:" << fileName;

        engine.load(fileName);
    }

    if (errorCount) {
        qWarning() << ">>> StoryBook page verification failed with" << errorCount << "errors.";
        qWarning() << ">>> StoryBook pages with errors:" << failedPages;

        return EXIT_FAILURE;
    }

    qInfo() << ">>> StoryBook page verification completed successfully.";
    return EXIT_SUCCESS;
}
