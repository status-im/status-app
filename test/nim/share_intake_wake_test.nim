## Integration test for the Nim side of the share-target hand-off
## (urls_manager + pending_intake_slot). Proves the delivery paths over the
## real StatusQ signals:
##  - the iOS extension's wake URL (unsupported openURL trick) delivers and
##    clears the App Group pending intake slot without being routed as a deep
##    link, and a share payload in the slot reaches the external intake seam
##    as SIGNAL_EXTERNAL_SHARE_INTAKE — immediately when ready, buffered until
##    appReady otherwise (login-first rule), last-wins across several shares;
##    blank/unknown-type/malformed payloads are cleared and dispatch nothing;
##  - appReady delivers a payload left behind when the wake never arrived
##    (degraded fallback: next manual app open, no data loss);
##  - foregrounding an already-running app (appForegrounded) delivers the slot
##    the same way — immediately when logged in, parked in the seam until
##    appReady when logged out; empty-slot foregrounds are no-ops;
##  - the Android SEND/SEND_MULTIPLE hand-off (shareActivated signal) reaches
##    SIGNAL_EXTERNAL_SHARE_INTAKE — text-only and with cached image paths —
##    with pre-ready buffering; a direct-share shortcut tap carries its
##    destination chat id through (empty for plain shares and slot payloads).

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
    var sharedImagePaths: seq[seq[string]] = @[]
    var sharedDestinations: seq[string] = @[]
    events.on(SIGNAL_EXTERNAL_SHARE_INTAKE) do(e: Args):
      let args = ExternalShareIntakeArgs(e)
      sharedTexts.add(args.text)
      sharedImagePaths.add(args.imagePaths)
      sharedDestinations.add(args.destinationChatId)

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

  test "wake url before appReady buffers the slot share until appReady (login-first)":
    # Logged-out share: the extension wakes the host, the host consumes the
    # slot immediately (file cleared), but the seam holds the share until
    # main-window-ready — login/onboarding first, share flow after.
    slot.write("""{"type":"share","text":"shared while logged out"}""")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check not fileExists(slot.filePath())
    check sharedTexts.len == 0

    manager.appReady()

    check sharedTexts == @["shared while logged out"]

  test "later slot share wins when several arrive before delivery":
    slot.write("""{"type":"share","text":"first share"}""")
    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    slot.write("""{"type":"share","text":"second share wins"}""")
    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    manager.appReady()

    check sharedTexts == @["second share wins"]

  test "blank slot share text is cleared and dispatches nothing":
    manager.appReady()
    slot.write("""{"type":"share","text":"   \n  "}""")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check not fileExists(slot.filePath())
    check sharedTexts.len == 0

  test "slot payload with an unknown type is cleared and dispatches nothing":
    manager.appReady()
    slot.write("""{"type":"image","path":"/somewhere.png"}""")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check not fileExists(slot.filePath())
    check sharedTexts.len == 0

  test "slot share payload with image paths reaches the intake seam":
    manager.appReady()
    slot.write("""{"type":"share","text":"pic","imagePaths":["/cache/share-intake/img.png"]}""")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check sharedTexts == @["pic"]
    check sharedImagePaths == @[@["/cache/share-intake/img.png"]]

  test "malformed slot payload is cleared and dispatches nothing":
    manager.appReady()
    slot.write("not json at all")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check not fileExists(slot.filePath())
    check sharedTexts.len == 0

  test "android share text reaches the intake seam once ready":
    manager.appReady()

    statusq_urlscheme_emit_share(urlSchemeEvent.vptr,
      "look at this https://example.com/article", "[]", "")
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedTexts == @["look at this https://example.com/article"]
    check sharedImagePaths == @[newSeq[string]()]

  test "android share with cached image paths reaches the intake seam":
    manager.appReady()

    statusq_urlscheme_emit_share(urlSchemeEvent.vptr, "gallery caption",
      """["/cache/share-intake/a.png","/cache/share-intake/b.jpg"]""", "")
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedTexts == @["gallery caption"]
    check sharedImagePaths ==
      @[@["/cache/share-intake/a.png", "/cache/share-intake/b.jpg"]]

  test "android image share with no text reaches the intake seam":
    manager.appReady()

    statusq_urlscheme_emit_share(urlSchemeEvent.vptr, "",
      """["/cache/share-intake/screenshot.png"]""", "")
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedTexts == @[""]
    check sharedImagePaths == @[@["/cache/share-intake/screenshot.png"]]

  test "android direct-share destination reaches the intake seam":
    # Direct-share shortcut tap: the OS attached the shortcut id (the chat id)
    # to the SEND intent, so the destination is already decided and the picker
    # step is skipped downstream.
    manager.appReady()

    statusq_urlscheme_emit_share(urlSchemeEvent.vptr, "to alice",
      """["/cache/share-intake/a.png"]""", "chat-alice")
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedTexts == @["to alice"]
    check sharedImagePaths == @[@["/cache/share-intake/a.png"]]
    check sharedDestinations == @["chat-alice"]

  test "android share without a shortcut id carries no destination":
    manager.appReady()

    statusq_urlscheme_emit_share(urlSchemeEvent.vptr, "plain share", "[]", "")
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedDestinations == @[""]

  test "slot share payload carries no direct-share destination":
    # iOS App Group slot path: direct-share shortcuts are Android-only, the
    # slot payload never preselects a destination.
    manager.appReady()
    slot.write("""{"type":"share","text":"from the extension"}""")

    statusq_urlscheme_emit_deeplink(urlSchemeEvent.vptr, ShareIntakeWakeUrl.cstring)
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check sharedDestinations == @[""]

  test "share text before appReady is buffered and delivered at appReady":
    statusq_urlscheme_emit_share(urlSchemeEvent.vptr, "pre-login share", "[]", "")
    drainEvents() # let the queued slot run; the seam must buffer, not dispatch
    check sharedTexts.len == 0

    manager.appReady()

    check sharedTexts == @["pre-login share"]

  test "app foregrounding delivers a payload left behind when the wake never arrived":
    # Wake-less fallback for an already-running app: the user backgrounds
    # Status, shares (extension writes the slot, openURL wake fails/dropped),
    # then manually returns to Status — the payload must not wait for a full
    # app restart.
    manager.appReady()
    slot.write("""{"type":"share","text":"delivered on foreground"}""")

    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)
    processEventsUntil(proc(): bool = sharedTexts.len > 0)

    check not fileExists(slot.filePath())
    check sharedTexts == @["delivered on foreground"]

  test "app foregrounding before appReady parks the payload until appReady (login-first)":
    # Logged-out warm app: the user foregrounds Status manually after sharing.
    # The slot is consumed from disk right away (file cleared) but the seam
    # must hold the share until login/onboarding completes — parked, not lost.
    slot.write("""{"type":"share","text":"shared while logged out, foregrounded"}""")

    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)
    processEventsUntil(proc(): bool = not fileExists(slot.filePath()))

    check not fileExists(slot.filePath())
    check sharedTexts.len == 0

    manager.appReady()

    check sharedTexts == @["shared while logged out, foregrounded"]

  test "app foregrounding with an empty slot is a no-op":
    manager.appReady()

    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)
    drainEvents()

    check sharedTexts.len == 0
    check slot.take() == ""

  test "appReady delivers a payload left behind when the wake never arrived":
    slot.write("""{"type":"share","text":"payload from a killed wake"}""")

    manager.appReady()

    check not fileExists(slot.filePath())
    check slot.take() == ""
    check sharedTexts == @["payload from a killed wake"]

  test "appReady with an empty slot is a no-op":
    manager.appReady()
    check slot.take() == ""
