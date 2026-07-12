import io_interface
import app_service/service/token/service as token_service
import app_service/service/token/items/token_group
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/wallet_account/dto/asset_group_item
import app_service/service/network/service as network_service
import app_service/service/network/network_item

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    tokenService: token_service.Service
    walletAccountService: wallet_account_service.Service
    networkService: network_service.Service

proc newController*(
  delegate: io_interface.AccessInterface,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
): Controller =
  result = Controller()
  result.delegate = delegate
  result.tokenService = tokenService
  result.walletAccountService = walletAccountService
  result.networkService = networkService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  discard

proc getTokenGroups*(self: Controller): var seq[TokenGroupItem] =
  return self.tokenService.getGroupsOfInterest()

proc getGroupedAssetsList*(self: Controller): var seq[AssetGroupItem] =
  return self.walletAccountService.getGroupedAssetsList()

proc getPriceForToken*(self: Controller, tokenKey: string): float64 =
  return self.tokenService.getPriceForToken(tokenKey)

proc getCurrentNetworks*(self: Controller): seq[NetworkItem] =
  return self.networkService.getCurrentNetworks()
