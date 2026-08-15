#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QtWebView>

#include <Storybook/storybooksetup.h>
#include <Storybook/qmlfilesserver.h>

#include <memory>

#include <StatusQ/networkaccessfactory.h>
#include <StatusQ/typesregistration.h>

#include <registration.h>

extern "C" void statusq_installBoostedIncubationController(void* engine, int msPerTick,
                                                           int gentlePeriodMs, int boostGapMs);

using namespace Qt::Literals::StringLiterals;

// Mirrors NETWORK_DISK_CACHE_SIZE in src/constants.nim.
constexpr qint64 networkDiskCacheSize = 512ll * 1024 * 1024;

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

    // Same disk cache and Accept hints the application installs, so media traffic
    // measured in Storybook is the traffic the application would produce.
    Status::setupNetworkAccessManagerFactory(
        &engine, QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + u"/netcache"_s,
        networkDiskCacheSize);

    // A/B hook for the app's boosted incubation controller (externc.cpp):
    // STORYBOOK_INCUBATION_MS=20 makes async section loads incubate with a
    // fixed event-loop budget instead of the render-loop-driven default;
    // STORYBOOK_INCUBATION_GENTLE_MS / STORYBOOK_INCUBATION_GAP_MS tune the
    // gentle window and the pause between boosted bites. An unparsable or
    // non-positive budget leaves the default controller in place.
    bool incubationMsValid = false;
    const int incubationMs =
        qEnvironmentVariable("STORYBOOK_INCUBATION_MS").toInt(&incubationMsValid);
    if (incubationMsValid && incubationMs > 0)
        statusq_installBoostedIncubationController(
            &engine, incubationMs,
            qEnvironmentVariableIntValue("STORYBOOK_INCUBATION_GENTLE_MS"),
            qEnvironmentVariableIntValue("STORYBOOK_INCUBATION_GAP_MS"));

    for (auto& path : std::as_const(additionalImportPaths))
        engine.addImportPath(path);

    StorybookSetup::configureEngine(&engine, mode == u"local"_s);
    registerStatusQTypes();
    registerStorybookMocks(engine);

    // Full-size generated profiles in the interactive storybook; the pages
    // validator flips this so its per-page instantiation stays cheap.
    engine.rootContext()->setContextProperty(u"storybookSmallProfile"_s, false);

    loadContextPropertiesMocks(engine, QString::fromLatin1(QML_IMPORT_ROOT));

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
