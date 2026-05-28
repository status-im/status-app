import io_interface
import ../../../../../app_service/service/wallet_account/service as wallet_account_service
import ../../../../../app_service/service/network/service as network_service
import ../../../../../app_service/service/currency/service as currency_service
import ../../../../../app_service/service/currency/dto as currency_dto

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    walletAccountService: wallet_account_service.Service
    networkService: network_service.Service
    currencyService: currency_service.Service

proc newController*(
  delegate: io_interface.AccessInterface,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  currencyService: currency_service.Service,
): Controller =
  result = Controller()
  result.delegate = delegate
  result.walletAccountService = walletAccountService
  result.networkService = networkService
  result.currencyService = currencyService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  discard

proc getWalletAccounts*(self: Controller): seq[wallet_account_service.WalletAccountDto] =
  return self.walletAccountService.getWalletAccounts()

proc getWalletAccountsByAddresses*(self: Controller, addresses: seq[string]): seq[wallet_account_service.WalletAccountDto] =
  return self.walletAccountService.getAccountsByAddresses(addresses)

proc isKeycardAccount*(self: Controller, account: WalletAccountDto): bool =
  return self.walletAccountService.isKeycardAccount(account)

proc deleteAccount*(self: Controller, address: string, password: string) =
  self.walletAccountService.deleteAccount(address, password)

proc getEnabledChainIds*(self: Controller): seq[int] =
  return self.networkService.getEnabledChainIds()

proc getCurrentCurrency*(self: Controller): string =
  return self.walletAccountService.getCurrency()

proc getCurrencyFormat*(self: Controller, key: string): CurrencyFormatDto =
  return self.currencyService.getCurrencyFormat(key)

proc getKeycardsWithSameKeyUid*(self: Controller, keyUid: string): seq[KeycardDto] =
  # TODO: re-implement when integrating new keycard approach
  return @[]

proc getWalletAccount*(self: Controller, address: string): WalletAccountDto =
  return self.walletAccountService.getAccountByAddress(address)

proc updateAccount*(self: Controller, address: string, accountName: string, colorId: string, emoji: string) =
  discard self.walletAccountService.updateWalletAccount(address, accountName, colorId, emoji)

proc areTestNetworksEnabled*(self: Controller): bool =
  return self.walletAccountService.areTestNetworksEnabled()

proc getTotalCurrencyBalance*(self: Controller, address: string, chainIds: seq[int]): float64 =
  return self.walletAccountService.getTotalCurrencyBalance(@[address], chainIds)

proc updateWatchAccountHiddenFromTotalBalance*(self: Controller, address: string, hideFromTotalBalance: bool) =
  discard self.walletAccountService.updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance)

proc getTokensMarketValuesLoading*(self: Controller): bool =
  return self.walletAccountService.getTokensMarketValuesLoading()