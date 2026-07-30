#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickStyle>
#include <QtWebView>

#include <Storybook/storybooksetup.h>
#include <Storybook/qmlfilesserver.h>

#include <memory>

#include <StatusQ/typesregistration.h>

using namespace Qt::Literals::StringLiterals;

void loadContextPropertiesMocks(const char* storybookRoot, QQmlApplicationEngine& engine);

int main(int argc, char *argv[])
{
    bool hasExplicitStyleSet = false;
    for (size_t i = 1; i < argc; i++)
    {
        // Qt uses these standard/builtin args as soon as it sees them;
        // so process before creating qApp instance
        if (qstrcmp(argv[i], "-style") == 0) {
            hasExplicitStyleSet = true;
            break;
        }
    }

    // Required by the WalletConnectSDK view
    QtWebView::initialize();

    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName(u"Status"_s);
    QGuiApplication::setOrganizationDomain(u"status.im"_s);
    QGuiApplication::setApplicationName(u"Status Desktop Storybook"_s);
    QGuiApplication::setApplicationDisplayName(u"%1 [Qt %2]"_s.arg(
        QGuiApplication::applicationName(), qVersion()));

    if (!hasExplicitStyleSet)
        QQuickStyle::setStyle(u"Universal"_s); // only used as a basic style for SB itself

    QCommandLineParser cmdParser;
    cmdParser.addHelpOption();
    cmdParser.addPositionalArgument(u"page"_s, u"Open the given page on startup"_s);

#ifdef ANDROID
    static constexpr auto defaultMode = "remote";
#else
    static constexpr auto defaultMode = "local";
#endif

    QCommandLineOption modeOption(QStringList() << u"m"_s << u"mode"_s,
                                  u"mode (local or remote)"_s,
                                  u"mode"_s, defaultMode);

    cmdParser.addOption(modeOption);
    cmdParser.process(app.arguments());

    const QString mode = cmdParser.value(modeOption);

    if (mode != u"local"_s && mode != u"remote"_s) {
        qWarning() << "Invalid mode, use 'local' or 'remote'";
        return 0;
    }

    qputenv("QT_QUICK_CONTROLS_HOVER_ENABLED", QByteArrayLiteral("1"));
    auto chromiumFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    if(!chromiumFlags.contains("--disable-seccomp-filter-sandbox")) {
        chromiumFlags +=" --disable-seccomp-filter-sandbox";
    }
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", chromiumFlags);

    QStringList additionalImportPaths;
    additionalImportPaths << u"qrc:/"_s;

    if (mode == u"local"_s) {
        additionalImportPaths << QStringList {
            STATUSQ_MODULE_IMPORT_PATH,
            QML_IMPORT_ROOT u"/../ui/app"_s,
            QML_IMPORT_ROOT u"/../ui/imports"_s,
            QML_IMPORT_ROOT u"/src"_s,
            QML_IMPORT_ROOT u"/pages"_s,
            QML_IMPORT_ROOT u"/stubs"_s,
        };

        StorybookSetup::registerTypesLocal(
            additionalImportPaths,
            QML_IMPORT_ROOT u"/pages"_s,
            QCoreApplication::applicationDirPath() + u"/QmlTests"_s,
            QML_IMPORT_ROOT u"/qmlTests/tests"_s);
    } else {
        additionalImportPaths << u"http://localhost:8080/0"_s;

        StorybookSetup::registerTypesRemote(QUrl(u"http://localhost:8080/version"_s),
                                            QUrl(u"http://localhost:8080/pages"_s),
                                            QUrl(u"http://localhost:8080"_s));
    }

    QQmlApplicationEngine engine;

    for (auto& path : std::as_const(additionalImportPaths))
        engine.addImportPath(path);

    StorybookSetup::configureEngine(&engine, mode == u"local"_s);
    registerStatusQTypes();

    loadContextPropertiesMocks(QML_IMPORT_ROOT, engine);

    const QUrl url("qrc:/main.qml");
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [url](const QUrl &objUrl) {
        if (url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    const auto args = cmdParser.positionalArguments();
    if (!args.isEmpty())
        engine.setInitialProperties({{u"currentPage"_s, args.constFirst()}});

    if (mode == u"remote"_s) {
        auto server = new QmlFilesServer({
            STATUSQ_MODULE_IMPORT_PATH,
            // stubs first to give precedence over real stores
            QML_IMPORT_ROOT u"/stubs"_s,
            QML_IMPORT_ROOT u"/../ui/app"_s,
            QML_IMPORT_ROOT u"/../ui/imports"_s,
            QML_IMPORT_ROOT u"/src"_s,
            QML_IMPORT_ROOT u"/pages"_s,
        }, QML_IMPORT_ROOT u"/pages"_s, true, &engine);

        server->start(8080);
    }

    engine.load(url);

    qInfo() << "Storybook started, Qt runtime version:" << qVersion()
            << "; built against version:" << QLibraryInfo::version().toString()
            << "installed in:" << QLibraryInfo::path(QLibraryInfo::PrefixPath)
            << "; QQC style:" << QQuickStyle::name()
            << "; QPA:" << qApp->platformName();

    return QGuiApplication::exec();
}

void loadContextPropertiesMocks(const char* storybookRoot, QQmlApplicationEngine& engine) {
    QDirIterator it(QML_IMPORT_ROOT u"/stubs/nim/sectionmocks"_s, QDirIterator::Subdirectories);

    while (it.hasNext()) {
        it.next();
        if (it.fileInfo().isFile() && it.fileInfo().suffix() == u"qml"_s) {
            auto component = std::make_unique<QQmlComponent>(&engine, QUrl::fromLocalFile(it.filePath()));
            if (component->status() != QQmlComponent::Ready) {
                qWarning() << "Failed to load mock for" << it.filePath() << component->errorString();
                continue;
            }

            auto objPtr = std::unique_ptr<QObject>(component->create());
            if(!objPtr) {
                qWarning() << "Failed to create mock for" << it.filePath();
                continue;
            }

            if(!objPtr->property("contextPropertyName").isValid()) {
                qInfo() << "Not a mock, missing property name \"contextPropertyName\"";
                continue;
            }

            auto contextPropertyName = objPtr->property("contextPropertyName").toString();
            auto obj = objPtr.release();
            obj->setParent(&engine);
            engine.rootContext()->setContextProperty(contextPropertyName, obj);
        }
    }
}
