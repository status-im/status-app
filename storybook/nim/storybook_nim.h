#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Installs the Nim libraries (NimQtCamera, ...) on a QQmlEngine*.
// Call once per engine, on the GUI thread.
void storybook_nim_install(void* qqmlEngine);

#ifdef __cplusplus
}
#endif
