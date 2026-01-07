import nimqml, std/strformat
import app_service/service/wallet_account/dto/account_dto as wa_dto
import ./currency_amount

export wa_dto

QtObject:
  type KeyPairAccountItem* = ref object of QObject
    name: string
    path: string
    address: string
    pubKey: string
    operability: string
    emoji: string
    colorId: string
    icon: string
    balance: CurrencyAmount
    balanceFetched: bool
    isDefaultAccount: bool
    areTestNetworksEnabled: bool
    hideFromTotalBalance: bool

  proc delete*(self: KeyPairAccountItem)
  proc newKeyPairAccountItem*(name = "", path = "", address = "", pubKey = "", emoji = "", colorId = "", icon = "",
    balance = newCurrencyAmount(), balanceFetched = true, operability = wa_dto.AccountFullyOperable,
    isDefaultAccount = false, areTestNetworksEnabled =false, hideFromTotalBalance = false): KeyPairAccountItem =
    new(result, delete)
    result.QObject.setup
    result.name = name
    result.path = path
    result.address = address
    result.pubKey = pubKey
    result.emoji = emoji
    result.colorId = colorId
    result.icon = icon
    result.balance = balance
    result.balanceFetched = balanceFetched
    result.operability = operability
    result.isDefaultAccount = isDefaultAccount
    result.areTestNetworksEnabled = areTestNetworksEnabled
    result.hideFromTotalBalance = hideFromTotalBalance

  proc `$`*(self: KeyPairAccountItem): string =
    result = fmt"""KeyPairAccountItem[
      name: {self.name},
      path: {self.path},
      address: {self.address},
      pubKey: {self.pubKey},
      emoji: {self.emoji},
      colorId: {self.colorId},
      icon: {self.icon},
      balance: {self.balance},
      balanceFetched: {self.balanceFetched},
      operability: {self.operability},
      isDefaultAccount: {self.isDefaultAccount},
      areTestNetworksEnabled: {self.areTestNetworksEnabled},
      hideFromTotalBalance: {self.hideFromTotalBalance}
      ]"""

  proc nameChanged*(self: KeyPairAccountItem) {.signal.}
  proc getName*(self: KeyPairAccountItem): string {.slot.} =
    return self.name
  proc setName*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.name = value
    self.nameChanged()
  QtProperty[string] name:
    read = getName
    write = setName
    notify = nameChanged

  proc pathChanged*(self: KeyPairAccountItem) {.signal.}
  proc getPath*(self: KeyPairAccountItem): string {.slot.} =
    return self.path
  proc setPath*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.path = value
    self.pathChanged()
  QtProperty[string] path:
    read = getPath
    write = setPath
    notify = pathChanged

  proc addressChanged*(self: KeyPairAccountItem) {.signal.}
  proc getAddress*(self: KeyPairAccountItem): string {.slot.} =
    return self.address
  proc setAddress*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.address = value
    self.addressChanged()
  QtProperty[string] address:
    read = getAddress
    write = setAddress
    notify = addressChanged

  proc pubKeyChanged*(self: KeyPairAccountItem) {.signal.}
  proc getPubKey*(self: KeyPairAccountItem): string {.slot.} =
    return self.pubKey
  proc setPubKey*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.pubKey = value
    self.pubKeyChanged()
  QtProperty[string] pubKey:
    read = getPubKey
    write = setPubKey
    notify = pubKeyChanged

  proc operabilityChanged*(self: KeyPairAccountItem) {.signal.}
  proc getOperability*(self: KeyPairAccountItem): string {.slot.} =
    return self.operability
  proc setOperability*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.operability = value
    self.operabilityChanged()
  QtProperty[string] operability:
    read = getOperability
    write = setOperability
    notify = operabilityChanged

  proc emojiChanged*(self: KeyPairAccountItem) {.signal.}
  proc getEmoji*(self: KeyPairAccountItem): string {.slot.} =
    return self.emoji
  proc setEmoji*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.emoji = value
    self.emojiChanged()
  QtProperty[string] emoji:
    read = getEmoji
    write = setEmoji
    notify = emojiChanged

  proc colorIdChanged*(self: KeyPairAccountItem) {.signal.}
  proc getColorId*(self: KeyPairAccountItem): string {.slot.} =
    return self.colorId
  proc setColorId*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.colorId = value
    self.colorIdChanged()
  QtProperty[string] colorId:
    read = getColorId
    write = setColorId
    notify = colorIdChanged

  proc iconChanged*(self: KeyPairAccountItem) {.signal.}
  proc getIcon*(self: KeyPairAccountItem): string {.slot.} =
    return self.icon
  proc setIcon*(self: KeyPairAccountItem, value: string) {.slot.} =
    self.icon = value
    self.iconChanged()
  QtProperty[string] icon:
    read = getIcon
    write = setIcon
    notify = iconChanged

  proc balanceChanged*(self: KeyPairAccountItem) {.signal.}
  proc getBalance*(self: KeyPairAccountItem): QVariant {.slot.} =
    return newQVariant(self.balance)
  proc setBalance*(self: KeyPairAccountItem, value: CurrencyAmount) =
    self.balance = value
    self.balanceFetched = true
    self.balanceChanged()
  QtProperty[QVariant] balance:
    read = getBalance
    write = setBalance
    notify = balanceChanged

  proc getBalanceFetched*(self: KeyPairAccountItem): bool {.slot.} =
    return self.balanceFetched
  QtProperty[bool] balanceFetched:
    read = getBalanceFetched
    notify = balanceChanged

  proc isDefaultAccountChanged*(self: KeyPairAccountItem) {.signal.}
  proc getIsDefaultAccount*(self: KeyPairAccountItem): bool {.slot.} =
    return self.isDefaultAccount
  QtProperty[bool] isDefaultAccount:
    read = getIsDefaultAccount
    notify = isDefaultAccountChanged

  proc hideFromTotalBalanceChanged*(self: KeyPairAccountItem) {.signal.}
  proc hideFromTotalBalance*(self: KeyPairAccountItem): bool {.slot.} =
    return self.hideFromTotalBalance
  proc setHideFromTotalBalance*(self: KeyPairAccountItem, value: bool) =
    self.hideFromTotalBalance = value
    self.hideFromTotalBalanceChanged()
  QtProperty[bool] hideFromTotalBalance:
    read = hideFromTotalBalance
    notify = hideFromTotalBalanceChanged

  proc delete*(self: KeyPairAccountItem) =
    self.QObject.delete

