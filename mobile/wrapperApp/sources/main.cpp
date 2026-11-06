#include <stdlib.h>
#include <unistd.h>
#include <qqml.h>
#include <QDir>

extern "C" {
    void NimMain();
}

int main(int argc, char* argv[])
{
    Q_INIT_RESOURCE(resources);

    // Must match the qmlcachegen shim style in Status.pro
    if (!qEnvironmentVariableIsSet("QT_QUICK_CONTROLS_STYLE"))
        qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    qmlRegisterModule("Qt.labs.settings", 1, 1);
    qmlRegisterModule("Qt.labs.settings", 1, 0);

    qmlRegisterModuleImport("Qt.labs.settings", QQmlModuleImportModuleAny,
                       "QtCore", QQmlModuleImportLatest);
#endif

    NimMain();
    return 0;
}
