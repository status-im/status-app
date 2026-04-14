import uuids, chronicles
import io_interface

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/settings/service as settings_service
import app_service/service/ens/service as ens_service
import app_service/service/network/service as network_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/token/service as token_service
import app_service/service/network/network_item

logScope:
  topics = "profile-section-ens-usernames-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    settingsService: settings_service.Service
    ensService: ens_service.Service
    networkService: network_service.Service
    walletAccountService: wallet_account_service.Service
    tokenService: token_service.Service
    connectionKeycardResponse: UUID

proc newController*(
  delegate: io_interface.AccessInterface, events: EventEmitter,
  settingsService: settings_service.Service, ensService: ens_service.Service,
  walletAccountService: wallet_account_service.Service, networkService: network_service.Service,
  tokenService: token_service.Service,
): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.settingsService = settingsService
  result.ensService = ensService
  result.walletAccountService = walletAccountService
  result.networkService = networkService
  result.tokenService = tokenService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_ENS_USERNAME_AVAILABILITY_CHECKED) do(e:Args):
    let args = EnsUsernameAvailabilityArgs(e)
    self.delegate.ensUsernameAvailabilityChecked(args.availabilityStatus, args.ownerAddress)

  self.events.on(SIGNAL_ENS_USERNAME_DETAILS_FETCHED) do(e:Args):
    let args = EnsUsernameDetailsArgs(e)
    self.delegate.onDetailsForEnsUsername(args.chainId, args.ensUsername, args.address, args.pubkey, args.isStatus, args.expirationTime)

  self.events.on(SIGNAL_ENS_TRANSACTION_SENT) do(e:Args):
    let args = EnsTxResultArgs(e)
    self.delegate.ensTransactionSent(args.transactionType, args.chainId, args.ensUsername, args.txHash, args.error)

  self.events.on(SIGNAL_ENS_TRANSACTION_CONFIRMED) do(e:Args):
    let args = EnsTransactionArgs(e)
    self.delegate.ensTransactionConfirmed(args.transactionType, args.ensUsername, args.txHash)

  self.events.on(SIGNAL_ENS_TRANSACTION_REVERTED) do(e:Args):
    let args = EnsTransactionArgs(e)
    self.delegate.ensTransactionReverted(args.transactionType, args.ensUsername, args.txHash)

proc getAppNetwork*(self: Controller): NetworkItem =
  return self.networkService.getAppNetwork()

proc checkEnsUsernameAvailability*(self: Controller, desiredEnsUsername: string, statusDomain: bool) =
  self.ensService.checkEnsUsernameAvailability(desiredEnsUsername, statusDomain)

proc getMyPendingEnsUsernames*(self: Controller): seq[EnsUsernameDto] =
  return self.ensService.getMyPendingEnsUsernames()

proc getAllMyEnsUsernames*(self: Controller, includePendingEnsUsernames: bool): seq[EnsUsernameDto] =
  return self.ensService.getAllMyEnsUsernames(includePendingEnsUsernames)

proc fetchDetailsForEnsUsername*(self: Controller, chainId: int, ensUsername: string) =
  self.ensService.fetchDetailsForEnsUsername(chainId, ensUsername)

proc addEnsUsername*(self: Controller, chainId: int, ensUsername: string): bool =
  return self.ensService.add(chainId, ensUsername)

proc removeEnsUsername*(self: Controller, chainId: int, ensUsername: string): bool =
  return self.ensService.remove(chainId, ensUsername)

proc getPreferredEnsUsername*(self: Controller): string =
  return self.settingsService.getPreferredName()

proc setPreferredName*(self: Controller, preferredName: string) =
  if(self.settingsService.savePreferredName(preferredName)):
    singletonInstance.userProfile.setPreferredName(preferredName)
  else:
    info "an error occurred saving prefered ens username", methodName="setPreferredName"

proc fixPreferredName*(self: Controller, ignoreCurrentValue: bool = false) =
  # TODO: Remove this workaround and make proper prefferedName-chainId database storage
  if (not ignoreCurrentValue and singletonInstance.userProfile.getPreferredName().len > 0):
    return
  let ensUsernames = self.getAllMyEnsUsernames(false)
  let currentChainId = self.getAppNetwork().chainId
  var firstEnsName = ""
  for ensUsername in ensUsernames:
    if ensUsername.chainId == currentChainId:
      firstEnsName = ensUsername.username
      break
  self.setPreferredName(firstEnsName)

proc getEnsRegisteredAddress*(self: Controller): string =
  return self.ensService.getEnsRegisteredAddress()

proc getWalletDefaultAddress*(self: Controller): string =
  return self.walletAccountService.getWalletAccount(0).address

proc getCurrentCurrency*(self: Controller): string =
  return self.settingsService.getCurrency()

proc getPriceForToken*(self: Controller, tokenKey: string): float64 =
  return self.tokenService.getPriceForToken(tokenKey)

proc ensnameResolverAddress*(self: Controller, ensUsername: string): string =
  return self.ensService.ensnameResolverAddress(ensUsername)
