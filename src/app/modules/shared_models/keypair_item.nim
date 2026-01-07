import nimqml, std/strformat, sequtils, sugar
import keypair_account_model
import ./currency_amount

export keypair_account_model

type
  KeyPairType* {.pure.} = enum
    Unknown = -1
    Profile
    SeedImport
    PrivateKeyImport
    WatchOnly

QtObject:
  type KeyPairItem* = ref object of QObject
    keyUid: string
    pubKey: string
    locked: bool
    name: string
    image: string
    icon: string
    pairType: KeyPairType
    derivedFrom: string
    lastUsedDerivationIndex: int
    migratedToKeycard: bool
    operability: string
    syncedFrom: string
    accounts: KeyPairAccountModel
    observedAccount: KeyPairAccountItem
    ownershipVerified: bool

  proc setup*(self: KeyPairItem,
      keyUid: string,
      pubKey: string,
      locked: bool,
      name: string,
      image: string,
      icon: string,
      pairType: KeyPairType,
      derivedFrom: string,
      lastUsedDerivationIndex: int,
      migratedToKeycard: bool,
      syncedFrom: string,
      ownershipVerified: bool
      )
  proc delete*(self: KeyPairItem)
  proc newKeyPairItem*(keyUid = "",
    pubKey = "",
    locked = false,
    name = "",
    image = "",
    icon = "",
    pairType = KeyPairType.Unknown,
    derivedFrom = "",
    lastUsedDerivationIndex = 0,
    migratedToKeycard = false,
    syncedFrom = "",
    ownershipVerified = false): KeyPairItem =
    new(result, delete)
    result.setup(keyUid, pubKey, locked, name, image, icon, pairType, derivedFrom, lastUsedDerivationIndex,
      migratedToKeycard, syncedFrom, ownershipVerified)

  proc `$`*(self: KeyPairItem): string =
    result = fmt"""KeyPairItem[
      keyUid: {self.keyUid},
      pubKey: {self.pubkey},
      name: {self.name},
      locked: {self.locked},
      image: {self.image},
      icon: {self.icon},
      pairType: {$self.pairType},
      derivedFrom: {self.derivedFrom},
      lastUsedDerivationIndex: {self.lastUsedDerivationIndex},
      migratedToKeycard: {self.migratedToKeycard},
      operability: {self.operability},
      syncedFrom: {self.syncedFrom},
      ownershipVerified: {$self.ownershipVerified}
      accounts: {$self.accounts},
      ]"""

  proc getAccountByAddress*(self: KeyPairItem, address: string): KeyPairAccountItem =
    return self.accounts.getItemByAddress(address)

  proc keyUidChanged*(self: KeyPairItem) {.signal.}
  proc getKeyUid*(self: KeyPairItem): string {.slot.} =
    return self.keyUid
  proc setKeyUid*(self: KeyPairItem, value: string) {.slot.} =
    self.keyUid = value
    self.keyUidChanged()
  QtProperty[string] keyUid:
    read = getKeyUid
    write = setKeyUid
    notify = keyUidChanged

  proc pubKeyChanged*(self: KeyPairItem) {.signal.}
  proc getPubKey*(self: KeyPairItem): string {.slot.} =
    return self.pubKey
  proc setPubKey*(self: KeyPairItem, value: string) {.slot.} =
    self.pubKey = value
    self.pubKeyChanged()
  QtProperty[string] pubKey:
    read = getPubKey
    write = setPubKey
    notify = pubKeyChanged

  proc lockedChanged*(self: KeyPairItem) {.signal.}
  proc getLocked*(self: KeyPairItem): bool {.slot.} =
    return self.locked
  proc setLocked*(self: KeyPairItem, value: bool) {.slot.} =
    self.locked = value
    self.lockedChanged()
  QtProperty[bool] locked:
    read = getLocked
    write = setLocked
    notify = lockedChanged

  proc nameChanged*(self: KeyPairItem) {.signal.}
  proc getName*(self: KeyPairItem): string {.slot.} =
    return self.name
  proc setName*(self: KeyPairItem, value: string) {.slot.} =
    self.name = value
    self.nameChanged()
  QtProperty[string] name:
    read = getName
    write = setName
    notify = nameChanged

  proc imageChanged*(self: KeyPairItem) {.signal.}
  proc getImage*(self: KeyPairItem): string {.slot.} =
    return self.image
  proc setImage*(self: KeyPairItem, value: string) {.slot.} =
    self.image = value
    self.imageChanged()
  QtProperty[string] image:
    read = getImage
    write = setImage
    notify = imageChanged

  proc iconChanged*(self: KeyPairItem) {.signal.}
  proc getIcon*(self: KeyPairItem): string {.slot.} =
    return self.icon
  proc setIcon*(self: KeyPairItem, value: string) {.slot.} =
    self.icon = value
    self.iconChanged()
  QtProperty[string] icon:
    read = getIcon
    write = setIcon
    notify = iconChanged

  proc pairTypeChanged*(self: KeyPairItem) {.signal.}
  proc getPairType*(self: KeyPairItem): int {.slot.} =
    return self.pairType.int
  proc setPairType*(self: KeyPairItem, value: int) {.slot.} =
    self.pairType = value.KeyPairType
    self.pairTypeChanged()
  QtProperty[int] pairType:
    read = getPairType
    write = setPairType
    notify = pairTypeChanged

  proc derivedFromChanged*(self: KeyPairItem) {.signal.}
  proc getDerivedFrom*(self: KeyPairItem): string {.slot.} =
    return self.derivedFrom
  proc setDerivedFrom*(self: KeyPairItem, value: string) {.slot.} =
    self.derivedFrom = value
    self.derivedFromChanged()
  QtProperty[string] derivedFrom:
    read = getDerivedFrom
    write = setDerivedFrom
    notify = derivedFromChanged

  proc lastUsedDerivationIndexChanged*(self: KeyPairItem) {.signal.}
  proc getLastUsedDerivationIndex*(self: KeyPairItem): int {.slot.} =
    return self.lastUsedDerivationIndex
  proc setLastUsedDerivationIndex*(self: KeyPairItem, value: int) {.slot.} =
    self.lastUsedDerivationIndex = value
    self.lastUsedDerivationIndexChanged()
  QtProperty[int] lastUsedDerivationIndex:
    read = getLastUsedDerivationIndex
    write = setLastUsedDerivationIndex
    notify = lastUsedDerivationIndexChanged

  proc migratedToKeycardChanged*(self: KeyPairItem) {.signal.}
  proc getMigratedToKeycard*(self: KeyPairItem): bool {.slot.} =
    return self.migratedToKeycard
  proc setMigratedToKeycard*(self: KeyPairItem, value: bool) {.slot.} =
    self.migratedToKeycard = value
    self.migratedToKeycardChanged()
  QtProperty[bool] migratedToKeycard:
    read = getMigratedToKeycard
    write = setMigratedToKeycard
    notify = migratedToKeycardChanged

  proc operabilityChanged*(self: KeyPairItem) {.signal.}
  proc getOperability*(self: KeyPairItem): string {.slot.} =
    let items = self.accounts.getItems()
    if items.any(x => x.getOperability() == AccountNonOperable):
      return AccountNonOperable
    if items.any(x => x.getOperability() == AccountPartiallyOperable):
      return AccountPartiallyOperable
    return AccountFullyOperable
  QtProperty[string] operability:
    read = getOperability
    notify = operabilityChanged

  proc syncedFromChanged*(self: KeyPairItem) {.signal.}
  proc getSyncedFrom*(self: KeyPairItem): string {.slot.} =
    return self.syncedFrom
  proc setSyncedFrom*(self: KeyPairItem, value: string) {.slot.} =
    self.syncedFrom = value
    self.syncedFromChanged()
  QtProperty[string] syncedFrom:
    read = getSyncedFrom
    write = setSyncedFrom
    notify = syncedFromChanged

  proc ownershipVerifiedChanged*(self: KeyPairItem) {.signal.}
  proc getOwnershipVerified*(self: KeyPairItem): bool {.slot.} =
    return self.ownershipVerified
  proc setOwnershipVerified*(self: KeyPairItem, value: bool) {.slot.} =
    self.ownershipVerified = value
    self.ownershipVerifiedChanged()
  QtProperty[bool] ownershipVerified:
    read = getOwnershipVerified
    write = setOwnershipVerified
    notify = ownershipVerifiedChanged

  proc observedAccountChanged*(self: KeyPairItem) {.signal.}
  proc getObservedAccountAsVariant*(self: KeyPairItem): QVariant {.slot.} =
    return newQVariant(self.observedAccount)
  QtProperty[QVariant] observedAccount:
    read = getObservedAccountAsVariant
    notify = observedAccountChanged
  proc setAccountAtIndexAsObservedAccount*(self: KeyPairItem, index: int) {.slot.} =
    self.observedAccount = self.accounts.getItemAtIndex(index)
    self.observedAccountChanged()
  proc setLastAccountAsObservedAccount(self: KeyPairItem) =
    let index = self.accounts.getCount() - 1
    self.setAccountAtIndexAsObservedAccount(index)
  proc getAccountsModel*(self: KeyPairItem): KeyPairAccountModel =
    return self.accounts
  proc getAccountsAsVariant*(self: KeyPairItem): QVariant {.slot.} =
    return newQVariant(self.accounts)
  QtProperty[QVariant] accounts:
    read = getAccountsAsVariant
  proc removeAccountAtIndex*(self: KeyPairItem, index: int) {.slot.} =
    self.accounts.removeItemAtIndex(index)
    self.setLastAccountAsObservedAccount()
    self.operabilityChanged()
  proc removeAccountByAddress*(self: KeyPairItem, address: string) {.slot.} =
    self.accounts.removeItemByAddress(address)
    self.setLastAccountAsObservedAccount()
    self.operabilityChanged()
  proc addAccount*(self: KeyPairItem, item: KeyPairAccountItem) =
    self.accounts.addItem(item)
    self.setLastAccountAsObservedAccount()
    self.operabilityChanged()
  proc setAccounts*(self: KeyPairItem, items: seq[KeyPairAccountItem]) =
    self.accounts.setItems(items)
    self.setLastAccountAsObservedAccount()
    self.operabilityChanged()
  proc containsAccountAddress*(self: KeyPairItem, address: string): bool =
    return self.accounts.containsAccountAddress(address)
  proc containsAccountPath*(self: KeyPairItem, path: string): bool =
    return self.accounts.containsAccountPath(path)
  proc containsPathOutOfTheDefaultStatusDerivationTree*(self: KeyPairItem): bool {.slot.} =
    return self.accounts.containsPathOutOfTheDefaultStatusDerivationTree()
  proc updateDetailsForAccountWithAddressIfTheyAreSet*(self: KeyPairItem, address, name, colorId, emoji: string) =
    self.accounts.updateDetailsForAddressIfTheyAreSet(address, name, colorId, emoji)
  proc updateAccountHiddenInTotalBalance*(self: KeyPairItem, address: string, hideFromTotalBalance: bool) =
    self.accounts.updateAccountHiddenInTotalBalance(address, hideFromTotalBalance)
  proc setBalanceForAddress*(self: KeyPairItem, address: string, balance: CurrencyAmount) =
    self.accounts.setBalanceForAddress(address, balance)
  proc updateOperabilityForAllAddresses*(self: KeyPairItem, operability: string) =
    self.accounts.updateOperabilityForAllAddresses(operability)
    self.operabilityChanged()

  proc setItem*(self: KeyPairItem, item: KeyPairItem) =
    self.setKeyUid(item.getKeyUid())
    self.setPubKey(item.getPubKey())
    self.setLocked(item.getLocked())
    self.setName(item.getName())
    self.setImage(item.getImage())
    self.setIcon(item.getIcon())
    self.setPairType(item.getPairType())
    self.setDerivedFrom(item.getDerivedFrom())
    self.setMigratedToKeycard(item.getMigratedToKeycard())
    self.setLastUsedDerivationIndex(item.getLastUsedDerivationIndex())
    self.setAccounts(item.getAccountsModel().getItems())
    self.setOwnershipVerified(item.getOwnershipVerified())
    self.setLastAccountAsObservedAccount()

  proc delete*(self: KeyPairItem) =
    self.QObject.delete

  proc setup*(self: KeyPairItem,
      keyUid: string,
      pubKey: string,
      locked: bool,
      name: string,
      image: string,
      icon: string,
      pairType: KeyPairType,
      derivedFrom: string,
      lastUsedDerivationIndex: int,
      migratedToKeycard: bool,
      syncedFrom: string,
      ownershipVerified: bool
      ) =
      self.QObject.setup
      self.keyUid = keyUid
      self.pubKey = pubKey
      self.locked = locked
      self.name = name
      self.image = image
      self.icon = icon
      self.pairType = pairType
      self.derivedFrom = derivedFrom
      self.lastUsedDerivationIndex = lastUsedDerivationIndex
      self.migratedToKeycard = migratedToKeycard
      self.syncedFrom = syncedFrom
      self.ownershipVerified = ownershipVerified
      self.accounts = newKeyPairAccountModel()