import nimqml, strutils, json, chronicles
import ./url_scheme_event
import app/global/single_instance
import ../eventemitter
import ../intake/external_intake
import ../intake/pending_intake_slot
import ../intake/share_intake_cache

import ../../global/app_signals

export ShareIntakeWakeUrl

logScope:
  topics = "urls-manager"

const StatusInternalLink* = "status-app://"
const StatusExternalLink* = "https://status.app/"

QtObject:
  type UrlsManager* = ref object of QObject
    events: EventEmitter
    intake: ExternalIntake
    intakeSlot: PendingIntakeSlot

  proc setup(self: UrlsManager, urlSchemeEvent: UrlSchemeEvent,
      singleInstance: SingleInstance) =
    self.QObject.setup
    discard QObject.connect(urlSchemeEvent, SIGNAL("urlActivated(QString)"),
      self, SLOT("onUrlActivated(QString)"), ConnectionType.QueuedConnection)
    discard QObject.connect(singleInstance, SIGNAL("eventReceived(QString)"),
      self, SLOT("onUrlActivated(QString)"), ConnectionType.QueuedConnection)
    discard QObject.connect(urlSchemeEvent, SIGNAL("shareActivated(QString,QString)"),
      self, SLOT("onShareActivated(QString,QString)"), ConnectionType.QueuedConnection)
    discard QObject.connect(urlSchemeEvent, SIGNAL("appForegrounded()"),
      self, SLOT("onAppForegrounded()"), ConnectionType.QueuedConnection)

  proc delete*(self: UrlsManager) =
    self.QObject.delete

  proc consumePendingIntake(self: UrlsManager) =
    ## Delivers (reads + clears) the App Group pending intake slot written by
    ## the iOS share extension and feeds it into the external intake seam.
    ## Payload contract (ShareViewController.m):
    ## {"type": "share", "text": ..., "imagePaths": [...]} (imagePaths
    ## optional). Malformed payloads are logged and dropped — a broken slot
    ## file must never take the app down.
    if self.intakeSlot.isNil:
      return
    let payload = self.intakeSlot.take()
    if payload.len == 0:
      return
    try:
      let parsed = parseJson(payload)
      if parsed{"type"}.getStr() == "share":
        var imagePaths: seq[string] = @[]
        for pathNode in parsed{"imagePaths"}.getElems():
          imagePaths.add(pathNode.getStr())
        self.intake.submit(ExternalIntakeEvent(kind: ExternalIntakeShare,
          text: parsed{"text"}.getStr(), imagePaths: imagePaths))
      else:
        warn "pending intake slot payload has an unknown type", payload
    except CatchableError:
      warn "pending intake slot payload is not valid JSON", payload

  proc convertInternalLinkToExternal*(self: UrlsManager, statusDeepLink: string): string =
    let idx = find(statusDeepLink, StatusInternalLink)
    result = statusDeepLink
    if idx != -1:
      result = statusDeepLink[idx + StatusInternalLink.len .. ^1]
      result = StatusExternalLink & result

  proc onUrlActivated*(self: UrlsManager, urlRaw: string) {.slot.} =
    if urlRaw.strip().startsWith(ShareIntakeWakeUrl):
      # Wake ping from the share extension — not a routable deep link; the
      # actual payload travels through the App Group pending intake slot.
      self.consumePendingIntake()
      return

    let url = urlRaw.multiReplace((" ", ""))
      .multiReplace(("\r\n", ""))
      .multiReplace(("\n", ""))
    self.intake.submit(ExternalIntakeEvent(kind: ExternalIntakeUrl, url: url))

  proc onAppForegrounded*(self: UrlsManager) {.slot.} =
    ## Wake-less fallback (iOS): the app came to the foreground; if the share
    ## extension left a payload in the slot because its unsupported openURL
    ## wake failed or was dropped, deliver it now instead of waiting for the
    ## next full app start. No-op when the slot is inactive or empty.
    self.consumePendingIntake()

  proc onShareActivated*(self: UrlsManager, text: string, imagePathsJson: string) {.slot.} =
    ## Share-target hand-off (Android SEND/SEND_MULTIPLE intents): shared
    ## text/links and images launch the share flow. The text is kept verbatim —
    ## unlike URLs it may legitimately contain whitespace and newlines; image
    ## paths are app-private cached copies made by the platform layer at
    ## receipt.
    self.intake.submit(ExternalIntakeEvent(kind: ExternalIntakeShare,
      text: text, imagePaths: parseImagePathsJson(imagePathsJson)))

  proc newUrlsManager*(events: EventEmitter, urlSchemeEvent: UrlSchemeEvent,
      singleInstance: SingleInstance, protocolUriOnStart: string,
      intakeSlot: PendingIntakeSlot = nil): UrlsManager =
    new(result)
    result.setup(urlSchemeEvent, singleInstance)
    result.events = events
    result.intake = newExternalIntake()
    result.intakeSlot = intakeSlot

    let self = result
    result.intake.onDeepLinkUrl = proc(url: string) =
      let data = StatusUrlArgs(url: self.convertInternalLinkToExternal(url))
      self.events.emit(SIGNAL_STATUS_URL_ACTIVATED, data)
    result.intake.onBrowserTabUrl = proc(url: string) =
      self.events.emit(SIGNAL_EXTERNAL_URL_INTAKE_BROWSER_TAB,
        ExternalUrlIntakeArgs(url: url))
    result.intake.onShare = proc(text: string, imagePaths: seq[string]) =
      self.events.emit(SIGNAL_EXTERNAL_SHARE_INTAKE,
        ExternalShareIntakeArgs(text: text, imagePaths: imagePaths))
    result.intake.onShareImagesDiscarded = proc(imagePaths: seq[string]) =
      # A pending share was replaced last-wins before delivery: its cached
      # image copies are unreferenced now and must not accumulate.
      releaseCachedShareFiles(imagePaths)

    if protocolUriOnStart != "":
      # Launched via URL: park it in the pending intake slot until appReady.
      self.onUrlActivated(protocolUriOnStart)

  proc appReady*(self: UrlsManager) =
    self.intake.setReady()
    # Degraded fallback: if the extension's unsupported openURL wake never
    # arrived (killed, or the OS dropped it), the payload is still sitting in
    # the slot — deliver it on this (manual) open. No-op when the slot is empty.
    self.consumePendingIntake()
