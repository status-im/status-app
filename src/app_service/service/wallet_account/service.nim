import nimqml, tables, json, sequtils, sugar, chronicles, std/strformat, stint
import net, strutils, os, times, algorithm, options, sets
import web3/eth_api_types

import app/global/global_singleton

import app_service/service/general/debouncer as debouncer_service
import app_service/service/settings/service as settings_service
import app_service/service/accounts/service as accounts_service
import app_service/service/token/service as token_service
import app_service/service/network/service as network_service
import app_service/service/currency/service as currency_service
import app_service/common/[utils]

import dto/keypair_dto as keypair_dto
import dto/derived_address_dto as derived_address_dto

import app/core/eventemitter
import app/core/signals/types
import app/core/tasks/[qt, threadpool]
import backend/accounts as status_go_accounts
import backend/backend as backend
import backend/network as status_go_network
import backend/eth as status_go_eth
import backend/collectibles
import backend/wallet as status_go_wallet
import constants as main_constants


export keypair_dto, derived_address_dto

logScope:
  topics = "wallet-account-service"

include signals_and_payloads
include utils
include async_tasks
include  ../../common/json_utils

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    settingsService: settings_service.Service
    accountsService: accounts_service.Service
    tokenService: token_service.Service
    networkService: network_service.Service
    currencyService: currency_service.Service
    watchOnlyAccounts: Table[string, WalletAccountDto] ## [address, WalletAccountDto]
    keypairs: Table[string, KeypairDto] ## [keyUid, KeypairDto]
    groupedAssets: seq[AssetGroupItem]
    hasBalanceCache: bool
    buildTokensDebouncer: debouncer_service.Debouncer

  # Forward declaration
  proc buildAllTokens*(self: Service, accounts: seq[string], forceRefresh: bool)
  proc buildAllTokensInternal(self: Service, accounts: seq[string], forceRefresh: bool)
  proc handleWalletAccount(self: Service, account: WalletAccountDto, notify: bool = true)
  proc handleKeypair(self: Service, keypair: KeypairDto)
  proc updateAccountsPositions(self: Service)
  proc importPartiallyOperableAccounts(self: Service, keyUid: string, password: string)
  proc cleanKeystoreFiles(self: Service, password: string)
  proc getCurrencyValueForToken*(self: Service, tokenKey: string, amountInt: UInt256): float64
  proc fetchENSNamesForAddressesAsync(self: Service, addresses: seq[string], chainId: int)
  # All slots defined in included files have to be forward declared
  proc onAllTokensBuilt(self: Service, response: string) {.slot.}
  proc onDerivedAddressesFetched*(self: Service, jsonString: string) {.slot.}
  proc onDerivedAddressesForMnemonicFetched*(self: Service, jsonString: string) {.slot.}
  proc onAddressDetailsFetched*(self: Service, jsonString: string) {.slot.}
  proc onKeycardAdded*(self: Service, response: string) {.slot.}
  proc onMigratedAccountsForKeycardRemoved*(self: Service, response: string) {.slot.}
  proc onFetchChainIdForUrl*(self: Service, jsonString: string) {.slot.}
  proc onNonProfileKeycardKeypairMigratedToApp*(self: Service, response: string) {.slot.}
  proc onENSNamesFetched*(self: Service, response: string) {.slot.}

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool,
    settingsService: settings_service.Service,
    accountsService: accounts_service.Service,
    tokenService: token_service.Service,
    networkService: network_service.Service,
    currencyService: currency_service.Service,
  ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.settingsService = settingsService
    result.accountsService = accountsService
    result.tokenService = tokenService
    result.networkService = networkService
    result.currencyService = currencyService

  proc isChecksumValidForAddress*(self: Service, address: string): bool =
    var updated = false
    try:
      let response = backend.isChecksumValidForAddress(address)
      if not response.error.isNil:
        error "status-go error", procName="isChecksumValidForAddress", errCode=response.error.code, errDesription=response.error.message
      return response.result.getBool
    except Exception as e:
      error "error: ", procName="isChecksumValidForAddress", errName=e.name, errDesription=e.msg

  proc refetchTxHistory*(self: Service) =
    try:
      discard status_go_wallet.refetchTxHistory()
    except Exception as e:
      let errDescription = e.msg
      error "error: ", errDescription

  include service_account
  include service_token
  include service_keycard

  proc delete*(self: Service) =
    self.QObject.delete

