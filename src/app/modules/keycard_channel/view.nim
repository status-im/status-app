import nimqml

import ./io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keycardChannelState: string # Operational channel state

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.delegate = delegate
    result.setup()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc keycardChannelStateChanged*(self: View) {.signal.}
  proc setKeycardChannelState*(self: View, value: string) =
    if self.keycardChannelState == value:
      return
    self.keycardChannelState = value
    self.keycardChannelStateChanged()
  proc getKeycardChannelState*(self: View): string {.slot.} =
    return self.keycardChannelState
  QtProperty[string] keycardChannelState:
    read = getKeycardChannelState
    write = setKeycardChannelState
    notify = keycardChannelStateChanged

  proc keycardDismissed*(self: View) {.slot.} =
    self.setKeycardChannelState("")

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

