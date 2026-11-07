## Feeds NimQrScan scanners from NimQtCamera frame taps.
##
## nim-qrscan doesn't know where frames come from; the host decides. Here a
## scanner's "frame source" is a NimQtCamera FrameTap handle, so in QML:
##   QrScanner { frameSource: frameTap.handle }
## Used by the app (nim_status_client.nim) and by Storybook's Nim library.

import qtcamera/types as camtypes
import qtcamera/qml as cam
import qrscan/qml as scan

when defined(android):
  # StatusQ's NativeQrCodeCapture (CameraX, no QtMultimedia): its frameSource
  # handles start above this; frames arrive on the GUI thread.
  const nativeSourceBase = 0x40000000

  type NativeConsumer = proc(user: int, data: ptr UncheckedArray[byte],
                             width, height, rowStride: cint) {.cdecl, gcsafe, raises: [].}

  {.push dynlib: "", importc.}
  proc statusq_qrcam_set_consumer(source: cint, consumer: NativeConsumer, user: int) {.cdecl.}
  proc statusq_qrcam_arm(source: cint) {.cdecl.}
  {.pop.}

  proc onNativeFrame(user: int, data: ptr UncheckedArray[byte],
                     width, height, rowStride: cint) {.cdecl, gcsafe, raises: [].} =
    scan.deliverFrame(user, toOpenArray(data, 0, int(height) * int(rowStride) - 1),
                      int(width), int(height), int(rowStride))

proc cameraFrames*(): scan.FrameSource =
  scan.FrameSource(
    attach: proc(source, scanner: int) {.gcsafe, raises: [].} =
      when defined(android):
        if source > nativeSourceBase:
          statusq_qrcam_set_consumer(cint(source), onNativeFrame, scanner)
          return
      cam.setTapConsumer(source, proc(f: sink camtypes.GrayFrame) {.gcsafe, raises: [].} =
        scan.deliverFrame(scanner, f.data, f.width, f.height, f.width)),
    requestNext: proc(source: int) {.gcsafe, raises: [].} =
      when defined(android):
        if source > nativeSourceBase:
          statusq_qrcam_arm(cint(source))
          return
      cam.armTap(source),
    detach: proc(source: int) {.gcsafe, raises: [].} =
      when defined(android):
        if source > nativeSourceBase:
          statusq_qrcam_set_consumer(cint(source), nil, 0)
          return
      cam.setTapConsumer(source, nil))
