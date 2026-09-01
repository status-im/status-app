import nimqml, strutils, chronicles
import ./url_scheme_event
import app/global/single_instance
import ../eventemitter
import ../intake/external_intake

import ../../global/app_signals

logScope:
  topics = "urls-manager"

const StatusInternalLink* = "status-app://"
const StatusExternalLink* = "https://status.app/"

QtObject:
  type UrlsManager* = ref object of QObject
    events: EventEmitter
    intake: ExternalIntake

  proc setup(self: UrlsManager, urlSchemeEvent: UrlSchemeEvent,
      singleInstance: SingleInstance) =
    self.QObject.setup
    discard QObject.connect(urlSchemeEvent, SIGNAL("urlActivated(QString)"),
      self, SLOT("onUrlActivated(QString)"), ConnectionType.QueuedConnection)
    discard QObject.connect(singleInstance, SIGNAL("eventReceived(QString)"),
      self, SLOT("onUrlActivated(QString)"), ConnectionType.QueuedConnection)

  proc delete*(self: UrlsManager) =
    self.QObject.delete

  proc convertInternalLinkToExternal*(self: UrlsManager, statusDeepLink: string): string =
    let idx = find(statusDeepLink, StatusInternalLink)
    result = statusDeepLink
    if idx != -1:
      result = statusDeepLink[idx + StatusInternalLink.len .. ^1]
      result = StatusExternalLink & result

  proc onUrlActivated*(self: UrlsManager, urlRaw: string) {.slot.} =
    let url = urlRaw.multiReplace((" ", ""))
      .multiReplace(("\r\n", ""))
      .multiReplace(("\n", ""))
    self.intake.submit(ExternalIntakeEvent(kind: ExternalIntakeUrl, url: url))

  proc newUrlsManager*(events: EventEmitter, urlSchemeEvent: UrlSchemeEvent,
      singleInstance: SingleInstance, protocolUriOnStart: string): UrlsManager =
    new(result)
    result.setup(urlSchemeEvent, singleInstance)
    result.events = events
    result.intake = newExternalIntake()

    let self = result
    result.intake.onDeepLinkUrl = proc(url: string) =
      let data = StatusUrlArgs(url: self.convertInternalLinkToExternal(url))
      self.events.emit(SIGNAL_STATUS_URL_ACTIVATED, data)
    result.intake.onBrowserTabUrl = proc(url: string) =
      self.events.emit(SIGNAL_EXTERNAL_URL_INTAKE_BROWSER_TAB,
        ExternalUrlIntakeArgs(url: url))

    if protocolUriOnStart != "":
      # Launched via URL: park it in the pending intake slot until appReady.
      self.onUrlActivated(protocolUriOnStart)

  proc appReady*(self: UrlsManager) =
    self.intake.setReady()
