#include <stdlib.h>
#include <unistd.h>
#include <qqml.h>
#include <QDir>

extern "C" {
    void NimMain();
}

#ifdef Q_OS_IOS
// sources/ios_accessibility_crash_filter.mm -- works around a Qt 6.11 SIGBUS
// destroying Quick Controls while VoiceOver is active (#21450).
void installIosAccessibilityCrashFilter();
#endif

int main(int argc, char* argv[])
{
    Q_INIT_RESOURCE(resources);

#if defined(Q_OS_IOS) && !defined(STATUS_DISABLE_A11Y_CRASH_FILTER)
    // Must be installed before NimMain() creates the QGuiApplication so no
    // accessibility event can reach the iOS platform plugin unfiltered.
    // Define STATUS_DISABLE_A11Y_CRASH_FILTER to build a negative-test binary
    // that reproduces the Qt crash (#21450) with VoiceOver active.
    installIosAccessibilityCrashFilter();
#endif

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    qmlRegisterModule("Qt.labs.settings", 1, 1);
    qmlRegisterModule("Qt.labs.settings", 1, 0);

    qmlRegisterModuleImport("Qt.labs.settings", QQmlModuleImportModuleAny,
                       "QtCore", QQmlModuleImportLatest);
#endif

    NimMain();
    return 0;
}
