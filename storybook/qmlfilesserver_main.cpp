#include <QCoreApplication>
#include <QDebug>

#include <QCommandLineParser>

#include <Storybook/qmlfilesserver.h>

using namespace Qt::Literals::StringLiterals;

static constexpr auto s_defaultPort = "8081";

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    QCommandLineParser cmdParser;
    cmdParser.addHelpOption();
    QCommandLineOption portOption({ u"p"_s, u"port"_s },
                                  u"tcp port"_s,
                                  u"port"_s, s_defaultPort);

    cmdParser.addOption(portOption);
    cmdParser.process(app.arguments());

    const QString portStr = cmdParser.value(portOption);

    bool ok = false;
    quint16 port = portStr.toUInt(&ok);

    if (!ok || port < 1024 || port > 65535) {
        qFatal() << "Invalid port specified!";
        return EXIT_FAILURE;
    }

    auto server = new QmlFilesServer({
        STATUSQ_MODULE_IMPORT_PATH,
        QML_IMPORT_ROOT u"/../ui"_s,
        QML_IMPORT_ROOT u"/../ui/app"_s,
        QML_IMPORT_ROOT u"/../ui/imports"_s,
    }, QML_IMPORT_ROOT u"/pages"_s, true, &app);

    if (!server->start(port))
        return EXIT_FAILURE;

    return QCoreApplication::exec();
}
