import json, marshal

include  ../../../common/json_utils

#################################################
# Important note:
#
# Uppercase letters are used in properties in object types deliberately, cause
# we're following "keys" which are received from `status-go`
#
# Why do we do that?
# Cause we're storing node configuration to the settings as JsonNode, and in order to
# convert `NodeConfigDto` to JsonNode we're using `marshal` Nim's module, which actually
# follows property names inside object types and convert them to "keys" of json object.
# That further means if we want to have parsing procs from this file reusable we have
# to store "keys" as they are received.
#################################################

type
  UpstreamConfig* = object
    Enabled*: bool
    URL*: string

  Network* = object
    chainId*: int
    chainName*: string
    rpcUrl*: string
    blockExplorerUrl*: string
    nativeCurrencyName*: string
    nativeCurrencySymbol*: string
    nativeCurrencyDecimals*: int
    isTest*: bool
    layer*: int
    enabled*: bool

  ClusterConfig* = object
    Enabled*: bool
    Fleet*: string
    StaticNodes*: seq[string]
    BootNodes*: seq[string]
    TrustedMailServers*: seq[string]
    PushNotificationsServers*: seq[string]
    RendezvousNodes*: seq[string]
    WakuNodes*: seq[string]
    DiscV5BootstrapNodes*: seq[string]
    ClusterID*: int


  LightEthConfig* = object
    Enabled*: bool
    DatabaseCache*: int
    TrustedNodes*: seq[string]
    MinTrustedFraction*: int

  PGConfig* = object
    Enabled*: bool
    URI*: string

  DatabaseConfig* = object
    PgConfig*: PGConfig

  WakuConfig* = object
    Enabled*: bool
    LightClient*: bool
    FullNode*: bool
    EnableMailServer*: bool
    DataDir*: string
    MinimumPoW*: float
    MailServerPassword*: string
    MailServerRateLimit*: int
    MailServerDataRetention*: int
    TTL: int64
    MaxMessageSize*: int
    DatabaseConfig*: DatabaseConfig
    EnableRateLimiter*: bool
    PacketRateLimitIP*: int
    PacketRateLimitPeerID*: int
    BytesRateLimitIP*: int
    BytesRateLimitPeerID*: int
    RateLimitTolerance*: int
    BloomFilterMode*: bool
    SoftBlacklistedPeerIDs*: seq[string]
    EnableConfirmations*: bool
    DiscoveryLimit*: int
    Rendezvous*: bool

  Waku2Config = object
    Enabled*: bool
    Rendezvous*: bool
    Host*: string
    Port*: int
    KeepAliveInterval*: int
    LightClient*: bool
    FullNode*: bool
    DiscoveryLimit*: int
    PersistPeers*: bool
    DataDir*: string
    MaxMessageSize*: int
    EnableConfirmations*: bool
    PeerExchange*: bool
    EnableDiscV5*: bool
    UDPPort*: int
    AutoUpdate*: bool
    EnableStore*: bool
    StoreCapacity*: int
    StoreSeconds*: int
    EnableFilterFullNode*: bool
    UseShardAsDefaultTopic*: bool

  NimbusProxyConfig* = object
    Enabled*: bool

  ShhextConfig* = object
    PFSEnabled*: bool
    BackupDisabledDataDir*: string
    InstallationID*: string
    MailServerConfirmations*: bool
    EnableConnectionManager*: bool
    EnableLastUsedMonitor*: bool
    ConnectionTarget*: int
    RequestsDelay*: int
    MaxServerFailures*: int
    MaxMessageDeliveryAttempts*: int
    WhisperCacheDir*: string
    DisableGenericDiscoveryTopic*: bool
    SendV1Messages*: bool
    DataSyncEnabled*: bool
    VerifyTransactionURL*: string
    VerifyENSURL*: string
    VerifyENSContractAddress*: string
    VerifyTransactionChainID*: int
    DefaultPushNotificationsServers*: seq[string] # not sure about the type, but we don't use it, so doesn't matter
    AnonMetricsSendID*: string
    AnonMetricsServerEnabled*: bool
    AnonMetricsServerPostgresURI*: string
    BandwidthStatsEnabled*: bool

  BridgeConfig* = object
    Enabled*: bool

  WalletConfig* = object
    Enabled*: bool

  LocalNotificationsConfig* = object
    Enabled*: bool

  BrowsersConfig* = object
    Enabled*: bool

  PermissionsConfig* = object
    Enabled*: bool

  MailserversConfig* = object
    Enabled*: bool

  Web3ProviderConfig* = object
    Enabled*: bool

  EnsConfig* = object
    Enabled*: bool

  SwarmConfig* = object
    Enabled*: bool

  TorrentConfig* = object
    Enabled*: bool

  LogosStorageConfig* = object
    Enabled*: bool

  Whisper* = object
    Min*: int
    Max*: int

  RequireTopics* = object
    whisper*: Whisper

  PushNotificationServerConfig* = object
    Enabled*: bool
    #Identity*: seq[string] # not sure about the type, but we don't use it, so doesn't matter
    GorushURL*: string
    #Logger*: seq[string] # not sure about the type, but we don't use it, so doesn't matter

