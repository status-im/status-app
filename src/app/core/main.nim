import nimqml
import custom_urls/url_scheme_event
import app/global/single_instance
import
  eventemitter,
  ./tasks/threadpool,
  ./signals/signals_manager,
  ./custom_urls/urls_manager,
  ./intake/pending_intake_slot

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
  ## The urls manager outlives the session: its owner deletes it.
  self.signalsManager.delete()
  self.threadpool.teardown()

proc attachUrlsManager*(self: StatusFoundation, urlsManager: UrlsManager) =
  ## The process-lifetime urls manager, attached to this session.
  self.urlsManager = urlsManager
  urlsManager.attachSession(self.events)

proc appReady*(self: StatusFoundation) =
  self.urlsManager.appReady()
