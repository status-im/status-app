import json, std/options
import wallet_secretes_config
import wallet_config
import image_crop_rectangle
import api_config
import network

export wallet_secretes_config
export wallet_config
export image_crop_rectangle
export api_config
export network

type
  CreateAccountRequest* = object
    rootDataDir*: string
    kdfIterations*: int
    deviceName*: string
    displayName*: string
    password*: string
    imagePath*: string
    imageCropRectangle*: ImageCropRectangle
    customizationColor*: string
    emoji*: string

    wakuV2Fleet*: string
    wakuV2Nameserver*: Option[string]
    wakuV2LightClient*: bool
    wakuV2EnableStoreConfirmationForMessagesSent*: bool
    wakuV2EnableMissingMessageVerification*: bool

    logLevel*: Option[string]
    logFilePath*: string
    logEnabled*: bool

    previewPrivacy*: bool
    autoRefreshTokensEnabled*: bool

    verifyTransactionURL*: Option[string]
    verifyENSURL*: Option[string]
    verifyENSContractAddress*: Option[string]
    verifyTransactionChainID*: Option[int64]
    upstreamConfig*: string
    networkID*: Option[uint64]
    testOverrideNetworks*: seq[Network]

    walletSecretsConfig*: WalletSecretsConfig
    walletConfig*: WalletConfig

    torrentConfigEnabled*: Option[bool]
    torrentConfigPort*: Option[int]

    keycardInstanceUID*: string
    keycardPairingDataFile*: string

    thirdpartyServicesEnabled*: bool

    apiConfig*: APIConfig

proc toJson*(self: CreateAccountRequest): JsonNode =
  result = %*{
    "rootDataDir": self.rootDataDir,
    "kdfIterations": self.kdfIterations,
    "deviceName": self.deviceName,
    "displayName": self.displayName,
    "password": self.password,
    "imagePath": self.imagePath,
    "imageCropRectangle": self.imageCropRectangle,
    "customizationColor": self.customizationColor,
    "emoji": self.emoji,
    "wakuV2Fleet": self.wakuV2Fleet,
    "wakuV2LightClient": self.wakuV2LightClient,
    "logFilePath": self.logFilePath,
    "logEnabled": self.logEnabled,
    "previewPrivacy": self.previewPrivacy,
    "autoRefreshTokensEnabled": self.autoRefreshTokensEnabled,
    "upstreamConfig": self.upstreamConfig,
    "keycardInstanceUID": self.keycardInstanceUID,
    "keycardPairingDataFile": self.keycardPairingDataFile,
    "apiConfig": self.apiConfig,
    "wakuV2EnableStoreConfirmationForMessagesSent": self.wakuV2EnableStoreConfirmationForMessagesSent,
    "wakuV2EnableMissingMessageVerification": self.wakuV2EnableMissingMessageVerification,
    "thirdpartyServicesEnabled": self.thirdpartyServicesEnabled,
  }

  if self.logLevel.isSome():
    result["logLevel"] = %self.logLevel.get("")

  if self.wakuV2Nameserver.isSome():
    result["wakuV2Nameserver"] = %self.wakuV2Nameserver.get()

  if self.verifyTransactionURL.isSome():
    result["verifyTransactionURL"] = %self.verifyTransactionURL.get()

  if self.verifyENSURL.isSome():
    result["verifyENSURL"] = %self.verifyENSURL.get()
    
  if self.verifyENSContractAddress.isSome():
    result["verifyENSContractAddress"] = %self.verifyENSContractAddress.get()

  if self.verifyTransactionChainID.isSome():
    result["verifyTransactionChainID"] = %self.verifyTransactionChainID.get()

  if self.networkID.isSome():
    result["networkID"] = %self.networkID.get()

  if self.torrentConfigEnabled.isSome():
    result["torrentConfigEnabled"] = %self.torrentConfigEnabled.get()

  if self.torrentConfigPort.isSome():
    result["torrentConfigPort"] = %self.torrentConfigPort.get()

  for key, value in self.walletSecretsConfig.toJson().pairs():
    result[key] = value

  for key, value in self.walletConfig.toJson().pairs():
    result[key] = value
