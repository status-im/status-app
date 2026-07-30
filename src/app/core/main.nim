import nimqml
import custom_urls/url_scheme_event
import app/global/single_instance
import
  eventemitter,
  ./tasks/threadpool,
  ./signals/signals_manager,
  ./custom_urls/urls_manager

export eventemitter
export threadpool, signals_manager

type StatusFoundation* = ref object
  events*: EventEmitter
  threadpool*: ThreadPool
  signalsManager*: SignalsManager
  urlsManager*: UrlsManager

proc newStatusFoundation*(): StatusFoundation =
  result = StatusFoundation()
  result.events = createEventEmitter()
  result.threadpool = newThreadPool()
  result.signalsManager = newSignalsManager(result.events)

proc delete*(self: StatusFoundation) =
  self.signalsManager.delete()
  self.urlsManager.delete()
  self.threadpool.teardown()

proc initUrlSchemeManager*(self: StatusFoundation, urlSchemeEvent: UrlSchemeEvent,
    singleInstance: SingleInstance, protocolUriOnStart: string) =
  self.urlsManager = newUrlsManager(self.events, urlSchemeEvent, singleInstance,
    protocolUriOnStart)

proc appReady*(self: StatusFoundation) =
  self.urlsManager.appReady()