type
  NodeConfigDto* = object
    NetworkId*: int
    DataDir*: string
    KeyStoreDir*: string
    NodeKey*: string
    NoDiscovery*: bool
    Rendezvous*: bool
    ListenAddr*: string
    AdvertiseAddr*: string
    Name*: string
    Version*: string
    APIModules*: string
    HTTPEnabled*: bool
    HTTPHost*: string
    HTTPPort*: int
    # HTTPVirtualHosts*: string # not sure about the type, but we don't use it, so doesn't matter
    # HTTPCors*: string # not sure about the type, but we don't use it, so doesn't matter
    IPCEnabled*: bool
    IPCFile*: string
    TLSEnabled*: bool
    MaxPeers*: int
    MaxPendingPeers*: int
    LogEnabled*: bool
    LogMobileSystem*: bool
    LogDir*: string
    LogFile*: string
    LogLevel*: string
    LogMaxBackups*: int
    LogMaxSize*: int
    LogCompressRotated*: bool
    LogToStderr*: bool
    EnableStatusService*: bool
    EnableNTPSync*: bool
    UpstreamConfig*: UpstreamConfig
    Networks*: seq[Network]
    ClusterConfig*: ClusterConfig
    LightEthConfig*: LightEthConfig
    WakuConfig*: WakuConfig
    WakuV2Config*: Waku2Config
    TorrentConfig*: TorrentConfig
    LogosStorageConfig*: LogosStorageConfig
    BridgeConfig*: BridgeConfig
    ShhextConfig*: ShhextConfig
    WalletConfig*: WalletConfig
    LocalNotificationsConfig*: LocalNotificationsConfig
    BrowsersConfig*: BrowsersConfig
    PermissionsConfig*: PermissionsConfig
    MailserversConfig*: MailserversConfig
    Web3ProviderConfig*: Web3ProviderConfig
    EnsConfig*: EnsConfig
    SwarmConfig*: SwarmConfig
    RegisterTopics*: seq[string]
    RequireTopics*: RequireTopics
    MailServerRegistryAddress*: string
    PushNotificationServerConfig*: PushNotificationServerConfig # not used in the app yet
    NimbusProxyConfig*: NimbusProxyConfig

proc toUpstreamConfig*(jsonObj: JsonNode): UpstreamConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("URL", result.URL)

proc toNimbusProxyConfig*(jsonObj: JsonNode): NimbusProxyConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toNetwork*(jsonObj: JsonNode): Network =
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("chainName", result.chainName)
  discard jsonObj.getProp("rpcUrl", result.rpcUrl)
  discard jsonObj.getProp("blockExplorerUrl", result.blockExplorerUrl)
  discard jsonObj.getProp("nativeCurrencyName", result.nativeCurrencyName)
  discard jsonObj.getProp("nativeCurrencySymbol", result.nativeCurrencySymbol)
  discard jsonObj.getProp("nativeCurrencyDecimals", result.nativeCurrencyDecimals)
  discard jsonObj.getProp("isTest", result.isTest)
  discard jsonObj.getProp("layer", result.layer)
  discard jsonObj.getProp("enabled", result.enabled)

