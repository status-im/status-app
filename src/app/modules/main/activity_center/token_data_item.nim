import nimqml, std/[strutils, strformat]

QtObject:
  type TokenDataItem* = ref object of QObject
    chainId*: int
    txHash*: string
    walletAddress*: string
    isFirst*: bool
    communiyId*: string
    amount*: string
    name*: string
    symbol*: string
    imageUrl*: string
    tokenType*: int

  proc setup(self: TokenDataItem)
  proc delete*(self: TokenDataItem)
  proc newTokenDataItem*(
    chainId: int,
    txHash: string,
    walletAddress: string,
    isFirst: bool,
    communiyId: string,
    amount: string,
    name: string,
    symbol: string,
    imageUrl: string,
    tokenType: int): TokenDataItem =
      new(result, delete)
      result.setup
      result.chainId = chainId
      result.txHash = txHash
      result.walletAddress = walletAddress
      result.isFirst = isFirst
      result.communiyId = communiyId
      result.amount = amount
      result.name = name
      result.symbol = symbol
      result.imageUrl = imageUrl
      result.tokenType = tokenType

  proc `$`*(self: TokenDataItem): string =
    result = fmt"""
      chainId: {self.chainId},
      txHash: {self.txHash},
      walletAddress: {self.walletAddress},
      isFirst: {self.isFirst},
      communiyId: {self.communiyId},
      amount: {self.amount},
      name: {self.name},
      symbol: {self.symbol},
      imageUrl: {self.imageUrl},
      tokenType: {self.tokenType}
    """

  proc chainId*(self: TokenDataItem): int {.slot.} = result = self.chainId
  QtProperty[int] chainId:
    read = chainId

  proc txHash*(self: TokenDataItem): string {.slot.} = result = self.txHash
  QtProperty[string] txHash:
    read = txHash

  proc walletAddress*(self: TokenDataItem): string {.slot.} = result = self.walletAddress
  QtProperty[string] walletAddress:
    read = walletAddress

  proc isFirst*(self: TokenDataItem): bool {.slot.} = result = self.isFirst
  QtProperty[bool] isFirst:
    read = isFirst

  proc communiyId*(self: TokenDataItem): string {.slot.} = result = self.communiyId
  QtProperty[string] communiyId:
    read = communiyId

  proc amount*(self: TokenDataItem): string {.slot.} = result = self.amount
  QtProperty[string] amount:
    read = amount

  proc name*(self: TokenDataItem): string {.slot.} = result = self.name
  QtProperty[string] name:
    read = name

  proc symbol*(self: TokenDataItem): string {.slot.} = result = self.symbol
  QtProperty[string] symbol:
    read = symbol

  proc imageUrl*(self: TokenDataItem): string {.slot.} = result = self.imageUrl
  QtProperty[string] imageUrl:
    read = imageUrl

  proc tokenType*(self: TokenDataItem): int {.slot.} = result = self.tokenType
  QtProperty[int] tokenType:
    read = tokenType

  proc setup(self: TokenDataItem) =
    self.QObject.setup

  proc delete*(self: TokenDataItem) =
    self.QObject.delete

