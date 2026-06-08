import nimqml, chronicles

import ../settings/service as settings_service
import ../node_configuration/service as node_configuration_service

import ../../../app/core/eventemitter
import ../../../app/core/signals/types
import ../../../backend/node as status_node

logScope:
  topics = "node-service"

# Signals which may be emitted by this service:
const SIGNAL_NETWORK_DISCONNECTED* = "networkDisconnected"
const SIGNAL_NETWORK_CONNECTED* = "networkConnected"

QtObject:
    type Service* = ref object of QObject
        events*: EventEmitter
        settingsService: settings_service.Service
        nodeConfigurationService: node_configuration_service.Service
        peers*: seq[string]
        connected: bool

    proc delete*(self: Service)
    proc newService*(events: EventEmitter, settingsService: settings_service.Service, nodeConfigurationService: node_configuration_service.Service): Service =
        new(result, delete)
        result.QObject.setup
        result.events = events
        result.settingsService = settingsService
        result.nodeConfigurationService = nodeConfigurationService
        result.peers = @[]
        result.connected = false

    proc peerSummaryChange(self: Service, peers: seq[string]) =
        if peers.len == 0 and self.connected:
            self.connected = false
            self.events.emit(SIGNAL_NETWORK_DISCONNECTED, Args())

        if peers.len > 0 and not self.connected:
            self.connected = true
            self.events.emit(SIGNAL_NETWORK_CONNECTED, Args())

        self.peers = peers

    proc init*(self: Service) =
        # Track network connectivity from peer activity reported by status-go.
        self.events.on(SignalType.DiscoverySummary.event) do(e: Args):
            self.peerSummaryChange(DiscoverySummarySignal(e).enodes)

        self.events.on(SignalType.PeerStats.event) do(e: Args):
            self.peerSummaryChange(PeerStatsSignal(e).peers)

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
