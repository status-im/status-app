import nimqml, std/strformat
import app_service/service/wallet_account/dto/account_dto as wa_dto

export wa_dto

QtObject:
  type WalletAccountItem* = ref object of QObject
    name: string
    address: string
    mixedcaseAddress: string
    colorId: string
    emoji: string
    walletType: string
    path: string
    keyUid: string
    keycardAccount: bool
    position: int
    operability: string
    areTestNetworksEnabled: bool
    hideFromTotalBalance: bool

  proc setup*(self: WalletAccountItem,
    name: string = "",
    address: string = "",
    mixedcaseAddress: string = "",
    colorId: string = "",
    emoji: string = "",
    walletType: string = "",
    path: string = "",
    keyUid: string = "",
    keycardAccount: bool = false,
    position: int = 0,
    operability: string = wa_dto.AccountFullyOperable,
    areTestNetworksEnabled: bool = false,
    hideFromTotalBalance: bool = true
    )
  proc delete*(self: WalletAccountItem)
  proc newWalletAccountItem*(
    name: string = "",
    address: string = "",
    mixedcaseAddress: string = "",
    colorId: string = "",
    emoji: string = "",
    walletType: string = "",
    path: string = "",
    keyUid: string = "",
    keycardAccount: bool = false,
    position: int = 0,
    operability: string = wa_dto.AccountFullyOperable,
    areTestNetworksEnabled: bool = false,
    hideFromTotalBalance: bool = true): WalletAccountItem =
    new(result, delete)
    result.QObject.setup
    result.name = name
    result.address = address
    result.colorId = colorId
    result.emoji = emoji
    result.walletType = walletType
    result.path = path
    result.keyUid = keyUid
    result.keycardAccount = keycardAccount
    result.position = position
    result.operability = operability
    result.areTestNetworksEnabled = areTestNetworksEnabled
    result.hideFromTotalBalance = hideFromTotalBalance

  proc `$`*(self: WalletAccountItem): string =
    result = fmt"""WalletAccountItem(
      name: {self.name},
      address: {self.address},
      mixedcaseAddress: {self.mixedcaseAddress},
      colorId: {self.colorId},
      emoji: {self.emoji},
      walletType: {self.walletType},
      path: {self.path},
      keyUid: {self.keyUid},
      keycardAccount: {self.keycardAccount},
      position: {self.position},
      operability: {self.operability},
      areTestNetworksEnabled: {self.areTestNetworksEnabled},
      hideFromTotalBalance: {self.hideFromTotalBalance}
      ]"""

  proc nameChanged*(self: WalletAccountItem) {.signal.}
  proc name*(self: WalletAccountItem): string {.slot.} =
    return self.name
  proc `name=`*(self: WalletAccountItem, value: string) {.inline.} =
    self.name = value
    self.nameChanged()
  QtProperty[string] name:
    read = name
    notify = nameChanged

  proc addressChanged*(self: WalletAccountItem) {.signal.}
  proc address*(self: WalletAccountItem): string {.slot.} =
    return self.address
#  proc setAddress*(self: WalletAccountItem, value: string) {.slot.} =
#    self.address = value
#    self.addressChanged()
  QtProperty[string] address:
    read = address
    notify = addressChanged

  proc mixedcaseAddressChanged*(self: WalletAccountItem) {.signal.}
  proc mixedcaseAddress*(self: WalletAccountItem): string {.slot.} =
    return self.mixedcaseAddress

  QtProperty[string] mixedcaseAddress:
    read = mixedcaseAddress
    notify = mixedcaseAddressChanged

  proc colorIdChanged*(self: WalletAccountItem) {.signal.}
  proc colorId*(self: WalletAccountItem): string {.slot.} =
    return self.colorId
  proc `colorId=`*(self: WalletAccountItem, value: string) {.inline.} =
    self.colorId = value
    self.colorIdChanged()
  QtProperty[string] colorId:
    read = colorId
    notify = colorIdChanged

  proc emojiChanged*(self: WalletAccountItem) {.signal.}
  proc emoji*(self: WalletAccountItem): string {.slot.} =
    return self.emoji
  proc `emoji=`*(self: WalletAccountItem, value: string) {.inline.} =
    self.emoji = value
    self.emojiChanged()
  QtProperty[string] emoji:
    read = emoji
    notify = emojiChanged

  proc walletTypeChanged*(self: WalletAccountItem) {.signal.}
  proc walletType*(self: WalletAccountItem): string {.slot.} =
    return self.walletType
  QtProperty[string] walletType:
    read = walletType
    notify = walletTypeChanged

  proc pathChanged*(self: WalletAccountItem) {.signal.}
  proc path*(self: WalletAccountItem): string {.slot.} =
    return self.path
  QtProperty[string] path:
    read = path
    notify = pathChanged

  proc keyUidChanged*(self: WalletAccountItem) {.signal.}
  proc keyUid*(self: WalletAccountItem): string {.slot.} =
    return self.keyUid
  QtProperty[string] keyUid:
    read = keyUid
    notify = keyUidChanged

  proc keycardAccountChanged*(self: WalletAccountItem) {.signal.}
  proc keycardAccount*(self: WalletAccountItem): bool {.slot.} =
    return self.keycardAccount
  QtProperty[bool] keycardAccount:
    read = keycardAccount
    notify = keycardAccountChanged

  proc positionChanged*(self: WalletAccountItem) {.signal.}
  proc getPosition*(self: WalletAccountItem): int {.slot.} =
    return self.position
  proc setPosition*(self: WalletAccountItem, value: int) {.slot.} =
    self.position = value
    self.positionChanged()
  QtProperty[int] position:
    read = getPosition
    write = setPosition
    notify = positionChanged

  proc operabilityChanged*(self: WalletAccountItem) {.signal.}
  proc getOperability*(self: WalletAccountItem): string {.slot.} =
    return self.operability
  proc setOperability*(self: WalletAccountItem, value: string) {.slot.} =
    self.operability = value
    self.operabilityChanged()
  QtProperty[string] operability:
    read = getOperability
    write = setOperability
    notify = operabilityChanged

  proc hideFromTotalBalanceChanged*(self: WalletAccountItem) {.signal.}
  proc hideFromTotalBalance*(self: WalletAccountItem): bool {.slot.} =
    return self.hideFromTotalBalance
  QtProperty[bool] hideFromTotalBalance:
    read = hideFromTotalBalance
    notify = hideFromTotalBalanceChanged

  proc `hideFromTotalBalance=`*(self: WalletAccountItem, value: bool) {.inline.} =
    self.hideFromTotalBalance = value
    self.hideFromTotalBalanceChanged()

  proc delete*(self: WalletAccountItem) =
      self.QObject.delete
  proc setup*(self: WalletAccountItem,
    name: string = "",
    address: string = "",
    mixedcaseAddress: string = "",
    colorId: string = "",
    emoji: string = "",
    walletType: string = "",
    path: string = "",
    keyUid: string = "",
    keycardAccount: bool = false,
    position: int = 0,
    operability: string = wa_dto.AccountFullyOperable,
    areTestNetworksEnabled: bool = false,
    hideFromTotalBalance: bool = true
    ) =
      self.QObject.setup
      self.name = name
      self.address = address
      self.mixedcaseAddress = mixedcaseAddress
      self.colorId = colorId
      self.emoji = emoji
      self.walletType = walletType
      self.path = path
      self.keyUid = keyUid
      self.keycardAccount = keycardAccount
      self.position = position
      self.operability = operability
      self.areTestNetworksEnabled = areTestNetworksEnabled
      self.hideFromTotalBalance = hideFromTotalBalance
