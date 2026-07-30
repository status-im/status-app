import chronicles, json_serialization

import ./dto/node_config
import ../../../app/core/eventemitter
import ../../../backend/node_config as status_node_config
import ../../../constants as main_constants
import ../../../app/core/signals/types

export node_config

logScope:
  topics = "node-config-service"

const WAKU_VERSION_1* = 1
const WAKU_VERSION_2* = 2

const
  SIGNAL_NODE_LOG_LEVEL_UPDATE* = "nodeLogLevelUpdated"
  DEBUG_LOG_LEVELS = @["DEBUG", "TRACE"]

type
  NodeLogLevelUpdatedArgs* = ref object of Args
    logLevel*: LogLevel

type
  ArchiveProtocolMode* {.pure.} = enum
    Disabled = 0
    LogosStorage = 1
    Torrent = 2

type
  ErrorArgs* = ref object of Args
    msg*: string

type
  Service* = ref object of RootObj
    configuration: NodeConfigDto
    events: EventEmitter

# Forward declarations
proc getCommunityHistoryArchiveProtocolMode*(self: Service): ArchiveProtocolMode
proc setCommunityHistoryArchiveProtocolMode*(self: Service, mode: ArchiveProtocolMode): bool


proc delete*(self: Service) =
  discard

proc newService*(events: EventEmitter): Service =
  result = Service()
  result.events = events

proc adaptNodeSettingsForTheAppNeed(self: Service) =
  self.configuration.DataDir = "./ethereum"
  self.configuration.KeyStoreDir = "./keystore"
  self.configuration.LogFile = "./geth.log"
  self.configuration.ShhextConfig.BackupDisabledDataDir = "./"

proc init*(self: Service) =
  try:
    let response = status_node_config.getNodeConfig()
    self.configuration = response.result.toNodeConfigDto()
    self.adaptNodeSettingsForTheAppNeed()
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription
    return

proc getWakuVersion*(self: Service): int =
  if self.configuration.WakuConfig.Enabled:
    return WAKU_VERSION_1
  elif self.configuration.WakuV2Config.Enabled:
    return WAKU_VERSION_2

  error "unsupported waku version"
  return 0

proc getCommunityHistoryArchiveProtocolMode*(self: Service): ArchiveProtocolMode =
  if self.configuration.LogosStorageConfig.Enabled:
    return ArchiveProtocolMode.LogosStorage

  if self.configuration.TorrentConfig.Enabled:
    return ArchiveProtocolMode.Torrent

  return ArchiveProtocolMode.Disabled

proc enableTorrentCommunityHistoryArchiveSupport*(self: Service): bool =
  try:
    let response = status_node_config.enableTorrentCommunityHistoryArchiveSupport()
    if response.error != nil:
      let error = Json.decode($response.error, RpcError)
      raise newException(RpcException, error.message)

    self.configuration.TorrentConfig.Enabled = true
    self.configuration.LogosStorageConfig.Enabled = false
    return true
  except Exception as e:
    error "error enabling Torrent community history archive support:", errDescription = e.msg
    return false

proc enableLogosStorageCommunityHistoryArchiveSupport*(self: Service): bool =
  try:
    let response = status_node_config.enableLogosStorageCommunityHistoryArchiveSupport()
    if response.error != nil:
      let error = Json.decode($response.error, RpcError)
      raise newException(RpcException, error.message)

    self.configuration.LogosStorageConfig.Enabled = true
    self.configuration.TorrentConfig.Enabled = false
    return true
  except Exception as e:
    error "error enabling Logos Storage community history archive support:", errDescription = e.msg
    return false

proc disableCommunityHistoryArchiveSupport*(self: Service): bool =
  try:
    let response = status_node_config.disableCommunityHistoryArchiveSupport()
    if response.error != nil:
      let error = Json.decode($response.error, RpcError)
      raise newException(RpcException, error.message)

    self.configuration.TorrentConfig.Enabled = false
    self.configuration.LogosStorageConfig.Enabled = false
    return true
  except Exception as e:
    error "error disabling community history archive support: ", errDescription = e.msg
    return false

proc setCommunityHistoryArchiveProtocolMode*(self: Service, mode: ArchiveProtocolMode): bool =
  if self.getCommunityHistoryArchiveProtocolMode() == mode:
    return true

  case mode:
    of ArchiveProtocolMode.Disabled:
      return self.disableCommunityHistoryArchiveSupport()
    of ArchiveProtocolMode.LogosStorage:
      if self.getCommunityHistoryArchiveProtocolMode() == ArchiveProtocolMode.Torrent:
        if not self.disableCommunityHistoryArchiveSupport():
          return false
      return self.enableLogosStorageCommunityHistoryArchiveSupport()
    of ArchiveProtocolMode.Torrent:
      if self.getCommunityHistoryArchiveProtocolMode() == ArchiveProtocolMode.LogosStorage:
        if not self.disableCommunityHistoryArchiveSupport():
          return false
      return self.enableTorrentCommunityHistoryArchiveSupport()

proc setLightClient*(self: Service, enabled: bool): bool =
  try:
    let response = status_node_config.setLightClient(enabled)

    if response.error != nil:
      let error = Json.decode($response.error, RpcError)
      raise newException(RpcException, error.message)

    self.configuration.WakuV2Config.LightClient = enabled
    return true
  except Exception as e:
    error "failed to set light client", errDescription = e.msg
    return false

proc getLogLevel(self: Service): string =
  return self.configuration.LogLevel

proc isDebugEnabled*(self: Service): bool =
  var logLevel = self.getLogLevel()
  if main_constants.runtimeLogLevelSet():
    logLevel = main_constants.LOG_LEVEL
  return logLevel in DEBUG_LOG_LEVELS

proc setLogLevel*(self: Service, logLevel: LogLevel): bool =
  try:
    let response = status_node_config.setLogLevel(logLevel)

    if response.error != nil:
      let error = Json.decode($response.error, RpcError)
      raise newException(RpcException, error.message)

    self.configuration.LogLevel = $logLevel
    self.events.emit(SIGNAL_NODE_LOG_LEVEL_UPDATE, NodeLogLevelUpdatedArgs(logLevel: logLevel))
    return true
  except Exception as e:
    error "failed to set log level", errDescription = e.msg
    return false

proc getNimbusProxyConfig(self: Service): bool =
  return self.configuration.NimbusProxyConfig.Enabled

proc isNimbusProxyEnabled*(self: Service): bool =
  return self.getNimbusProxyConfig()

proc setNimbusProxyConfigEnabled*(self: Service, enabled: bool): bool =
  # FIXME: call status-go API to update NodeConfig
  # when this is merged https://github.com/status-im/status-go/pull/4254
  self.configuration.NimbusProxyConfig.Enabled = enabled
  return true

proc isLightClient*(self: Service): bool =
   return self.configuration.WakuV2Config.LightClient

proc isFullNode*(self: Service): bool =
   return self.configuration.WakuConfig.FullNode

proc getLogMaxBackups*(self: Service): int =
  return self.configuration.LogMaxBackups

proc setMaxLogBackups*(self: Service, value: int): bool =
  try:
    let response = status_node_config.setMaxLogBackups(value)

    if response.error != nil:
      let error = Json.decode($response.error, RpcError)
      raise newException(RpcException, error.message)

    self.configuration.LogMaxBackups = value
    return true
  except Exception as e:
    error "failed to set max log backups", errDescription = e.msg
    return false
