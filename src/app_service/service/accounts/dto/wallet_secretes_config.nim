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
    statusProxyMarketUser*: string
    statusProxyMarketPassword*: string
    marketDataProxyUrl*: string
    marketDataProxyUser*: string
    marketDataProxyPassword*: string
    statusProxyBlockchainUser*: string
    statusProxyBlockchainPassword*: string
    ethRpcProxyUser*: string
    ethRpcProxyPassword*: string
    ethRpcProxyUrl*: string
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
    "statusProxyMarketUser": self.statusProxyMarketUser,
    "statusProxyMarketPassword": self.statusProxyMarketPassword,
    "marketDataProxyUrl": self.marketDataProxyUrl,
    "marketDataProxyUser": self.marketDataProxyUser,
    "marketDataProxyPassword": self.marketDataProxyPassword,
    "statusProxyBlockchainUser": self.statusProxyBlockchainUser,
    "statusProxyBlockchainPassword": self.statusProxyBlockchainPassword,
    "ethRpcProxyUser": self.ethRpcProxyUser,
    "ethRpcProxyPassword": self.ethRpcProxyPassword,
    "ethRpcProxyUrl": self.ethRpcProxyUrl,
    "nftProxyUrl": self.nftProxyUrl,
    "nftProxyStageName": self.nftProxyStageName,
    "nftProxyUser": self.nftProxyUser,
    "nftProxyPassword": self.nftProxyPassword,
    "nftProxyUsePuzzleAuth": self.nftProxyUsePuzzleAuth,
  }
