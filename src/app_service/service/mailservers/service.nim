import nimqml, tables, json, sequtils, strutils, system, chronicles

import ./dto/mailserver as mailserver_dto
import ../../../app/core/signals/types
import ../../../app/core/[main]
import ../../../app/core/tasks/[qt, threadpool]
import ../settings/service as settings_service
import ../node_configuration/service as node_configuration_service
import ../../../backend/mailservers as status_mailservers

logScope:
  topics = "mailservers-service"

type
  ActiveMailserverChangedArgs* = ref object of Args
    nodeAddress*: string
    nodeId*: string

  MailserverSyncedArgs* = ref object of Args
    chatId*: string
    syncedFrom*: int64

  FillGapsTaskArg* = ref object of QObjectTaskArg
    chatId*: string
    messageIds*: seq[string]

# Signals which may be emitted by this service:
const SIGNAL_ACTIVE_MAILSERVER_CHANGED* = "activeMailserverChanged"
const SIGNAL_MAILSERVER_NOT_WORKING* = "mailserverNotWorking"
const SIGNAL_MAILSERVER_SYNCED* = "mailserverSynced"
const SIGNAL_MAILSERVER_HISTORY_REQUEST_STARTED* = "historyRequestStarted"
const SIGNAL_MAILSERVER_HISTORY_REQUEST_COMPLETED* = "historyRequestCompleted"

proc fillGapsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FillGapsTaskArg](argEncoded)
  try:
    info "Requesting fill gaps", chatId=arg.chatId, messageIds=arg.messageIds
    discard status_mailservers.fillGaps(arg.chatId, arg.messageIds)
  except Exception as e:
    warn "Could not fill gaps due to error", errDescription=e.msg

QtObject:
  type Service* = ref object of QObject
    mailservers: seq[tuple[name: string, nodeAddress: string]]
    events: EventEmitter
    threadpool: ThreadPool
    settingsService: settings_service.Service
    nodeConfigurationService: node_configuration_service.Service

  # Forward declaration:
  proc doConnect(self: Service)

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool,
    settingsService: settings_service.Service,
    nodeConfigurationService: node_configuration_service.Service): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.settingsService = settingsService
    result.nodeConfigurationService = nodeConfigurationService

  proc init*(self: Service) =
    self.doConnect()

  proc fillGaps*(self: Service, chatId: string, messageId: string) =
    let arg = FillGapsTaskArg(
      tptr: fillGapsTask,
      vptr: cast[uint](self.vptr),
      chatId: chatId,
      messageIds: @[messageId]
    )
    self.threadpool.start(arg)

  proc doConnect(self: Service) =
    self.events.on(SignalType.MailserverChanged.event) do(e: Args):
      let receivedData = MailserverChangedSignal(e)
      let address = receivedData.address
      let id = receivedData.id

      info "active mailserver changed", node=address, id = id
      let activeMailserverData = ActiveMailserverChangedArgs(nodeAddress: address, nodeId: id)
      self.events.emit(SIGNAL_ACTIVE_MAILSERVER_CHANGED, activeMailserverData)

    self.events.on(SignalType.MailserverNotWorking.event) do(e: Args):
      info "mailserver not working"
      self.events.emit(SIGNAL_MAILSERVER_NOT_WORKING, Args())

    self.events.on(SignalType.HistoryRequestStarted.event) do(e: Args):
      let h = HistoryRequestStartedSignal(e)
      info "history request started", numBatches=h.numBatches
      self.events.emit(SIGNAL_MAILSERVER_HISTORY_REQUEST_STARTED, Args())

    self.events.on(SignalType.HistoryRequestCompleted.event) do(e: Args):
      let h = HistoryRequestCompletedSignal(e)
      info "history request completed"
      self.events.emit(SIGNAL_MAILSERVER_HISTORY_REQUEST_COMPLETED, Args())

  proc delete*(self: Service) =
    self.QObject.delete

