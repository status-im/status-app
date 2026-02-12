import json, std/options
import wallet_secretes_config
import wallet_config
import api_config

export wallet_secretes_config
export wallet_config
export api_config

type
  LoginAccountRequest* = object
    passwordHash*: string
    keyUID*: string
    kdfIterations*: int
    runtimeLogLevel*: string
    wakuV2Nameserver*: string
    bandwidthStatsEnabled*: bool
    keycardWhisperPrivateKey*: string
    mnemonic*: string
    walletSecretsConfig*: WalletSecretsConfig
    walletConfig*: WalletConfig
    apiConfig*: APIConfig
    walletConnectProjectID*: string

proc toJson*(self: LoginAccountRequest): JsonNode =
  result = %* {
    "password": self.passwordHash,
    "keyUid": self.keyUID,
    "kdfIterations": self.kdfIterations,
    "runtimeLogLevel": self.runtimeLogLevel,
    "wakuV2Nameserver": self.wakuV2Nameserver,
    "bandwidthStatsEnabled": self.bandwidthStatsEnabled,
    "keycardWhisperPrivateKey": self.keycardWhisperPrivateKey,
    "mnemonic": self.mnemonic,
    "apiConfig": self.apiConfig,
    "walletConnectProjectID": self.walletConnectProjectID,
  }
  for key, value in self.walletSecretsConfig.toJson().pairs():
    result[key] = value
  for key, value in self.walletConfig.toJson().pairs():
    result[key] = value
