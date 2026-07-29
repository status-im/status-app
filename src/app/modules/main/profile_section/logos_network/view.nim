import nimqml

import ./io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      peerCount: int
      peerCountLoading: bool
      peerCountError: string

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.peerCount = -1
    result.peerCountLoading = false
    result.peerCountError = ""

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc peerCountChanged*(self: View) {.signal.}
  proc getPeerCount*(self: View): int {.slot.} =
    return self.peerCount
  proc setPeerCount*(self: View, count: int) =
    if count == self.peerCount:
      return
    self.peerCount = count
    self.peerCountChanged()
  QtProperty[int] peerCount:
    read = getPeerCount
    notify = peerCountChanged

  proc peerCountLoadingChanged*(self: View) {.signal.}
  proc getPeerCountLoading*(self: View): bool {.slot.} =
    return self.peerCountLoading
  proc setPeerCountLoading*(self: View, loading: bool) =
    if loading == self.peerCountLoading:
      return
    self.peerCountLoading = loading
    self.peerCountLoadingChanged()
  QtProperty[bool] peerCountLoading:
    read = getPeerCountLoading
    notify = peerCountLoadingChanged

  proc peerCountErrorChanged*(self: View) {.signal.}
  proc getPeerCountError*(self: View): string {.slot.} =
    return self.peerCountError
  proc setPeerCountError*(self: View, error: string) =
    if error == self.peerCountError:
      return
    self.peerCountError = error
    self.peerCountErrorChanged()
  QtProperty[string] peerCountError:
    read = getPeerCountError
    notify = peerCountErrorChanged

  proc refreshPeerCount*(self: View) {.slot.} =
    if self.peerCountLoading:
      return
    self.setPeerCountLoading(true)
    self.delegate.refreshPeerCount()

  proc delete*(self: View) =
    self.QObject.delete
