## Regression: authentication Controller.init registers permanent EventEmitter
## handlers, but delete() is a no-op — each create/destroy cycle leaks handlers.

import unittest

import app/core/eventemitter
import app/modules/shared_modules/authentication/[io_interface, controller]
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/keycardV2/dto as keycard_dto

type
  FakeAuthDelegate = ref object of AccessInterface
    stateUpdates: int
    exportFinished: int

method delete*(self: FakeAuthDelegate) =
  discard

method onKeycardStateUpdated*(self: FakeAuthDelegate, kcEvent: keycard_dto.KeycardEventDto) =
  inc self.stateUpdates

method onKeycardExportPublicKeysFinished*(self: FakeAuthDelegate,
    exportedPublicKeys: keycard_dto.KeycardExportedPublicKeysDto, error: string) =
  inc self.exportFinished

suite "authentication controller lifecycle":

  test "delete disconnects keycard state handlers":
    let events = createEventEmitter()
    let delegate = FakeAuthDelegate()
    let ctrl = newController(delegate, events, nil, nil, nil)
    ctrl.init()
    ctrl.delete()

    events.emit(SIGNAL_KEYCARD_STATE_UPDATED, KeycardEventArg(
      keycardEvent: KeycardEventDto()))

    check delegate.stateUpdates == 0

  test "recreate after delete does not stack state handlers":
    let events = createEventEmitter()
    let first = FakeAuthDelegate()
    let second = FakeAuthDelegate()

    let ctrl1 = newController(first, events, nil, nil, nil)
    ctrl1.init()
    ctrl1.delete()

    let ctrl2 = newController(second, events, nil, nil, nil)
    ctrl2.init()

    events.emit(SIGNAL_KEYCARD_STATE_UPDATED, KeycardEventArg(
      keycardEvent: KeycardEventDto()))

    check first.stateUpdates == 0
    check second.stateUpdates == 1
