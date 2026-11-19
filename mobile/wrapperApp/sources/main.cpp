#include <stdlib.h>
#include <unistd.h>
#include <qqml.h>
#include <QDir>
#include <QFile>
#include <QFileInfo>

extern "C" {
    void NimMain();
}

static void exportBuildConfig(const char* executable)
{
#if defined(Q_OS_ANDROID)
    Q_UNUSED(executable);
    QFile file(QStringLiteral("assets:/build-config"));
#else
    QFile file(QFileInfo(QString::fromLocal8Bit(executable)).absolutePath()
               + QStringLiteral("/build-config"));
#endif
    if (file.open(QIODevice::ReadOnly))
        qputenv("STATUS_RUNTIME_BUILD_CONFIG", file.readAll());
}

int main(int argc, char* argv[])
{
    Q_INIT_RESOURCE(resources);

    exportBuildConfig(argc > 0 ? argv[0] : "");

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    qmlRegisterModule("Qt.labs.settings", 1, 1);
    qmlRegisterModule("Qt.labs.settings", 1, 0);

    qmlRegisterModuleImport("Qt.labs.settings", QQmlModuleImportModuleAny,
                       "QtCore", QQmlModuleImportLatest);
#endif

    NimMain();
    return 0;
}
