## External intake seam (see CONTEXT.md -> "External intake").
##
## The single typed entry point where the platform layer (Android JNI deep-link
## hand-off, macOS QFileOpenEvent, iOS QDesktopServices handler, desktop
## single-instance forwarding) hands the app an intake event. This slice covers
## the `url` kind; share payloads extend `ExternalIntakeKind` later.
##
## Routing lives at this seam, not in the platform layer:
## - `status-app:` links and `status.app` web links keep the existing
##   deep-link behavior,
## - any other web URL is a browser-tab intake (browser candidacy: it opens as
##   a new tab in the in-app browser, browser section foregrounded).
##
## The seam also owns the pending intake slot: a single, last-wins buffer
## holding an intake until the app can act on it (main-window-ready, i.e. after
## login or onboarding). It generalizes the saved-deep-link mechanism that
## previously lived in UrlsManager.

import std/[options, strutils, uri]

type
  ExternalIntakeKind* = enum
    ExternalIntakeUrl

  ExternalIntakeEvent* = object
    case kind*: ExternalIntakeKind
    of ExternalIntakeUrl:
      url*: string

  UrlIntakeRoute* = enum
    UrlIntakeDeepLink   ## existing Status deep-link routing
    UrlIntakeBrowserTab ## new tab in the in-app browser

  ExternalIntake* = ref object
    ready: bool
    pendingSlot: Option[ExternalIntakeEvent]
    onDeepLinkUrl*: proc(url: string)
    onBrowserTabUrl*: proc(url: string)

const StatusExternalLinkHost = "status.app"

proc routeForUrl*(url: string): UrlIntakeRoute =
  ## Status links keep their deep-link behavior; any other web URL opens in a
  ## browser tab. Non-web schemes keep the historical deep-link path (the
  ## deep-link pipeline already falls back for unsupported links).
  let parsed = parseUri(url)
  let scheme = parsed.scheme.toLowerAscii()
  if scheme == "http" or scheme == "https":
    let host = parsed.hostname.toLowerAscii()
    if host == StatusExternalLinkHost or host.endsWith("." & StatusExternalLinkHost):
      return UrlIntakeDeepLink
    return UrlIntakeBrowserTab
  return UrlIntakeDeepLink

proc newExternalIntake*(): ExternalIntake =
  ExternalIntake()

proc hasPending*(self: ExternalIntake): bool =
  self.pendingSlot.isSome

proc dispatch(self: ExternalIntake, event: ExternalIntakeEvent) =
  case event.kind
  of ExternalIntakeUrl:
    case routeForUrl(event.url)
    of UrlIntakeDeepLink:
      if not self.onDeepLinkUrl.isNil:
        self.onDeepLinkUrl(event.url)
    of UrlIntakeBrowserTab:
      if not self.onBrowserTabUrl.isNil:
        self.onBrowserTabUrl(event.url)

proc submit*(self: ExternalIntake, event: ExternalIntakeEvent) =
  ## Platform-layer entry point. Until ready, events land in the pending
  ## intake slot — single, last-wins.
  if not self.ready:
    self.pendingSlot = some(event)
    return
  self.dispatch(event)

proc setReady*(self: ExternalIntake) =
  ## Called at main-window-ready (after login or onboarding completes).
  ## Delivers the pending intake, if any.
  self.ready = true
  if self.pendingSlot.isSome:
    let event = self.pendingSlot.get()
    self.pendingSlot = none(ExternalIntakeEvent)
    self.dispatch(event)
