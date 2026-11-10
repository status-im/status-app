import nimqml
import io_interface
import sequtils
import ../io_interface as delegate_interface
import view
import ./item
import sets
import controller
import ../../../../global/global_singleton
import ../../../../../app_service/service/dapp_permissions/service as dapp_permissions_service
import ../../../../../app_service/service/wallet_account/service as wallet_account_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    dappsLoaded: bool
    controller: Controller

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  dappPermissionsService: dapp_permissions_service.Service,
  walletAccountServive: wallet_account_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.moduleLoaded = false
  result.dappsLoaded = false
  result.controller = controller.newController(result, dappPermissionsService, walletAccountServive)

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method fetchDapps*(self: Module) =
  self.view.clearDapps()
  let dapps = self.controller.getDapps()
  var items: seq[Item] = @[]

  for dapp in dapps:
    var found = false
    for item in items:
      if item.name == dapp.name:
        found = true

        let account = self.controller.getAccountForAddress(dapp.address)
        if account.isNil:
          break

        item.addAccount(account)
        break
      
    if not found:
      let item = initItem(
        dapp.name, dapp.permissions.mapIt($it)
      )
      items.add(item)
      let account = self.controller.getAccountForAddress(dapp.address)
      item.addAccount(account)
  
  for item in items:
    self.view.addDapp(item)

method load*(self: Module) =
  singletonInstance.setSessionContextProperty("dappPermissionsModule", self.viewVariant)
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.dappsDidLoad()


method loadDapps*(self: Module) =
  if self.dappsLoaded:
    return

  self.fetchDapps()

  self.dappsLoaded = true

method onActivated*(self: Module) =
    self.loadDapps()

method hasPermission*(self: Module, hostname: string, address: string, permission: string): bool =
  self.controller.hasPermission(hostname, address, permission.toPermission())

method addPermission*(self: Module, hostname: string, address: string, permission: string) =
  self.controller.addPermission(hostname, address, permission.toPermission())
  self.fetchDapps()

method removePermission*(self: Module, dapp: string, address: string, permission: string) =
  self.controller.removePermission(dapp, address, permission.toPermission())
  self.fetchDapps()

method disconnectAddress*(self: Module, dapp: string, address: string) =
  self.controller.disconnectAddress(dapp, address)
  self.fetchDapps()

method disconnect*(self: Module, dapp: string) =
  self.controller.disconnect(dapp)
  self.fetchDapps()
