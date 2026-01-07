{.used.}

import json, std/strformat

include ../../../common/json_utils
include ../../../common/utils

include backend/collectibles_types

type TokenDataDto* = object
  chainId*: int
  collectibleId*: CollectibleUniqueID
  txHash*: string
  walletAddress*: string
  isFirst*: bool
  communiyId*: string
  amount*: string
  name*: string
  symbol*: string
  imageUrl*: string
  tokenType*: int

proc `$`*(self: TokenDataDto): string =
  result = fmt"""TokenDataDto(
    chainId: {$self.chainId},
    collectibleId: {self.collectibleId},
    txHash: {self.txHash},
    walletAddress: {self.walletAddress},
    isFirst: {$self.isFirst},
    communiyId: {self.communiyId},
    amount: {self.amount},
    name: {self.name},
    symbol: {self.symbol},
    imageUrl: {self.imageUrl},
    tokenType: {$self.tokenType}
    )"""

proc toTokenDataDto*(jsonObj: JsonNode): TokenDataDto =
  result = TokenDataDto()
  discard jsonObj.getProp("chainId", result.chainId)
  discard jsonObj.getProp("txHash", result.txHash)
  discard jsonObj.getProp("walletAddress", result.walletAddress)
  discard jsonObj.getProp("isFirst", result.isFirst)
  discard jsonObj.getProp("communiyId", result.communiyId)
  discard jsonObj.getProp("amount", result.amount)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("symbol", result.symbol)
  discard jsonObj.getProp("imageUrl", result.imageUrl)
  discard jsonObj.getProp("tokenType", result.tokenType)

  if jsonObj.contains("collectibleId") and jsonObj{"collectibleId"}.kind != JNull:
      result.collectibleId = fromJson(jsonObj["collectibleId"], CollectibleUniqueID)