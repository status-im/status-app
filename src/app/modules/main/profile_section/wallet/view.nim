import nimqml

import ./io_interface
from app/modules/shared_modules/keypair_import/module import ImportKeypairModuleMode

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate

  proc getAccountsModule(self: View): QVariant {.slot.} =
    return self.delegate.getAccountsModule()
  QtProperty[QVariant] accountsModule:
    read = getAccountsModule

  proc getCollectiblesModel(self: View): QVariant {.slot.} =
    return self.delegate.getCollectiblesModel()
  QtProperty[QVariant] collectiblesModel:
    read = getCollectiblesModel

  proc runKeypairImportPopup*(self: View, keyUid: string, mode: int) {.slot.} =
    self.delegate.runKeypairImportPopup(keyUid, ImportKeypairModuleMode(mode))

  proc keypairImportModuleChanged*(self: View) {.signal.}
  proc emitKeypairImportModuleChangedSignal*(self: View) =
    self.keypairImportModuleChanged()
  proc getKeypairImportModule(self: View): QVariant {.slot.} =
    return self.delegate.getKeypairImportModule()
  QtProperty[QVariant] keypairImportModule:
    read = getKeypairImportModule
    notify = keypairImportModuleChanged

  proc displayKeypairImportPopup*(self: View) {.signal.}
  proc emitDisplayKeypairImportPopup*(self: View) =
    self.displayKeypairImportPopup()

  proc destroyKeypairImportPopup*(self: View) {.signal.}
  proc emitDestroyKeypairImportPopup*(self: View) =
    self.destroyKeypairImportPopup()

  proc hasPairedDevicesChanged*(self: View) {.signal.}
  proc emitHasPairedDevicesChangedSignal*(self: View) =
    self.hasPairedDevicesChanged()
  proc getHasPairedDevices(self: View): bool {.slot.} =
    return self.delegate.hasPairedDevices()
  QtProperty[bool] hasPairedDevices:
    read = getHasPairedDevices
    notify = hasPairedDevicesChanged

  proc autoApplyKeypairMigrationsChanged*(self: View) {.signal.}
  proc emitAutoApplyKeypairMigrationsChangedSignal*(self: View) =
    self.autoApplyKeypairMigrationsChanged()
  proc getAutoApplyKeypairMigrations(self: View): bool {.slot.} =
    return self.delegate.getAutoApplyKeypairMigrations()
  proc setAutoApplyKeypairMigrations*(self: View, value: bool) {.slot.} =
    self.delegate.setAutoApplyKeypairMigrations(value)
  QtProperty[bool] autoApplyKeypairMigrations:
    read = getAutoApplyKeypairMigrations
    notify = autoApplyKeypairMigrationsChanged

  proc getRpcStats(self: View): string {.slot.} =
    return self.delegate.getRpcStats()
  proc resetRpcStats(self: View) {.slot.} =
    self.delegate.resetRpcStats()

  proc refetchTxHistory*(self: View) {.slot.} =
    self.delegate.refetchTxHistory()

  proc delete*(self: View) =
    self.QObject.delete

