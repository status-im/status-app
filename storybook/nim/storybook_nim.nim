## Aggregate Nim library linked into Storybook's C++ executables. One library
## means one Nim runtime and one copy of the seaqt glue for every Nim library
## Storybook hosts (nim-qtcamera now, nim-qrscan later). The Status app imports
## the same libraries directly and calls their `install(engine)`.

import qtcamera/qml

var nimInitialized: bool

proc NimMain() {.importc, cdecl.}

proc storybook_nim_install(engine: pointer) {.exportc, cdecl, raises: [].} =
  ## Call once per QQmlEngine, on the GUI thread.
  if not nimInitialized:
    nimInitialized = true
    NimMain()
  installOnEngine(engine)
