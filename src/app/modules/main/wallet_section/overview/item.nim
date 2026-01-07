import std/strformat, strutils

type
  Item* = object
    name: string
    mixedCaseAddress: string
    ens: string
    balanceLoading: bool
    colorId: string
    emoji: string
    isWatchOnlyAccount: bool
    isAllAccounts: bool
    colorIds: seq[string]
    canSend: bool

proc initItem*(
  name: string = "",
  mixedCaseAddress: string = "",
  ens: string = "",
  balanceLoading: bool  = true,
  colorId: string,
  emoji: string,
  isWatchOnlyAccount: bool=false,
  isAllAccounts: bool = false,
  colorIds: seq[string] = @[],
  canSend: bool = true,
): Item =
  result.name = name
  result.mixedCaseAddress = mixedCaseAddress
  result.ens = ens
  result.balanceLoading = balanceLoading
  result.colorId = colorId
  result.emoji = emoji
  result.isAllAccounts = isAllAccounts
  result.colorIds = colorIds
  result.isWatchOnlyAccount = isWatchOnlyAccount
  result.canSend = canSend

proc `$`*(self: Item): string =
  result = fmt"""OverviewItem(
    name: {self.name},
    mixedCaseAddress: {self.mixedCaseAddress},
    ens: {self.ens},
    balanceLoading: {self.balanceLoading},
    colorId: {self.colorId},
    emoji: {self.emoji},
    isWatchOnlyAccount: {self.isWatchOnlyAccount},
    isAllAccounts: {self.isAllAccounts},
    colorIds: {self.colorIds}
    ]"""

proc getName*(self: Item): string =
  return self.name

proc getMixedCaseAddress*(self: Item): string =
  return self.mixedCaseAddress

proc getEns*(self: Item): string =
  return self.ens

proc getBalanceLoading*(self: Item): bool =
  return self.balanceLoading

proc getColorId*(self: Item): string =
  return self.colorId

proc getEmoji*(self: Item): string =
  return self.emoji

proc getIsAllAccounts*(self: Item): bool =
  return self.isAllAccounts

proc getColorIds*(self: Item): string =
  return self.colorIds.join(";")

proc getIsWatchOnlyAccount*(self: Item): bool =
  return self.isWatchOnlyAccount

proc getCanSend*(self: Item): bool =
  return self.canSend
