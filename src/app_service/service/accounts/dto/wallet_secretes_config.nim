import json

type
  WalletSecretsConfig* = object
    poktToken*: string
    infuraToken*: string
    infuraSecret*: string
    openseaApiKey*: string
    raribleMainnetApiKey*: string
    raribleTestnetApiKey*: string
    alchemyApiKey*: string
    statusProxyStageName*: string
    marketDataProxyUrl*: string
    marketDataProxyUser*: string
    marketDataProxyPassword*: string
    statusProxyBlockchainUser*: string
    statusProxyBlockchainPassword*: string
    ethRpcProxyUser*: string
    ethRpcProxyPassword*: string
    ethRpcProxyUrl*: string
    ethRpcProxyUsePuzzleAuth*: bool
    nftProxyUrl*: string
    nftProxyStageName*: string
    nftProxyUser*: string
    nftProxyPassword*: string
    nftProxyUsePuzzleAuth*: bool

proc toJson*(self: WalletSecretsConfig): JsonNode =
  return %* {
    "poktToken": self.poktToken,
    "infuraToken": self.infuraToken,
    "infuraSecret": self.infuraSecret,
    "openseaApiKey": self.openseaApiKey,
    "raribleMainnetApiKey": self.raribleMainnetApiKey,
    "raribleTestnetApiKey": self.raribleTestnetApiKey,
    "alchemyApiKey": self.alchemyApiKey,
    "statusProxyStageName": self.statusProxyStageName,
    "marketDataProxyUrl": self.marketDataProxyUrl,
    "marketDataProxyUser": self.marketDataProxyUser,
    "marketDataProxyPassword": self.marketDataProxyPassword,
    "statusProxyBlockchainUser": self.statusProxyBlockchainUser,
    "statusProxyBlockchainPassword": self.statusProxyBlockchainPassword,
    "ethRpcProxyUser": self.ethRpcProxyUser,
    "ethRpcProxyPassword": self.ethRpcProxyPassword,
    "ethRpcProxyUrl": self.ethRpcProxyUrl,
    "ethRpcProxyUsePuzzleAuth": self.ethRpcProxyUsePuzzleAuth,
    "nftProxyUrl": self.nftProxyUrl,
    "nftProxyStageName": self.nftProxyStageName,
    "nftProxyUser": self.nftProxyUser,
    "nftProxyPassword": self.nftProxyPassword,
    "nftProxyUsePuzzleAuth": self.nftProxyUsePuzzleAuth,
  }
