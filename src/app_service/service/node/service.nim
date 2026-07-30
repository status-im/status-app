import nimqml, chronicles

import ../settings/service as settings_service
import ../node_configuration/service as node_configuration_service

import ../../../app/core/eventemitter
import ../../../app/core/signals/types
import ../../../backend/node as status_node

logScope:
  topics = "node-service"

const SIGNAL_MESSAGING_NETWORK_DISCONNECTED* = "messagingNetworkDisconnected"
const SIGNAL_MESSAGING_NETWORK_CONNECTED* = "messagingNetworkConnected"

QtObject:
  type Service* = ref object of QObject
    events*: EventEmitter
    settingsService: settings_service.Service
    nodeConfigurationService: node_configuration_service.Service
    connected: bool

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, settingsService: settings_service.Service, nodeConfigurationService: node_configuration_service.Service): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
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

  proc delete*(self: Service) =
    self.QObject.delete
