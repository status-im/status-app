include env_cli_vars

## Added a constant here cause it's easier to check the app how it behaves
## on other platform if we just change the value here
const IS_MACOS* = defined(macosx)
const IS_INTEL* = defined(amd64)
const IS_MOBILE* = defined(ios) or defined(android)
# For future supporting fingerprints on other platforms
const SUPPORTS_FINGERPRINT* = IS_MACOS or IS_MOBILE
# This is changed during compilation by reading the VERSION file
const DESKTOP_VERSION {.strdefine.} = "0.0.0"
const STATUSGO_VERSION* {.strdefine.} = "0.0.0"
# This is changed during compilation by executing git command
const GIT_COMMIT* {.strdefine.} = ""

const APP_VERSION* = DESKTOP_VERSION

const DATE_TIME_FORMAT_1* = "yyyy-MM-dd'T'HH:mm:ss'.'fffzzz"
const DATE_TIME_FORMAT_2* = "yyyy-MM-dd'T'HH:mm:ss'.'ffffffzzz"

const sep* = when defined(windows): "\\" else: "/"

################################################################################
# The following variables are set:
#
# - via CL arguments, if they are provided
# - otherwise via env variables, if they are provided
# - otherwise the default values are used
################################################################################
let
  baseDir = absolutePath(expandTilde(desktopConfig.dataDir))
  OPENURI* = desktopConfig.uri
  DATADIR* = baseDir & sep
  STATUSGODIR* = joinPath(baseDir, "data") & sep
  ROOTKEYSTOREDIR* = joinPath(STATUSGODIR, "keystore")
  DEFAULT_BACKUP_DIR* = joinPath(STATUSGODIR, "backups") & sep
  TMPDIR* = joinPath(baseDir, "tmp") & sep
  LOGDIR* = joinPath(baseDir, "logs") & sep
  KEYCARD_DATA_DIR* = joinPath(baseDir, "data", "keycard")
  KEYCARD_LOG_FILE_PATH* = joinPath(KEYCARD_DATA_DIR, "keycard.log")
  KEYCARDPAIRINGDATAFILE* = joinPath(KEYCARD_DATA_DIR, "pairings.json")

  # runtime variables
  TEST_MODE_ENABLED* = desktopConfig.testMode
  DISPLAY_MOCKED_KEYCARD_WINDOW* = desktopConfig.displayMockedKeycardWindow
  WALLET_ENABLED* = desktopConfig.enableWallet
  TORRENT_CONFIG_PORT* = desktopConfig.defaultTorentConfigPort
  LOG_LEVEL* = desktopConfig.logLevel
  FLEET_SELECTION_ENABLED* = desktopConfig.enableFleetSelection

  # build variables
  POKT_TOKEN_RESOLVED* = desktopConfig.poktToken
  INFURA_TOKEN_RESOLVED* = desktopConfig.infuraToken
  INFURA_TOKEN_SECRET_RESOLVED* = desktopConfig.infuraTokenSecret
  ALCHEMY_API_KEY_RESOLVED* = desktopConfig.alchemyApiKey
  OPENSEA_API_KEY_RESOLVED* = desktopConfig.openseaApiKey
  RARIBLE_MAINNET_API_KEY_RESOLVED* = desktopConfig.raribleMainnetApiKey
  RARIBLE_TESTNET_API_KEY_RESOLVED* = desktopConfig.raribleTestnetApiKey
  TENOR_API_KEY_RESOLVED* = desktopConfig.tenorApiKey
  STATUS_PROXY_STAGE_NAME_RESOLVED* = desktopConfig.statusProxyStageName
  STATUS_PROXY_USER_RESOLVED* = desktopConfig.statusProxyUser
  STATUS_PROXY_PASSWORD_RESOLVED* = desktopConfig.statusProxyPassword
  MARKET_DATA_PROXY_URL_RESOLVED* = desktopConfig.marketDataProxyUrl
  MARKET_DATA_PROXY_USER_RESOLVED* = desktopConfig.marketDataProxyUser
  MARKET_DATA_PROXY_PASSWORD_RESOLVED* = desktopConfig.marketDataProxyPassword
  MARKET_DATA_FULL_REFRESH_INTERVAL* = desktopConfig.marketDataFullRefreshInterval
  MARKET_DATA_PRICE_REFRESH_INTERVAL* = desktopConfig.marketDataPricesRefreshInterval
  ETH_RPC_PROXY_USER_RESOLVED* = desktopConfig.ethRpcProxyUser
  ETH_RPC_PROXY_PASSWORD_RESOLVED* = desktopConfig.ethRpcProxyPassword
  ETH_RPC_PROXY_URL_RESOLVED* = desktopConfig.ethRpcProxyUrl
  NFT_PROXY_URL_RESOLVED* = desktopConfig.nftProxyUrl
  NFT_PROXY_STAGE_NAME_RESOLVED* = desktopConfig.nftProxyStageName
  NFT_PROXY_USER_RESOLVED* = desktopConfig.nftProxyUser
  NFT_PROXY_PASSWORD_RESOLVED* = desktopConfig.nftProxyPassword
  NFT_PROXY_USE_PUZZLE_AUTH_RESOLVED* = desktopConfig.nftProxyUsePuzzleAuth

  WALLET_CONNECT_PROJECT_ID* = BUILD_WALLET_CONNECT_PROJECT_ID
  MIXPANEL_APP_ID* = desktopConfig.mixpanelAppId
  MIXPANEL_TOKEN* = desktopConfig.mixpanelToken
  BUILD_MODE* = if defined(production): "prod" else: "test"
  HTTP_API_ENABLED* = desktopConfig.httpApiEnabled
  WS_API_ENABLED* = desktopConfig.wsApiEnabled
  SENTRY_DSN_STATUS_GO* = BUILD_SENTRY_DSN_STATUS_GO
  SENTRY_DSN_STATUS_GO_DESKTOP* = BUILD_SENTRY_DSN_STATUS_DESKTOP
  API_LOGGING* = desktopConfig.apiLogging
  KEYCARD_LOGS_ENABLED* = if defined(production): false else: true
  METRICS_ENABLED* = desktopConfig.metricsEnabled
  METRICS_ADDRESS* = desktopConfig.metricsAddress
  WAKU_FLEET* = desktopConfig.wakuFleet
  WAKU_FLEETS_CONFIG* = desktopConfig.wakuFleetsConfig

proc hasLogLevelOption*(): bool =
  for p in cliParams:
    if p.startswith("--log-level") or p.startsWith("--LOG_LEVEL"):
      return true
  return false

proc runtimeLogLevelSet*(): bool =
  return existsEnv(RUN_TIME_PREFIX & "_LOG_LEVEL") or hasLogLevelOption()

proc getStatusGoLogLevel*(): string =
  if LOG_LEVEL == "TRACE":
    return "DEBUG"
  return LOG_LEVEL

const MAIN_STATUS_SHARD_CLUSTER_ID* = 16
