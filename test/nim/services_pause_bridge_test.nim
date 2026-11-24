## Tests for the iOS app-lifecycle → pausable-services bridge (issue #51):
## driven over the real StatusQ appBackgrounded/appForegrounded signals,
## with the backend seam replaced by recorders.
##  - a real backgrounding (Qt::ApplicationSuspended → appBackgrounded) pauses
##    the full pausable set fetched from the backend; the matching
##    foregrounding resumes it — the chain that makes the media server rebind
##    and emit mediaserver.started (the #47 URL refresh trigger);
##  - foreground flaps with no preceding pause (share sheets and system alerts
##    dip the app to Inactive and back — appForegrounded fires on every return
##    to Active) drive nothing;
##  - repeated backgrounded events pause once; each pause resumes at most once;
##  - an empty pausable set (node not running, e.g. backgrounded on the login
##    screen) drives no pause and no resume;
##  - the second suite covers the backend response parsing (PausableServices
##    returns "null" when the node is down; Pause/ResumeServices return
##    {"error": ...} envelopes).

import unittest
import ./support/qt_app
import nimqml
import app/core/custom_urls/url_scheme_event
import app/core/services_pause_bridge
import backend/pausable_services as backend_pausable_services
import statusq_bridge
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# gen_qobject_types.QObject and make nimqml's QObject ambiguous (see url_scheme_event_test).

ensureQtCoreApp()  # one app for the whole suite

suite "services_pause_bridge":
  setup:
    let urlSchemeEvent = newUrlSchemeEvent()
    var names = @["mediaserver", "messenger", "localbackups"]
    # unittest's setup vars live at module scope: a `= 0` constant initializer is
    # emitted once and not re-run per case, so the counter must be reset here
    # explicitly (unlike the seqs, whose `@[]` runtime init already resets).
    var fetches: int
    fetches = 0
    var pauseCalls: seq[seq[string]] = @[]
    var resumeCalls: seq[seq[string]] = @[]
    let bridge = newServicesPauseBridge(urlSchemeEvent, PausableServicesCalls(
      pausableServiceNames: proc(): seq[string] =
        inc fetches
        names,
      pauseServices: proc(serviceNames: seq[string]) =
        pauseCalls.add(serviceNames),
      resumeServices: proc(serviceNames: seq[string]) =
        resumeCalls.add(serviceNames)))

  teardown:
    bridge.delete()

  test "backgrounding pauses the full pausable set":
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)

    check pauseCalls == @[@["mediaserver", "messenger", "localbackups"]]
    check resumeCalls.len == 0

  test "foregrounding after a pause resumes the services":
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)

    check pauseCalls == @[@["mediaserver", "messenger", "localbackups"]]
    check resumeCalls == @[@["mediaserver", "messenger", "localbackups"]]

  test "foregrounding without a preceding pause drives nothing":
    # Share sheets, system alerts and app start all re-enter Active without a
    # suspension; resuming never-paused services would be noise.
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)

    check fetches == 0
    check pauseCalls.len == 0
    check resumeCalls.len == 0

  test "repeated backgrounded events pause once":
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)

    check pauseCalls.len == 1

  test "each pause resumes at most once":
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)

    check pauseCalls.len == 1
    check resumeCalls.len == 1

  test "full background/foreground cycles pause and resume each time":
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)

    check pauseCalls.len == 2
    check resumeCalls.len == 2

  test "the pausable set is re-fetched at each transition":
    # Mirrors the Android service: services registered in status-go later are
    # picked up without client changes.
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    names = @["mediaserver", "messenger", "localbackups", "downloader"]
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)

    check pauseCalls == @[@["mediaserver", "messenger", "localbackups"]]
    check resumeCalls ==
      @[@["mediaserver", "messenger", "localbackups", "downloader"]]

  test "an empty pausable set drives no pause and no resume":
    # Node not running: backgrounded on the login screen. Nothing was paused,
    # so the paused latch stays clear and the foreground event returns before
    # fetching — only the backgrounding fetches.
    names = @[]
    statusq_urlscheme_emit_appbackgrounded(urlSchemeEvent.vptr)
    statusq_urlscheme_emit_appforegrounded(urlSchemeEvent.vptr)

    check fetches == 1
    check pauseCalls.len == 0
    check resumeCalls.len == 0

suite "pausable_services backend parsing":
  test "the backend procs satisfy the bridge seam (nim_status_client wiring)":
    # Mirrors the mainProc construction exactly: the plain backend procs must
    # convert to the closure-typed seam fields, and forcing their codegen
    # proves the PausableServices/PauseServices/ResumeServices importc symbols
    # link against libstatus' generated C exports. Not invoked: no node runs
    # here.
    let calls = PausableServicesCalls(
      pausableServiceNames: backend_pausable_services.pausableServiceNames,
      pauseServices: backend_pausable_services.pauseServices,
      resumeServices: backend_pausable_services.resumeServices)
    check not calls.pausableServiceNames.isNil
    check not calls.pauseServices.isNil
    check not calls.resumeServices.isNil

  test "a service list parses to its names":
    check backend_pausable_services.parsePausableServiceNames(
      """[{"name":"mediaserver","state":"running"},
          {"name":"messenger","state":"paused"}]""") ==
      @["mediaserver", "messenger"]

  test "node-not-running null response parses to no names":
    # mobile/status.go marshals the nil PausableServices() slice to "null".
    check backend_pausable_services.parsePausableServiceNames("null").len == 0

  test "empty, error-object and malformed responses parse to no names":
    check backend_pausable_services.parsePausableServiceNames("").len == 0
    check backend_pausable_services.parsePausableServiceNames("[]").len == 0
    check backend_pausable_services.parsePausableServiceNames(
      """{"error":"node stopped"}""").len == 0
    check backend_pausable_services.parsePausableServiceNames(
      "not json").len == 0

  test "entries without a usable name are skipped":
    check backend_pausable_services.parsePausableServiceNames(
      """[{"name":"mediaserver"},{"state":"running"},{"name":""}]""") ==
      @["mediaserver"]

  test "api response error envelope parses":
    check backend_pausable_services.apiResponseError("""{"error":""}""") == ""
    check backend_pausable_services.apiResponseError(
      """{"error":"service not found in registry: \"x\""}""") ==
      "service not found in registry: \"x\""
    check backend_pausable_services.apiResponseError("garbage") == ""
