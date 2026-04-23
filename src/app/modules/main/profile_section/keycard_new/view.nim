import nimqml
import io_interface

import app/modules/shared/keypairs

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keyPairItem: KeyPairItem
      keyPairItemVariant: QVariant

  ## Forward declarations
  proc delete*(self: View)

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.keyPairItem = newKeyPairItem()
    result.keyPairItemVariant = newQVariant(result.keyPairItem)

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc isKnownKeyUid*(self: View, keyUid: string): bool {.slot.} =
    return self.delegate.isKnownKeyUid(keyUid)

  proc allNonProfileKeyPairsMigratedToKeycard*(self: View): bool {.slot.} =
    return self.delegate.allNonProfileKeyPairsMigratedToKeycard()

  proc keycardPairingExists*(self: View, keycardUid: string): bool {.slot.} =
    return self.delegate.keycardPairingExists(keycardUid)

  proc remainingKeypairCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingKeypairCapacity()

  proc remainingAccountCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingAccountCapacity()

  proc notifyKeyPairItemChanged*(self: View) {.signal.}
  proc getKeyPairItem*(self: View): QVariant {.slot.} =
    if self.keyPairItemVariant.isNil:
      return newQVariant()
    return self.keyPairItemVariant
  QtProperty[QVariant] keyPairItem:
    read = getKeyPairItem
    notify = keyPairItemChanged

  proc resolveKeyPairItemForKeyUid*(self: View, keyUid: string) {.slot.} =
    var item = self.delegate.getKeyPairItemForKeyUid(keyUid)
    if item.isNil:
      item = newKeyPairItem()
    self.keyPairItem.setItem(item)
    self.notifyKeyPairItemChanged()

  proc delete*(self: View) =
    self.QObject.delete
    if not self.keyPairItem.isNil:
      self.keyPairItem.delete
    if not self.keyPairItemVariant.isNil:
      self.keyPairItemVariant.delete
