import nimqml, std/strformat
import ../../../shared_models/keypair_item

export keypair_item

QtObject:
  type KeycardItem* = ref object of KeyPairItem
    keycardUid: string

  proc delete*(self: KeycardItem)
  proc initKeycardItem*(
      keycardUid = "",
      keyUid = "",
      pubKey = "",
      locked = false,
      name = "",
      image = "",
      icon = "",
      pairType = KeyPairType.Unknown,
      derivedFrom = "",
      lastUsedDerivationIndex = 0,
      migratedToKeycard = true
      ): KeycardItem =
    new(result, delete)
    result.KeyPairItem.setup(keyUid, pubKey, locked, name, image, icon, pairType, derivedFrom,lastUsedDerivationIndex,
      migratedToKeycard, syncedFrom = "", ownershipVerified = false)
    result.keycardUid = keycardUid

  proc `$`*(self: KeycardItem): string =
    result = fmt"""KeycardItem[
      keycardUid: {self.keycardUid},
      pubKey: {self.getPubKey()},
      keyUid: {self.getKeyUid()},
      locked: {self.getLocked()},
      name: {self.getName()},
      image: {self.getImage()},
      icon: {self.getIcon()},
      pairType: {$self.getPairType()},
      derivedFrom: {self.getDerivedFrom()},
      accounts: {self.getAccountsModel()}
      ]"""

  proc keycardUidChanged*(self: KeycardItem) {.signal.}
  proc getKeycardUid*(self: KeycardItem): string {.slot.} =
    return self.keycardUid
  proc setKeycardUid*(self: KeycardItem, value: string) {.slot.} =
    self.keycardUid = value
    self.keycardUidChanged()
  QtProperty[string] keycardUid:
    read = getKeycardUid
    write = setKeycardUid
    notify = keycardUidChanged

  proc setItem*(self: KeycardItem, item: KeycardItem) =
    self.setKeycardUid(item.getKeycardUid())
    self.KeyPairItem.setItem(KeyPairItem(item))

  proc delete*(self: KeycardItem) =
      self.KeyPairItem.delete

