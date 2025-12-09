import nimqml

import ./io_interface
import ./constants

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
    result.keycardChannelState = KEYCARD_CHANNEL_STATE_IDLE
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

  # Constants for channel states (readonly properties for QML)
  proc getStateIdle*(self: View): string {.slot.} =
    return KEYCARD_CHANNEL_STATE_IDLE
  QtProperty[string] stateIdle:
    read = getStateIdle

  proc getStateWaitingForKeycard*(self: View): string {.slot.} =
    return KEYCARD_CHANNEL_STATE_WAITING_FOR_KEYCARD
  QtProperty[string] stateWaitingForKeycard:
    read = getStateWaitingForKeycard

  proc getStateReading*(self: View): string {.slot.} =
    return KEYCARD_CHANNEL_STATE_READING
  QtProperty[string] stateReading:
    read = getStateReading

  proc getStateError*(self: View): string {.slot.} =
    return KEYCARD_CHANNEL_STATE_ERROR
  QtProperty[string] stateError:
    read = getStateError

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

