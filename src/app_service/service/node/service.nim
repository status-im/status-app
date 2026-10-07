import nimqml, chronicles, json

import ../settings/service as settings_service
import ../node_configuration/service as node_configuration_service

import ../../../app/core/eventemitter
import ../../../app/core/signals/types
import ../../../backend/node as status_node
import ../../../app/core/tasks/[qt, threadpool]

include async_tasks

logScope:
  topics = "node-service"

const SIGNAL_MESSAGING_NETWORK_DISCONNECTED* = "messagingNetworkDisconnected"
const SIGNAL_MESSAGING_NETWORK_CONNECTED* = "messagingNetworkConnected"
const SIGNAL_HTTP_TRAFFIC_REPORT_FETCHED* = "httpTrafficReportFetched"

type HttpTrafficReportArgs* = ref object of Args
  ## The JSON-RPC envelope status-go answered wallet_getHTTPTrafficReport with.
  report*: string
  error*: string
  ## The query the report answers.
  endpoints*: string
  key*: string

QtObject:
  type Service* = ref object of QObject
    events*: EventEmitter
    threadpool: ThreadPool
    settingsService: settings_service.Service
    nodeConfigurationService: node_configuration_service.Service
    connected: bool

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool, settingsService: settings_service.Service,
      nodeConfigurationService: node_configuration_service.Service): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.settingsService = settingsService
    result.nodeConfigurationService = nodeConfigurationService
    result.connected = false

  proc setConnected(self: Service, connected: bool) =
    if connected == self.connected:
      return

    info "waku connection status changed", connected
    self.connected = connected
    if self.connected:
      self.events.emit(SIGNAL_MESSAGING_NETWORK_CONNECTED, Args())
    else:
      self.events.emit(SIGNAL_MESSAGING_NETWORK_DISCONNECTED, Args())

  proc init*(self: Service) =
    self.events.on(SignalType.ConnectionStatusChange.event) do(e: Args):
      self.setConnected(ConnectionStatusChangeSignal(e).isOnline)

    # Seed connectivity from backend state in case first signal was emitted
    # before this service subscribed.
    self.setConnected(status_node.getConnectionStatus())

  proc isConnected*(self: Service): bool = self.connected

  proc getRpcStats*(self: Service): string =
    try:
      return status_node.getRpcStats()
    except Exception as e:
      let errDescription = e.msg
      error "error: ", errDescription

  proc resetRpcStats*(self: Service) =
    try:
      status_node.resetRpcStats()
    except Exception as e:
      let errDescription = e.msg
      error "error: ", errDescription

  ## Reads the HTTP traffic report off the GUI thread; SIGNAL_HTTP_TRAFFIC_REPORT_FETCHED
  ## carries it back. endpoints and key narrow the endpoints it carries.
  proc fetchHttpTrafficReport*(self: Service, endpoints: string, key: string) =
    let arg = FetchHttpTrafficReportTaskArg(
      tptr: fetchHttpTrafficReportTask,
      vptr: cast[uint](self.vptr),
      slot: "onHttpTrafficReportFetched",
      endpoints: endpoints,
      key: key,
    )
    self.threadpool.start(arg)

  proc onHttpTrafficReportFetched(self: Service, response: string) {.slot.} =
    var args = HttpTrafficReportArgs()
    try:
      let parsed = response.parseJson
      args.report = parsed{"report"}.getStr
      args.error = parsed{"error"}.getStr
      args.endpoints = parsed{"endpoints"}.getStr
      args.key = parsed{"key"}.getStr
    except Exception as e:
      args.error = e.msg
    self.events.emit(SIGNAL_HTTP_TRAFFIC_REPORT_FETCHED, args)

  proc resetHttpTrafficStats*(self: Service) =
    try:
      status_node.resetHttpTrafficStats()
    except Exception as e:
      let errDescription = e.msg
      error "error: ", errDescription

  proc setHttpTrafficStatsEnabled*(self: Service, enabled: bool) =
    try:
      status_node.setHttpTrafficStatsEnabled(enabled)
    except Exception as e:
      let errDescription = e.msg
      error "error: ", errDescription

  proc delete*(self: Service) =
    self.QObject.delete
