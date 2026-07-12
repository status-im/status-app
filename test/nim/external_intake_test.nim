## Unit tests for the external intake seam (app/core/intake/external_intake).
## Covers the routing decision (Status links keep deep-link behavior, any other
## web URL becomes a browser-tab intake), the share-event route (share target:
## shared text/links launch the share flow) and the pending intake slot
## semantics (pre-ready buffering, single slot, last-wins across kinds,
## delivered once at ready). Prior art: url_scheme_event_test.nim exercises the
## platform side of this same boundary.

import unittest
import app/core/intake/external_intake

type Capture = ref object
  deepLinks: seq[string]
  browserTabs: seq[string]
  shares: seq[string]

proc newCapturingIntake(capture: Capture): ExternalIntake =
  result = newExternalIntake()
  result.onDeepLinkUrl = proc(url: string) =
    capture.deepLinks.add(url)
  result.onBrowserTabUrl = proc(url: string) =
    capture.browserTabs.add(url)
  result.onShareText = proc(text: string) =
    capture.shares.add(text)

proc urlIntake(url: string): ExternalIntakeEvent =
  ExternalIntakeEvent(kind: ExternalIntakeUrl, url: url)

proc shareIntake(text: string): ExternalIntakeEvent =
  ExternalIntakeEvent(kind: ExternalIntakeShare, text: text)

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

suite "external_intake status web url classification":
  ## Backs the unresolvable-deep-link fallback: a status.app web URL handed
  ## off externally routes straight back to Status when it holds the browser
  ## role, so the fallback must open it as an in-app browser tab instead.

  test "status.app web urls (incl. subdomains) are Status's own web urls":
    check isStatusWebUrl("https://status.app/c/invalid-community-key")
    check isStatusWebUrl("http://status.app/u/user-key")
    check isStatusWebUrl("https://status.app/")
    check isStatusWebUrl("https://www.status.app/c/community-id")

  test "other web urls are not Status's own":
    check not isStatusWebUrl("https://example.com/article")
    check not isStatusWebUrl("https://notstatus.app/c/x")
    check not isStatusWebUrl("https://status.app.evil.com/")

  test "non-web schemes are not renderable web urls":
    check not isStatusWebUrl("status-app://c/community-id")
    check not isStatusWebUrl("mailto:someone@example.com")
    check not isStatusWebUrl("")

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

suite "external_intake share events":

  test "share text reaches the share handler once ready":
    let capture = Capture()
    let intake = newCapturingIntake(capture)
    intake.setReady()

    intake.submit(shareIntake("look at this https://example.com/article"))

    check capture.shares == @["look at this https://example.com/article"]
    check capture.deepLinks.len == 0
    check capture.browserTabs.len == 0

  test "share submitted before ready is buffered and delivered at ready":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(shareIntake("quote from another app"))
    check capture.shares.len == 0
    check intake.hasPending()

    intake.setReady()

    check capture.shares == @["quote from another app"]
    check not intake.hasPending()

  test "the pending slot is last-wins across intake kinds":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(urlIntake("https://example.com/article"))
    intake.submit(shareIntake("second share wins"))
    intake.setReady()

    check capture.browserTabs.len == 0
    check capture.shares == @["second share wins"]

  test "a later url intake overwrites a pending share":
    let capture = Capture()
    let intake = newCapturingIntake(capture)

    intake.submit(shareIntake("first share"))
    intake.submit(urlIntake("https://status.app/c/community-id"))
    intake.setReady()

    check capture.shares.len == 0
    check capture.deepLinks == @["https://status.app/c/community-id"]

  test "blank share text dispatches nothing":
    let capture = Capture()
    let intake = newCapturingIntake(capture)
    intake.setReady()

    intake.submit(shareIntake(""))
    intake.submit(shareIntake("   \n  "))

    check capture.shares.len == 0

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
