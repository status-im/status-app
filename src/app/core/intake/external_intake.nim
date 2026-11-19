## The single typed entry point where the platform layer (Android JNI deep-link
## hand-off, macOS QFileOpenEvent, iOS QDesktopServices handler, desktop
## single-instance forwarding) hands the app an intake event. Covers the `url`
## kind (browser candidacy slice), the `share` kind (share target slice:
## text, links and images shared from another app launch the share flow) and
## the `file` kind (an Opened File: "Open with" shows it in a Preview Tab).
##
## Routing lives at this seam, not in the platform layer:
## - `status-app:` links and `status.app` web links keep the existing
##   deep-link behavior,
## - any other web URL is a browser-tab intake (browser candidacy: it opens as
##   a new tab in the in-app browser, browser section foregrounded),
## - a `file:` URL is an Opened File, never a deep link.
##
## The seam also owns the pending intake slot: a single, last-wins buffer
## holding an intake until the app can act on it (main-window-ready, i.e. after
## login or onboarding). It generalizes the saved-deep-link mechanism that
## previously lived in UrlsManager.

import std/[monotimes, options, os, strutils, uri]

type
  ExternalIntakeKind* = enum
    ExternalIntakeUrl
    ExternalIntakeShare
    ExternalIntakeFile

  ExternalIntakeEvent* = object
    case kind*: ExternalIntakeKind
    of ExternalIntakeUrl:
      url*: string
    of ExternalIntakeShare:
      text*: string ## shared plain text; shared links arrive as text too
      imagePaths*: seq[string] ## app-private cached copies of shared images
                               ## (copied at receipt; never OS-managed URIs)
    of ExternalIntakeFile:
      fileUrl*: string ## kept verbatim: a path may hold any whitespace
      copied*: bool ## a private copy made at receipt, released if not opened

  UrlIntakeRoute* = enum
    UrlIntakeDeepLink   ## existing Status deep-link routing
    UrlIntakeBrowserTab ## new tab in the in-app browser
    UrlIntakeOpenedFile ## a local file in a Preview Tab

  ExternalIntake* = ref object
    ready: bool
    pendingSlot: Option[ExternalIntakeEvent]
    burstCount: int
    lastFileAt: float
    clock*: proc(): float ## seconds; injectable for tests
    copyLimitBytes*: int64
    onDeepLinkUrl*: proc(url: string)
    onBrowserTabUrl*: proc(url: string)
    onShare*: proc(text: string, imagePaths: seq[string])
    onShareImagesDiscarded*: proc(imagePaths: seq[string])
      ## A buffered share carrying images was dropped without dispatch
      ## (last-wins overwrite of the pending slot); the cached copies are now
      ## unreferenced and must be released.
    onOpenedFile*: proc(fileUrl: string)
    onOpenedFileRefused*: proc(fileUrl: string)
      ## The file cannot be opened; "" stands for the rest of a burst over
      ## the limit.
    onOpenedFileCopyDiscarded*: proc(fileUrl: string)
      ## A copy made at receipt will not be opened and must be deleted.

const
  OpenedFileBurstLimit* = 10
  OpenedFileBurstGap* = 1.0 ## seconds between files of one hand-off burst
  OpenedFileCopyLimitBytes* = 200'i64 * 1024 * 1024

const StatusExternalLinkHost = "status.app"

proc isOpenedFileUrl*(url: string): bool =
  parseUri(url).scheme.toLowerAscii() == "file"

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
  if isOpenedFileUrl(url):
    return UrlIntakeOpenedFile
  let scheme = parseUri(url).scheme.toLowerAscii()
  if scheme == "http" or scheme == "https":
    return UrlIntakeBrowserTab
  return UrlIntakeDeepLink

proc monotonicSeconds(): float =
  getMonoTime().ticks.float / 1e9

proc newExternalIntake*(): ExternalIntake =
  ExternalIntake(clock: monotonicSeconds, copyLimitBytes: OpenedFileCopyLimitBytes,
    lastFileAt: NegInf)

proc openedFilePath*(fileUrl: string): string =
  decodeUrl(parseUri(fileUrl).path, decodePlus = false)

proc copyFits(self: ExternalIntake, fileUrl: string): bool =
  try:
    getFileSize(openedFilePath(fileUrl)) <= self.copyLimitBytes
  except OSError:
    false

proc discardCopy(self: ExternalIntake, event: ExternalIntakeEvent) =
  if event.copied and not self.onOpenedFileCopyDiscarded.isNil:
    self.onOpenedFileCopyDiscarded(event.fileUrl)

proc refuse(self: ExternalIntake, fileUrl: string) =
  if not self.onOpenedFileRefused.isNil:
    self.onOpenedFileRefused(fileUrl)

proc dispatchFile(self: ExternalIntake, event: ExternalIntakeEvent) =
  let now = self.clock()
  if now - self.lastFileAt > OpenedFileBurstGap:
    self.burstCount = 0
  self.lastFileAt = now
  inc self.burstCount
  if self.burstCount > OpenedFileBurstLimit:
    if self.burstCount == OpenedFileBurstLimit + 1:
      self.refuse("")
    self.discardCopy(event)
    return
  if event.copied and not self.copyFits(event.fileUrl):
    self.refuse(event.fileUrl)
    self.discardCopy(event)
    return
  if self.onOpenedFile.isNil:
    self.discardCopy(event)
    return
  self.onOpenedFile(event.fileUrl)

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
    of UrlIntakeOpenedFile:
      self.dispatchFile(ExternalIntakeEvent(kind: ExternalIntakeFile, fileUrl: event.url))
  of ExternalIntakeShare:
    if not self.onShare.isNil:
      self.onShare(event.text, event.imagePaths)
  of ExternalIntakeFile:
    self.dispatchFile(event)

proc discardPendingCopies(self: ExternalIntake) =
  ## The pending slot is about to be overwritten (last-wins): copies made at
  ## receipt for the pending intake are reported so they can be released.
  if self.pendingSlot.isNone:
    return
  let pending = self.pendingSlot.get()
  case pending.kind
  of ExternalIntakeShare:
    if pending.imagePaths.len > 0 and not self.onShareImagesDiscarded.isNil:
      self.onShareImagesDiscarded(pending.imagePaths)
  of ExternalIntakeFile:
    self.discardCopy(pending)
  of ExternalIntakeUrl:
    discard

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
    self.discardPendingCopies()
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
