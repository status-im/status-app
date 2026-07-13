## The single typed entry point where the platform layer (Android JNI deep-link
## hand-off, macOS QFileOpenEvent, iOS QDesktopServices handler, desktop
## single-instance forwarding) hands the app an intake event. Covers the `url`
## kind (browser candidacy slice) and the `share` kind (share target slice:
## text, links and images shared from another app launch the share flow).
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
    ExternalIntakeShare

  ExternalIntakeEvent* = object
    case kind*: ExternalIntakeKind
    of ExternalIntakeUrl:
      url*: string
    of ExternalIntakeShare:
      text*: string ## shared plain text; shared links arrive as text too
      imagePaths*: seq[string] ## app-private cached copies of shared images
                               ## (copied at receipt; never OS-managed URIs)
      destinationChatId*: string ## non-empty when the share arrived through a
                                 ## direct-share shortcut: the destination is
                                 ## already decided and the picker is skipped

  UrlIntakeRoute* = enum
    UrlIntakeDeepLink   ## existing Status deep-link routing
    UrlIntakeBrowserTab ## new tab in the in-app browser

  ExternalIntake* = ref object
    ready: bool
    pendingSlot: Option[ExternalIntakeEvent]
    onDeepLinkUrl*: proc(url: string)
    onBrowserTabUrl*: proc(url: string)
    onShare*: proc(text: string, imagePaths: seq[string], destinationChatId: string)
    onShareImagesDiscarded*: proc(imagePaths: seq[string])
      ## A buffered share carrying images was dropped without dispatch
      ## (last-wins overwrite of the pending slot); the cached copies are now
      ## unreferenced and must be released.

const StatusExternalLinkHost = "status.app"

proc isStatusWebUrl*(url: string): bool =
  ## True for web URLs on status.app or a subdomain — links Status itself
  ## handles (and the in-app browser can render). An external hand-off of such
  ## a URL routes straight back here when Status holds the browser role, so
  ## the unresolvable-deep-link fallback opens them as an in-app browser tab
  ## instead of handing off externally.
  let parsed = parseUri(url)
  let scheme = parsed.scheme.toLowerAscii()
  if scheme != "http" and scheme != "https":
    return false
  let host = parsed.hostname.toLowerAscii()
  return host == StatusExternalLinkHost or host.endsWith("." & StatusExternalLinkHost)

proc routeForUrl*(url: string): UrlIntakeRoute =
  ## Status links keep their deep-link behavior; any other web URL opens in a
  ## browser tab. Non-web schemes keep the historical deep-link path (the
  ## deep-link pipeline already falls back for unsupported links).
  if isStatusWebUrl(url):
    return UrlIntakeDeepLink
  let scheme = parseUri(url).scheme.toLowerAscii()
  if scheme == "http" or scheme == "https":
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
  of ExternalIntakeShare:
    if not self.onShare.isNil:
      self.onShare(event.text, event.imagePaths, event.destinationChatId)

proc discardPendingShareImages(self: ExternalIntake) =
  ## The pending slot is about to be overwritten (last-wins): if it holds a
  ## share carrying images, report them as discarded so the cached copies can
  ## be released.
  if self.pendingSlot.isNone or self.onShareImagesDiscarded.isNil:
    return
  let pending = self.pendingSlot.get()
  if pending.kind == ExternalIntakeShare and pending.imagePaths.len > 0:
    self.onShareImagesDiscarded(pending.imagePaths)

proc submit*(self: ExternalIntake, event: ExternalIntakeEvent) =
  ## Platform-layer entry point. Until ready, events land in the pending
  ## intake slot — single, last-wins across kinds. Empty share payloads
  ## (blank text and no images) are dropped here (the platform layer is
  ## decision-free), so they can neither launch an empty share flow nor
  ## clobber a pending intake.
  if event.kind == ExternalIntakeShare and event.text.isEmptyOrWhitespace and
      event.imagePaths.len == 0:
    return
  if not self.ready:
    self.discardPendingShareImages()
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
