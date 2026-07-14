import nimqml, tables, stint

import ./io_interface, ./view
import  ./controller as all_collectibles_controller
import ../io_interface as delegate_interface

import app/global/global_singleton
import app/core/eventemitter
import app/modules/shared_modules/collectibles/controller as collectibles_controller
import app/modules/shared_models/collectibles_model as collectibles_model
import app/modules/shared_models/collectibles_entry
import app/modules/shared_models/collectibles_selector_model as collectibles_selector_model
import app_service/service/collectible/service as collectible_service
import app_service/service/network/service as network_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/settings/service as settings_service

import backend/collectibles as backend_collectibles

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: all_collectibles_controller.Controller
    collectiblesController: collectibles_controller.Controller
    moduleLoaded: bool
    # Live send-modal picker models, keyed by the id handed to QML; each is
    # re-pushed the whole collectibles universe on any collectibles data change.
    selectorModels: Table[int, collectibles_selector_model.CollectiblesSelectorModel]
    nextSelectorId: int

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  collectibleService: collectible_service.Service,
  networkService: network_service.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.controller = all_collectibles_controller.newController(result, events, collectibleService, networkService, walletAccountService, settingsService)

  let collectiblesController = collectibles_controller.newController(
    requestId = int32(backend_collectibles.CollectiblesRequestID.AllCollectibles),
    loadType = collectibles_controller.LoadType.AutoLoadSingleUpdate,
    networkService = networkService,
    events = events
  )
  result.collectiblesController = collectiblesController

  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.moduleLoaded = false
  result.selectorModels = initTable[int, collectibles_selector_model.CollectiblesSelectorModel]()

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete
  self.controller.delete
  self.collectiblesController.delete

proc buildSelectorSource(self: Module): tuple[
    items: seq[collectibles_selector_model.CollectibleItem],
    networks: seq[collectibles_selector_model.CollectiblesNetworkInfo]] =
  ## Map the collectibles universe (all accounts' ownership) onto the picker's
  ## input DTOs. Soulbound collectibles are dropped (non-transferable), mirroring
  ## the retired adaptor's `soulbound == false` source filter.
  var items: seq[collectibles_selector_model.CollectibleItem] = @[]
  for entry in self.collectiblesController.getModel().getItems():
    if entry.getSoulbound():
      continue
    var ownership: seq[collectibles_selector_model.CollectibleOwnership] = @[]
    for ob in entry.getOwnership():
      ownership.add(collectibles_selector_model.CollectibleOwnership(
        accountAddress: ob.address, balance: ob.balance.truncate(int)))
    items.add(collectibles_selector_model.CollectibleItem(
      key: entry.getIDAsString(),
      chainId: entry.getChainID(),
      collectionUid: entry.getCollectionIDAsString(),
      contractAddress: entry.getContractAddress(),
      tokenId: entry.getTokenIDAsString(),
      tokenType: entry.getTokenType(),
      name: entry.getName(),
      collectionName: entry.getCollectionName(),
      mediaUrl: entry.getMediaURL(),
      imageUrl: entry.getImageURL(),
      communityId: entry.getCommunityId(),
      communityName: entry.getCommunityRawName(),
      communityImage: entry.getCommunityImage(),
      communityPrivilegesLevel: entry.getCommunityPrivilegesLevel(),
      ownership: ownership))

  var networks: seq[collectibles_selector_model.CollectiblesNetworkInfo] = @[]
  for n in self.controller.getFlatNetworks():
    networks.add(collectibles_selector_model.CollectiblesNetworkInfo(
      chainId: n.chainId, chainName: n.chainName, iconUrl: n.iconUrl))
  return (items, networks)

proc pushSelectorSource(self: Module) =
  if self.selectorModels.len == 0:
    return
  let (items, networks) = self.buildSelectorSource()
  for m in self.selectorModels.values:
    m.setSource(items, networks)

method createCollectiblesSelectorModel*(self: Module):
    tuple[id: int, model: collectibles_selector_model.CollectiblesSelectorModel] =
  let model = collectibles_selector_model.newCollectiblesSelectorModel()
  let id = self.nextSelectorId
  self.nextSelectorId.inc
  self.selectorModels[id] = model
  let (items, networks) = self.buildSelectorSource()
  model.setSource(items, networks)
  return (id, model)

method releaseCollectiblesSelectorModel*(self: Module, id: int) =
  self.selectorModels.del(id)

method refreshCollectiblesSelectorModels*(self: Module) =
  self.pushSelectorSource()

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionAllCollectibles", self.viewVariant)

  self.events.on(SIGNAL_COLLECTIBLE_PREFERENCES_UPDATED) do(e: Args):
    let args = ResultArgs(e)
    self.view.collectiblePreferencesUpdated(args.success)

  # Re-derive live picker models when the collectibles universe changes.
  let model = self.collectiblesController.getModel()
  discard QObject.connect(model, collectibles_model.countChanged,
    self.view, onCollectiblesUniverseChanged)
  discard QObject.connect(model, collectibles_model.itemsDataUpdated,
    self.view, onCollectiblesUniverseChanged)

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc refreshCollectiblesFilter(self: Module) =
  let addresses = self.controller.getWalletAddresses()
  let chainIds = self.controller.getChainIds()
  self.collectiblesController.setFilterAddressesAndChains(addresses, chainIds)

method viewDidLoad*(self: Module) =
  self.refreshCollectiblesFilter()
  self.moduleLoaded = true
  self.delegate.allCollectiblesModuleDidLoad()

method setSelectedAccount*(self: Module, address: string) =
  self.collectiblesController.setSelectedAccount(address)

method getAllCollectiblesModel*(self: Module): collectibles_model.Model =
  return self.collectiblesController.getModel()

method refreshNetworks*(self: Module) =
  self.refreshCollectiblesFilter()

method refreshWalletAccounts*(self: Module) =
  self.refreshCollectiblesFilter()

method updateCollectiblePreferences*(self: Module, collectiblePreferencesJson: string) {.slot.} =
  self.controller.updateCollectiblePreferences(collectiblePreferencesJson)

method getCollectiblePreferencesJson*(self: Module): string =
  return self.controller.getCollectiblePreferencesJson()

method getCollectibleGroupByCommunity*(self: Module): bool =
  return self.controller.getCollectibleGroupByCommunity()

method toggleCollectibleGroupByCommunity*(self: Module): bool =
  return self.controller.toggleCollectibleGroupByCommunity()

method getCollectibleGroupByCollection*(self: Module): bool =
  return self.controller.getCollectibleGroupByCollection()

method toggleCollectibleGroupByCollection*(self: Module): bool =
  return self.controller.toggleCollectibleGroupByCollection()
