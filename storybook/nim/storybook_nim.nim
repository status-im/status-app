## Aggregate Nim library linked into Storybook's C++ executables. One library
## means one Nim runtime and one copy of the seaqt glue for every Nim library
## Storybook hosts. The Status app imports the same libraries directly and
## installs them the same way (src/nim_status_client.nim).

import qtcamera/qml as camqml
import qrscan/qml as scanqml
import qr_camera_frames

var nimInitialized: bool

proc NimMain() {.importc, cdecl.}

proc storybook_nim_install(engine: pointer) {.exportc, cdecl, raises: [].} =
  ## Call once per QQmlEngine, on the GUI thread.
  if not nimInitialized:
    nimInitialized = true
    NimMain()
  camqml.installOnEngine(engine)
  scanqml.installOnEngine(engine, cameraFrames())
