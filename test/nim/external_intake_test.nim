## Unit tests for the external intake seam (app/core/intake/external_intake).
## Covers the routing decision (Status links keep deep-link behavior, any other
## web URL becomes a browser-tab intake) and the pending intake slot semantics
## (pre-ready buffering, single slot, last-wins, delivered once at ready).
## Prior art: url_scheme_event_test.nim exercises the platform side of this
## same boundary.

import unittest
import app/core/intake/external_intake

type Capture = ref object
  deepLinks: seq[string]
  browserTabs: seq[string]

proc newCapturingIntake(capture: Capture): ExternalIntake =
  result = newExternalIntake()
  result.onDeepLinkUrl = proc(url: string) =
    capture.deepLinks.add(url)
  result.onBrowserTabUrl = proc(url: string) =
    capture.browserTabs.add(url)

proc urlIntake(url: string): ExternalIntakeEvent =
  ExternalIntakeEvent(kind: ExternalIntakeUrl, url: url)

suite "external_intake routing":

  test "status-app scheme routes as deep link":
    check routeForUrl("status-app://c/community-id") == UrlIntakeDeepLink
    check routeForUrl("status-app://u/user-key") == UrlIntakeDeepLink

  test "status.app web links route as deep link":
    check routeForUrl("https://status.app/c/community-id") == UrlIntakeDeepLink
    check routeForUrl("http://status.app/u/user-key") == UrlIntakeDeepLink
    check routeForUrl("https://status.app/") == UrlIntakeDeepLink

  test "status.app subdomains route as deep link":
    check routeForUrl("https://www.status.app/c/community-id") == UrlIntakeDeepLink

  test "arbitrary web urls route to a browser tab":
    check routeForUrl("https://example.com/article") == UrlIntakeBrowserTab
    check routeForUrl("http://example.com") == UrlIntakeBrowserTab
    check routeForUrl("https://notstatus.app/c/x") == UrlIntakeBrowserTab
    check routeForUrl("https://status.app.evil.com/") == UrlIntakeBrowserTab

  test "non-web schemes keep the historical deep-link path":
    check routeForUrl("mailto:someone@example.com") == UrlIntakeDeepLink

suite "external_intake dispatch":

  test "deep-link url reaches the deep-link handler once ready":
    let capture = Capture()
    let intake = newCapturingIntake(capture)
    intake.setReady()

    intake.submit(urlIntake("https://status.app/c/community-id"))

    check capture.deepLinks == @["https://status.app/c/community-id"]
    check capture.browserTabs.len == 0

  test "arbitrary web url reaches the browser-tab handler once ready":
    let capture = Capture()
    let intake = newCapturingIntake(capture)
    intake.setReady()

    intake.submit(urlIntake("https://example.com/article"))

    check capture.browserTabs == @["https://example.com/article"]
    check capture.deepLinks.len == 0

suite "external_intake pending slot":

  test "intake submitted before ready is buffered, not dispatched":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(urlIntake("https://example.com/article"))

    check capture.deepLinks.len == 0
    check capture.browserTabs.len == 0
    check intake.hasPending()

  test "pending intake is delivered at ready":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(urlIntake("https://example.com/article"))
    intake.setReady()

    check capture.browserTabs == @["https://example.com/article"]
    check not intake.hasPending()

  test "the slot is single and last-wins":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(urlIntake("https://first.example.com/"))
    intake.submit(urlIntake("https://status.app/c/community-id"))
    intake.setReady()

    check capture.browserTabs.len == 0
    check capture.deepLinks == @["https://status.app/c/community-id"]

  test "pending intake is delivered exactly once":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(urlIntake("https://example.com/article"))
    intake.setReady()
    intake.setReady()

    check capture.browserTabs == @["https://example.com/article"]

  test "ready with an empty slot dispatches nothing":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.setReady()

    check capture.deepLinks.len == 0
    check capture.browserTabs.len == 0

  test "after ready, intakes dispatch immediately without buffering":
    let capture = Capture()
    let intake = newCapturingIntake(capture)
    intake.setReady()

    intake.submit(urlIntake("https://example.com/one"))
    intake.submit(urlIntake("https://example.com/two"))

    check capture.browserTabs == @["https://example.com/one", "https://example.com/two"]
    check not intake.hasPending()
