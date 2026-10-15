## Feeds NimQrScan scanners from NimQtCamera frame taps.
##
## nim-qrscan doesn't know where frames come from; the host decides. Here a
## scanner's "frame source" is a NimQtCamera FrameTap handle, so in QML:
##   QrScanner { frameSource: frameTap.handle }
## Used by the app (nim_status_client.nim) and by Storybook's Nim library.

import qtcamera/types as camtypes
import qtcamera/qml as cam
import qrscan/qml as scan

proc cameraFrames*(): scan.FrameSource =
  scan.FrameSource(
    attach: proc(source, scanner: int) {.gcsafe, raises: [].} =
      cam.setTapConsumer(source, proc(f: sink camtypes.GrayFrame) {.gcsafe, raises: [].} =
        scan.deliverFrame(scanner, f.data, f.width, f.height, f.width)),
    requestNext: proc(source: int) {.gcsafe, raises: [].} =
      cam.armTap(source),
    detach: proc(source: int) {.gcsafe, raises: [].} =
      cam.setTapConsumer(source, nil))
