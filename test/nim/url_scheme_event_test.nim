## Unit test for the StatusQ-backed UrlSchemeEvent (app/core/custom_urls/url_scheme_event).
## Proves the C++ urlActivated(QString) signal -> by-name slot delivery via QCoreApplication.processEvents.

import unittest, os
import nimqml
import app/core/custom_urls/url_scheme_event
import statusq_bridge
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# gen_qobject_types.QObject and make the nimqml QtObject macro below ambiguous.
from seaqt/QtCore/gen_qcoreapplication import QCoreApplication, create, processEvents

QtObject:
  type Receiver = ref object of QObject
    got: string
    count: int

  proc delete(self: Receiver) =
    self.QObject.delete

  proc onUrl*(self: Receiver, url: string) {.slot.} =
    self.got = url
    inc self.count

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

discard QCoreApplication.create()  # one app for the whole suite

suite "url_scheme_event":

  test "emitDeepLink delivers the url via urlActivated to a connected slot":
    let ev = newUrlSchemeEvent()
    let r = newReceiver()
    discard QObject.connect(ev, SIGNAL("urlActivated(QString)"),
      r, SLOT("onUrl(QString)"), ConnectionType.QueuedConnection)

    statusq_urlscheme_emit_deeplink(ev.vptr, "status-app://test-deep-link".cstring)

    check r.count == 0  # QueuedConnection: not delivered synchronously

    var spins = 0
    while r.count == 0 and spins < 100:
      QCoreApplication.processEvents()
      sleep(5)
      inc spins

    check r.count == 1
    check r.got == "status-app://test-deep-link"
