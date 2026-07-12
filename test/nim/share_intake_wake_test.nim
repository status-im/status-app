## Integration test for the Nim side of the share-target hand-off
## (urls_manager + pending_intake_slot). Proves the delivery paths over the
## real StatusQ signals:
##  - the iOS extension's wake URL (unsupported openURL trick) delivers and
##    clears the App Group pending intake slot without being routed as a deep
##    link, and a share payload in the slot reaches the external intake seam
##    as SIGNAL_EXTERNAL_SHARE_INTAKE;
##  - appReady delivers a payload left behind when the wake never arrived
##    (degraded fallback: next manual app open, no data loss);
##  - the Android SEND hand-off (shareTextActivated signal) reaches
##    SIGNAL_EXTERNAL_SHARE_INTAKE, with pre-ready buffering.

import unittest, os
import nimqml
import app/core/eventemitter
import app/core/custom_urls/url_scheme_event
import app/core/custom_urls/urls_manager
import app/core/intake/pending_intake_slot
import app/global/app_signals
import app/global/single_instance
import statusq_bridge
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# gen_qobject_types.QObject and make nimqml's QObject ambiguous (see url_scheme_event_test).
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

discard QCoreApplication.create()  # one app for the whole suite

proc processEventsUntil(cond: proc(): bool) =
  var spins = 0
  while not cond() and spins < 100:
    QCoreApplication.processEvents()
    sleep(5)
    inc spins

proc drainEvents() =
  for _ in 0 ..< 10:
    QCoreApplication.processEvents()
    sleep(5)

suite "share_intake_wake":
  setup:
    # Not "share_intake_wake_test": newSingleInstance below creates its local
    # socket under that name in the temp dir and removeDir would trip on it.
    let slotDir = getTempDir() / "share_intake_wake_test_slot"
    removeDir(slotDir)
    let events = createEventEmitter()
    let urlSchemeEvent = newUrlSchemeEvent()
    let singleInstance = newSingleInstance("share_intake_wake_test", "")
    let slot = newPendingIntakeSlot(slotDir)
    let manager = newUrlsManager(events, urlSchemeEvent, singleInstance, "", slot)
    var sharedTexts: seq[string] = @[]
    events.on(SIGNAL_EXTERNAL_SHARE_INTAKE) do(e: Args):
      sharedTexts.add(ExternalShareIntakeArgs(e).text)

  teardown:
    removeDir(slotDir)

  test "wake url delivers the slot share payload to the intake seam":
    manager.appReady()
    slot.write("""{"type":"share","text":"shared from the extension"}""")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    # consumed by the manager: cleared after read, nothing left to take
    check not fileExists(slot.filePath())
    check slot.take() == ""
    check sharedTexts == @["shared from the extension"]

  test "malformed slot payload is cleared and dispatches nothing":
    manager.appReady()
    slot.write("not json at all")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check not fileExists(slot.filePath())
    check sharedTexts.len == 0

  test "android share text reaches the intake seam once ready":
    manager.appReady()

    statusq_urlscheme_emit_sharetext(urlSchemeEvent.vptr,
      "look at this https://example.com/article")
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedTexts == @["look at this https://example.com/article"]

  test "share text before appReady is buffered and delivered at appReady":
    statusq_urlscheme_emit_sharetext(urlSchemeEvent.vptr, "pre-login share")
    drainEvents() # let the queued slot run; the seam must buffer, not dispatch
    check sharedTexts.len == 0

    manager.appReady()

    check sharedTexts == @["pre-login share"]

  test "appReady delivers a payload left behind when the wake never arrived":
    slot.write("payload-from-killed-wake")

    manager.appReady()

    check not fileExists(slot.filePath())
    check slot.take() == ""

  test "appReady with an empty slot is a no-op":
    manager.appReady()
    check slot.take() == ""
