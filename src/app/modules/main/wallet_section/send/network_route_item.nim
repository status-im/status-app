import std/strformat, strutils

import app/modules/shared_models/currency_amount

type
  NetworkRouteItem* = ref object
    chainId: int
    layer: int
    isRouteEnabled: bool
    isRoutePreferred: bool
    hasGas: bool
    tokenBalance: CurrencyAmount
    amountIn: string
    amountOut: string
    toNetworks: seq[int]

proc initNetworkRouteItem*(
    chainId: int,
    layer: int,
    isRouteEnabled: bool,
    isRoutePreferred: bool,
    hasGas: bool,
    tokenBalance: CurrencyAmount,
    amountIn: string = "",
    amountOut: string = "",
    toNetworks: seq[int] = @[]
): NetworkRouteItem =
  result = NetworkRouteItem()
  result.chainId = chainId
  result.layer = layer
  result.isRouteEnabled = isRouteEnabled
  result.isRoutePreferred = isRoutePreferred
  result.hasGas = hasGas
  result.tokenBalance = tokenBalance
  result.amountIn = amountIn
  result.amountOut = amountOut
  result.toNetworks = toNetworks

proc `$`*(self: NetworkRouteItem): string =
  result = fmt"""NetworkRouteItem(
    chainId: {self.chainId},
    layer: {self.layer},
    isRouteEnabled:{self.isRouteEnabled},
    isRoutePreferred:{self.isRoutePreferred},
    hasGas:{self.hasGas},
    tokenBalance:{self.tokenBalance},
    amountIn:{self.amountIn},
    amountOut:{self.amountOut},
    toNetworks:{self.toNetworks},
    ]"""

proc getChainId*(self: NetworkRouteItem): int =
  return self.chainId

proc getLayer*(self: NetworkRouteItem): int =
  return self.layer

proc getIsRouteEnabled*(self: NetworkRouteItem): bool =
  return self.isRouteEnabled
proc `isRouteEnabled=`*(self: NetworkRouteItem, value: bool) {.inline.} =
  self.isRouteEnabled = value

proc getIsRoutePreferred*(self: NetworkRouteItem): bool =
  return self.isRoutePreferred
proc `isRoutePreferred=`*(self: NetworkRouteItem, value: bool) {.inline.} =
  self.isRoutePreferred = value

proc getHasGas*(self: NetworkRouteItem): bool =
  return self.hasGas
proc `hasGas=`*(self: NetworkRouteItem, value: bool) {.inline.} =
  self.hasGas = value

proc getTokenBalance*(self: NetworkRouteItem): CurrencyAmount =
  return self.tokenBalance
proc `tokenBalance=`*(self: NetworkRouteItem, value: CurrencyAmount) {.inline.} =
  self.tokenBalance = value

proc getAmountIn*(self: NetworkRouteItem): string =
  return self.amountIn
proc `amountIn=`*(self: NetworkRouteItem, value: string) {.inline.} =
  self.amountIn = value

proc getAmountOut*(self: NetworkRouteItem): string =
  return self.amountOut
proc `amountOut=`*(self: NetworkRouteItem, value: string) {.inline.} =
  self.amountOut = value

proc getToNetworks*(self: NetworkRouteItem): string =
  return self.toNetworks.join(":")
proc `toNetworks=`*(self: NetworkRouteItem, value: int) {.inline.} =
  self.toNetworks.add(value)
proc resetToNetworks*(self: NetworkRouteItem) =
   self.toNetworks = @[]

