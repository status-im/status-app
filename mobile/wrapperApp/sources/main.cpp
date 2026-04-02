#include <stdlib.h>
#include <unistd.h>
#include <qqml.h>
#include <QDir>

extern "C" {
    void NimMain();

    // Nim's staticlib expects these to be provided by the host.
    // On Android there's no traditional main(argc, argv), so provide stubs.
    int cmdCount = 0;
    char** cmdLine = nullptr;
}

int main(int argc, char* argv[])
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    qmlRegisterModule("Qt.labs.settings", 1, 1);
    qmlRegisterModule("Qt.labs.settings", 1, 0);

    qmlRegisterModuleImport("Qt.labs.settings", QQmlModuleImportModuleAny,
                       "QtCore", QQmlModuleImportLatest);
#endif

    NimMain();
    return 0;
}