proc toClusterConfig*(jsonObj: JsonNode): ClusterConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("Fleet", result.Fleet)
  discard jsonObj.getProp("ClusterID", result.ClusterID)

  var arr: JsonNode
  if(jsonObj.getProp("StaticNodes", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.StaticNodes.add(valueObj.getStr)

  if(jsonObj.getProp("BootNodes", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.BootNodes.add(valueObj.getStr)

  if(jsonObj.getProp("TrustedMailServers", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.TrustedMailServers.add(valueObj.getStr)

  if(jsonObj.getProp("PushNotificationsServers", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.PushNotificationsServers.add(valueObj.getStr)

  if(jsonObj.getProp("RendezvousNodes", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.RendezvousNodes.add(valueObj.getStr)

  if(jsonObj.getProp("WakuNodes", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.WakuNodes.add(valueObj.getStr)

  if(jsonObj.getProp("DiscV5BootstrapNodes", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.DiscV5BootstrapNodes.add(valueObj.getStr)


proc toLightEthConfig*(jsonObj: JsonNode): LightEthConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("DatabaseCache", result.DatabaseCache)
  discard jsonObj.getProp("MinTrustedFraction", result.MinTrustedFraction)

  var arr: JsonNode
  if(jsonObj.getProp("TrustedNodes", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.TrustedNodes.add(valueObj.getStr)

proc toPGConfig*(jsonObj: JsonNode): PGConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("URI", result.URI)

proc toDatabaseConfig*(jsonObj: JsonNode): DatabaseConfig =
  var pgConfigObj: JsonNode
  if(jsonObj.getProp("PGConfig", pgConfigObj)):
    result.PGConfig = toPGConfig(pgConfigObj)

proc toTorrentConfig*(jsonObj: JsonNode): TorrentConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toLogosStorageConfig*(jsonObj: JsonNode): LogosStorageConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toWaku2Config*(jsonObj: JsonNode): Waku2Config =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("Rendezvous", result.Rendezvous)
  discard jsonObj.getProp("Host", result.Host)
  discard jsonObj.getProp("Port", result.Port)
  discard jsonObj.getProp("KeepAliveInterval", result.KeepAliveInterval)
  discard jsonObj.getProp("LightClient", result.LightClient)
  discard jsonObj.getProp("FullNode", result.FullNode)
  discard jsonObj.getProp("DiscoveryLimit", result.DiscoveryLimit)
  discard jsonObj.getProp("PersistPeers", result.PersistPeers)
  discard jsonObj.getProp("DataDir", result.DataDir)
  discard jsonObj.getProp("MaxMessageSize", result.MaxMessageSize)
  discard jsonObj.getProp("EnableConfirmations", result.EnableConfirmations)
  discard jsonObj.getProp("PeerExchange", result.PeerExchange)
  discard jsonObj.getProp("EnableDiscV5", result.EnableDiscV5)
  discard jsonObj.getProp("UDPPort", result.UDPPort)
  discard jsonObj.getProp("AutoUpdate", result.AutoUpdate)
  discard jsonObj.getProp("EnableStore", result.EnableStore)
  discard jsonObj.getProp("StoreCapacity", result.StoreCapacity)
  discard jsonObj.getProp("StoreSeconds", result.StoreSeconds)
  discard jsonObj.getProp("EnableFilterFullNode", result.EnableFilterFullNode)
  discard jsonObj.getProp("UseShardAsDefaultTopic", result.UseShardAsDefaultTopic)

proc toWakuConfig*(jsonObj: JsonNode): WakuConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("LightClient", result.LightClient)
  discard jsonObj.getProp("FullNode", result.FullNode)
  discard jsonObj.getProp("EnableMailServer", result.EnableMailServer)
  discard jsonObj.getProp("DataDir", result.DataDir)
  discard jsonObj.getProp("MinimumPoW", result.MinimumPoW)
  discard jsonObj.getProp("MailServerPassword", result.MailServerPassword)
  discard jsonObj.getProp("MailServerRateLimit", result.MailServerRateLimit)
  discard jsonObj.getProp("MailServerDataRetention", result.MailServerDataRetention)
  discard jsonObj.getProp("TTL", result.TTL)
  discard jsonObj.getProp("MaxMessageSize", result.MaxMessageSize)
  discard jsonObj.getProp("EnableRateLimiter", result.EnableRateLimiter)
  discard jsonObj.getProp("PacketRateLimitIP", result.PacketRateLimitIP)
  discard jsonObj.getProp("PacketRateLimitPeerID", result.PacketRateLimitPeerID)
  discard jsonObj.getProp("BytesRateLimitIP", result.BytesRateLimitIP)
  discard jsonObj.getProp("BytesRateLimitPeerID", result.BytesRateLimitPeerID)
  discard jsonObj.getProp("RateLimitTolerance", result.RateLimitTolerance)
  discard jsonObj.getProp("BloomFilterMode", result.BloomFilterMode)
  discard jsonObj.getProp("EnableConfirmations", result.EnableConfirmations)
  discard jsonObj.getProp("DiscoveryLimit", result.DiscoveryLimit)
  discard jsonObj.getProp("Rendezvous", result.Rendezvous)

  var databaseConfigObj: JsonNode
  if(jsonObj.getProp("DatabaseConfig", databaseConfigObj)):
    result.DatabaseConfig = toDatabaseConfig(databaseConfigObj)

  var arr: JsonNode
  if(jsonObj.getProp("SoftBlacklistedPeerIDs", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.SoftBlacklistedPeerIDs.add(valueObj.getStr)

proc toShhextConfig*(jsonObj: JsonNode): ShhextConfig =
  discard jsonObj.getProp("PFSEnabled", result.PFSEnabled)
  discard jsonObj.getProp("BackupDisabledDataDir", result.BackupDisabledDataDir)
  discard jsonObj.getProp("InstallationID", result.InstallationID)
  discard jsonObj.getProp("MailServerConfirmations", result.MailServerConfirmations)
  discard jsonObj.getProp("EnableConnectionManager", result.EnableConnectionManager)
  discard jsonObj.getProp("EnableLastUsedMonitor", result.EnableLastUsedMonitor)
  discard jsonObj.getProp("ConnectionTarget", result.ConnectionTarget)
  discard jsonObj.getProp("RequestsDelay", result.RequestsDelay)
  discard jsonObj.getProp("MaxServerFailures", result.MaxServerFailures)
  discard jsonObj.getProp("MaxMessageDeliveryAttempts", result.MaxMessageDeliveryAttempts)
  discard jsonObj.getProp("WhisperCacheDir", result.WhisperCacheDir)
  discard jsonObj.getProp("DisableGenericDiscoveryTopic", result.DisableGenericDiscoveryTopic)
  discard jsonObj.getProp("SendV1Messages", result.SendV1Messages)
  discard jsonObj.getProp("DataSyncEnabled", result.DataSyncEnabled)
  discard jsonObj.getProp("VerifyTransactionURL", result.VerifyTransactionURL)
  discard jsonObj.getProp("VerifyENSURL", result.VerifyENSURL)
  discard jsonObj.getProp("VerifyENSContractAddress", result.VerifyENSContractAddress)
  discard jsonObj.getProp("VerifyTransactionChainID", result.VerifyTransactionChainID)
  discard jsonObj.getProp("AnonMetricsSendID", result.AnonMetricsSendID)
  discard jsonObj.getProp("AnonMetricsServerEnabled", result.AnonMetricsServerEnabled)
  discard jsonObj.getProp("AnonMetricsServerPostgresURI", result.AnonMetricsServerPostgresURI)
  discard jsonObj.getProp("BandwidthStatsEnabled", result.BandwidthStatsEnabled)

  var arr: JsonNode
  if(jsonObj.getProp("DefaultPushNotificationsServers", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.DefaultPushNotificationsServers.add(valueObj.getStr)

proc toBridgeConfig*(jsonObj: JsonNode): BridgeConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toWalletConfig*(jsonObj: JsonNode): WalletConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toLocalNotificationsConfig*(jsonObj: JsonNode): LocalNotificationsConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toBrowsersConfig*(jsonObj: JsonNode): BrowsersConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toPermissionsConfig*(jsonObj: JsonNode): PermissionsConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toMailserversConfig*(jsonObj: JsonNode): MailserversConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toWeb3ProviderConfig*(jsonObj: JsonNode): Web3ProviderConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toEnsConfig*(jsonObj: JsonNode): EnsConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toSwarmConfig*(jsonObj: JsonNode): SwarmConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)

proc toWhisper*(jsonObj: JsonNode): Whisper =
  discard jsonObj.getProp("Min", result.Min)
  discard jsonObj.getProp("Max", result.Max)

proc toRequireTopics*(jsonObj: JsonNode): RequireTopics =
  var whisperObj: JsonNode
  if(jsonObj.getProp("whisper", whisperObj)):
    result.whisper = toWhisper(whisperObj)

proc toPushNotificationServerConfig*(jsonObj: JsonNode): PushNotificationServerConfig =
  discard jsonObj.getProp("Enabled", result.Enabled)
  discard jsonObj.getProp("GorushURL", result.GorushURL)

  # var arr: JsonNode
  # if(jsonObj.getProp("Identity", arr)):
  #   if(arr.kind == JArray):
  #     for valueObj in arr:
  #       result.Identity.add(valueObj.getStr)

  # if(jsonObj.getProp("Logger", arr)):
  #   if(arr.kind == JArray):
  #     for valueObj in arr:
  #       result.Logger.add(valueObj.getStr)

proc toNodeConfigDto*(jsonObj: JsonNode): NodeConfigDto =
  discard jsonObj.getProp("NetworkId", result.NetworkId)
  discard jsonObj.getProp("DataDir", result.DataDir)
  discard jsonObj.getProp("KeyStoreDir", result.KeyStoreDir)
  discard jsonObj.getProp("NodeKey", result.NodeKey)
  discard jsonObj.getProp("NoDiscovery", result.NoDiscovery)
  discard jsonObj.getProp("Rendezvous", result.Rendezvous)
  discard jsonObj.getProp("ListenAddr", result.ListenAddr)
  discard jsonObj.getProp("AdvertiseAddr", result.AdvertiseAddr)
  discard jsonObj.getProp("Name", result.Name)
  discard jsonObj.getProp("Version", result.Version)
  discard jsonObj.getProp("APIModules", result.APIModules)
  discard jsonObj.getProp("HTTPEnabled", result.HTTPEnabled)
  discard jsonObj.getProp("HTTPHost", result.HTTPHost)
  discard jsonObj.getProp("HTTPPort", result.HTTPPort)
  # discard jsonObj.getProp("HTTPVirtualHosts", result.HTTPVirtualHosts)
  # discard jsonObj.getProp("HTTPCors", result.HTTPCors)
  discard jsonObj.getProp("IPCEnabled", result.IPCEnabled)
  discard jsonObj.getProp("IPCFile", result.IPCFile)
  discard jsonObj.getProp("TLSEnabled", result.TLSEnabled)
  discard jsonObj.getProp("MaxPeers", result.MaxPeers)
  discard jsonObj.getProp("MaxPendingPeers", result.MaxPendingPeers)
  discard jsonObj.getProp("LogEnabled", result.LogEnabled)
  discard jsonObj.getProp("LogMobileSystem", result.LogMobileSystem)
  discard jsonObj.getProp("LogDir", result.LogDir)
  discard jsonObj.getProp("LogFile", result.LogFile)
  discard jsonObj.getProp("LogLevel", result.LogLevel)
  discard jsonObj.getProp("LogMaxBackups", result.LogMaxBackups)
  discard jsonObj.getProp("LogMaxSize", result.LogMaxSize)
  discard jsonObj.getProp("LogCompressRotated", result.LogCompressRotated)
  discard jsonObj.getProp("LogToStderr", result.LogToStderr)
  discard jsonObj.getProp("EnableStatusService", result.EnableStatusService)
  discard jsonObj.getProp("EnableNTPSync", result.EnableNTPSync)
  discard jsonObj.getProp("MailServerRegistryAddress", result.MailServerRegistryAddress)

  var nimbusProxyConfigObj: JsonNode
  if(jsonObj.getProp("NimbusProxyConfig", nimbusProxyConfigObj)):
    result.NimbusProxyConfig = toNimbusProxyConfig(nimbusProxyConfigObj)

  var upstreamConfigObj: JsonNode
  if(jsonObj.getProp("UpstreamConfig", upstreamConfigObj)):
    result.UpstreamConfig = toUpstreamConfig(upstreamConfigObj)

  var networksArr: JsonNode
  if(jsonObj.getProp("Networks", networksArr)):
    if(networksArr.kind == JArray):
      for networkObj in networksArr:
        result.Networks.add(toNetwork(networkObj))

  var clusterConfigObj: JsonNode
  if(jsonObj.getProp("ClusterConfig", clusterConfigObj)):
    result.ClusterConfig = toClusterConfig(clusterConfigObj)

  var lightEthConfigObj: JsonNode
  if(jsonObj.getProp("LightEthConfig", lightEthConfigObj)):
    result.LightEthConfig = toLightEthConfig(lightEthConfigObj)

  var wakuConfigObj: JsonNode
  if(jsonObj.getProp("WakuConfig", wakuConfigObj)):
    result.WakuConfig = toWakuConfig(wakuConfigObj)

  var torrentConfigObj: JsonNode
  if(jsonObj.getProp("TorrentConfig", torrentConfigObj)):
    result.TorrentConfig = toTorrentConfig(torrentConfigObj)

  var logosStorageConfigObj: JsonNode
  if(jsonObj.getProp("LogosStorageConfig", logosStorageConfigObj)):
    result.LogosStorageConfig = toLogosStorageConfig(logosStorageConfigObj)

  var wakuV2ConfigObj: JsonNode
  if(jsonObj.getProp("WakuV2Config", wakuV2ConfigObj)):
    result.WakuV2Config = toWaku2Config(wakuV2ConfigObj)

  var shhextConfigObj: JsonNode
  if(jsonObj.getProp("ShhextConfig", shhextConfigObj)):
    result.ShhextConfig = toShhextConfig(shhextConfigObj)

  var bridgeConfigObj: JsonNode
  if(jsonObj.getProp("BridgeConfig", bridgeConfigObj)):
    result.BridgeConfig = toBridgeConfig(bridgeConfigObj)

  var walletConfigObj: JsonNode
  if(jsonObj.getProp("WalletConfig", walletConfigObj)):
    result.WalletConfig = toWalletConfig(walletConfigObj)

  var localNotificationsConfigObj: JsonNode
  if(jsonObj.getProp("LocalNotificationsConfig", localNotificationsConfigObj)):
    result.LocalNotificationsConfig = toLocalNotificationsConfig(localNotificationsConfigObj)

  var browsersConfigObj: JsonNode
  if(jsonObj.getProp("BrowsersConfig", browsersConfigObj)):
    result.BrowsersConfig = toBrowsersConfig(browsersConfigObj)

  var permissionsConfigObj: JsonNode
  if(jsonObj.getProp("PermissionsConfig", permissionsConfigObj)):
    result.PermissionsConfig = toPermissionsConfig(permissionsConfigObj)

  var mailserversConfigObj: JsonNode
  if(jsonObj.getProp("MailserversConfig", mailserversConfigObj)):
    result.MailserversConfig = toMailserversConfig(mailserversConfigObj)

  var web3ProviderConfig: JsonNode
  if(jsonObj.getProp("Web3ProviderConfig", web3ProviderConfig)):
    result.Web3ProviderConfig = toWeb3ProviderConfig(web3ProviderConfig)

  var ensConfig: JsonNode
  if(jsonObj.getProp("EnsConfig", ensConfig)):
    result.EnsConfig = toEnsConfig(ensConfig)

  var swarmConfigObj: JsonNode
  if(jsonObj.getProp("SwarmConfig", swarmConfigObj)):
    result.SwarmConfig = toSwarmConfig(swarmConfigObj)

  var arr: JsonNode
  if(jsonObj.getProp("RegisterTopics", arr)):
    if(arr.kind == JArray):
      for valueObj in arr:
        result.RegisterTopics.add(valueObj.getStr)

  var requireTopicsObj: JsonNode
  if(jsonObj.getProp("RequireTopics", requireTopicsObj)):
    result.RequireTopics = toRequireTopics(requireTopicsObj)

  var pushNotificationServerConfigObj: JsonNode
  if(jsonObj.getProp("PushNotificationServerConfig", pushNotificationServerConfigObj)):
    result.PushNotificationServerConfig = toPushNotificationServerConfig(pushNotificationServerConfigObj)

proc toJsonNode*(nodeConfigDto: NodeConfigDto): JsonNode =
  let nodeConfigDtoAsString = $$nodeConfigDto
  result = parseJson(nodeConfigDtoAsString)
