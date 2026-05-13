import nimqml

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/keycardV2/service as keycard_serviceV2
import app/modules/shared/keypairs

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    walletAccountService: wallet_account_service.Service
    ): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, walletAccountService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.view.load()
  self.controller.init()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.keycardNewModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method isKnownKeyUid*(self: Module, keyUid: string): bool =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return false
  return true

method allNonProfileKeyPairsMigratedToKeycard*(self: Module): bool =
  let keypairs = self.controller.getKeypairs()
  for keypair in keypairs:
    if not keypair.isNil and
      keypair.keypairType != KeypairTypeProfile and
      not keypair.removed and
      not keypair.migratedToKeycard():
        return false
  return true

method getKeyPairItemForKeyUid*(self: Module, keyUid: string): KeyPairItem =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return nil
  let areTestNetworksEnabled = self.controller.areTestNetworksEnabled()
  return buildKeypairItem(keypair, areTestNetworksEnabled)

method remainingKeypairCapacity*(self: Module): int =
  return self.controller.remainingKeypairCapacity()

method remainingAccountCapacity*(self: Module): int =
  return self.controller.remainingAccountCapacity()

method keycardPairingExists*(self: Module, keycardUid: string): bool =
  return keycard_serviceV2.keycardPairingExists(keycardUid)