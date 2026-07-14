import json, sequtils, sugar

import ./io_interface

import app/core/eventemitter
import app_service/service/collectible/service as collectible_service
import app_service/service/network/service as network_service
import app_service/service/network/network_item
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/settings/service as settings_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    collectibleService: collectible_service.Service
    networkService: network_service.Service
    walletAccountService: wallet_account_service.Service
    settingsService: settings_service.Service

proc newController*(
  delegate: io_interface.AccessInterface,
  events: EventEmitter,
  collectibleService: collectible_service.Service,
  networkService: network_service.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service
): Controller =
  result = Controller()
  result.events = events
  result.delegate = delegate
  result.networkService = networkService
  result.walletAccountService = walletAccountService
  result.collectibleService = collectibleService
  result.settingsService = settingsService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_WALLET_ACCOUNT_SAVED) do(e:Args):
    self.delegate.refreshWalletAccounts()

  self.events.on(SIGNAL_WALLET_ACCOUNT_DELETED) do(e:Args):
    self.delegate.refreshWalletAccounts()

  self.events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e: Args):
    self.delegate.refreshNetworks()

proc getWalletAddresses*(self: Controller): seq[string] =
  return self.walletAccountService.getWalletAccounts().map(a => a.address)

proc getChainIds*(self: Controller): seq[int] =
  return self.networkService.getCurrentNetworksChainIds()

proc getFlatNetworks*(self: Controller): seq[NetworkItem] =
  return self.networkService.getFlatNetworks()

proc updateCollectiblePreferences*(self: Controller, tokenPreferencesJson: string) =
  self.collectibleService.updateCollectiblePreferences(tokenPreferencesJson)

proc getCollectiblePreferencesJson*(self: Controller): string =
  let data = self.collectibleService.getCollectiblePreferences()
  if data.isNil:
    return "[]"
  return $data

proc getCollectibleGroupByCommunity*(self: Controller): bool =
  return self.settingsService.collectibleGroupByCommunity()

proc toggleCollectibleGroupByCommunity*(self: Controller): bool =
  return self.settingsService.toggleCollectibleGroupByCommunity()

proc getCollectibleGroupByCollection*(self: Controller): bool =
  return self.settingsService.collectibleGroupByCollection()

proc toggleCollectibleGroupByCollection*(self: Controller): bool =
  return self.settingsService.toggleCollectibleGroupByCollection()
