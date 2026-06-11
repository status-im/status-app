import times, chronicles
import uuids
import io_interface

import app/core/eventemitter
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/devices/service as devices_service

import app/modules/shared_models/[keypair_item]

logScope:
  topics = "wallet-keycard-import-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    devicesService: devices_service.Service
    connectionIds: seq[UUID]
    uniqueFetchingDetailsId: string
    tmpPrivateKey: string
    tmpSeedPhrase: string
    tmpGeneratedAccount: GeneratedAccountDto

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  devicesService: devices_service.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.devicesService = devicesService

proc disconnectAll*(self: Controller) =
  for id in self.connectionIds:
    self.events.disconnect(id)

proc delete*(self: Controller) =
  self.disconnectAll()

proc init*(self: Controller) =

  var handlerId = self.events.onWithUUID(SIGNAL_WALLET_ACCOUNT_ADDRESS_DETAILS_FETCHED) do(e:Args):
    var args = DerivedAddressesArgs(e)
    if args.uniqueId != self.uniqueFetchingDetailsId:
      return
    self.delegate.onAddressDetailsFetched(args.derivedAddresses, args.error)
  self.connectionIds.add(handlerId)

proc closeKeypairImportPopup*(self: Controller) =
  self.delegate.closeKeypairImportPopup()

proc setPrivateKey*(self: Controller, value: string) =
  self.tmpPrivateKey = value

proc getPrivateKey*(self: Controller): string =
  return self.tmpPrivateKey

proc setSeedPhrase*(self: Controller, value: string) =
  self.tmpSeedPhrase = value

proc getSeedPhrase*(self: Controller): string =
  return self.tmpSeedPhrase

proc authenticateLoggedInUser*(self: Controller) =
  self.delegate.onAuthenticationRequest()

proc getKeypairByKeyUid*(self: Controller, keyUid: string): KeypairDto =
  return self.walletAccountService.getKeypairByKeyUid(keyUid)

proc createAccountFromPrivateKey*(self: Controller, privateKey: string): GeneratedAccountDto =
  self.setPrivateKey(privateKey)
  self.tmpGeneratedAccount = self.accountsService.createAccountFromPrivateKey(privateKey)
  return self.tmpGeneratedAccount

proc createAccountFromSeedPhrase*(self: Controller, seedPhrase: string): GeneratedAccountDto =
  self.setSeedPhrase(seedPhrase)
  self.tmpGeneratedAccount = self.accountsService.createAccountFromMnemonic(seedPhrase)
  return self.tmpGeneratedAccount

proc getGeneratedAccount*(self: Controller): GeneratedAccountDto =
  return self.tmpGeneratedAccount

proc fetchDetailsForAddresses*(self: Controller, addresses: seq[string]) =
  self.uniqueFetchingDetailsId = $now().toTime().toUnix()
  self.walletAccountService.fetchDetailsForAddresses(self.uniqueFetchingDetailsId, addresses)

proc makePrivateKeyKeypairFullyOperable*(self: Controller, keyUid, privateKey, password: string, doPasswordHashing: bool): string =
  return self.walletAccountService.makePrivateKeyKeypairFullyOperable(keyUid, privateKey, password, doPasswordHashing)

proc makeSeedPhraseKeypairFullyOperable*(self: Controller, keyUid, mnemonic, password: string, doPasswordHashing: bool): string =
  return self.walletAccountService.makeSeedPhraseKeypairFullyOperable(keyUid, mnemonic, password, doPasswordHashing)

proc getKeypairs*(self: Controller): seq[wallet_account_service.KeypairDto] =
  return self.walletAccountService.getKeypairs()

proc getSelectedKeypair*(self: Controller): KeyPairItem =
  return self.delegate.getSelectedKeypair()

proc clearSelectedKeypair*(self: Controller) =
  self.delegate.clearSelectedKeypair()

proc setConnectionString*(self: Controller, connectionString: string) =
  self.delegate.setConnectionString(connectionString)

proc generateConnectionStringForExportingKeypairsKeystores*(self: Controller, keyUids: seq[string], password: string): tuple[res: string, err: string] =
  return self.devicesService.generateConnectionStringForExportingKeypairsKeystores(keyUids, password)

proc validateConnectionString*(self: Controller, connectionString: string): string =
  return self.devicesService.validateConnectionString(connectionString)

proc inputConnectionStringForImportingKeypairsKeystores*(self: Controller, keyUids: seq[string], connectionString: string, password: string): string =
  return self.devicesService.inputConnectionStringForImportingKeypairsKeystores(keyUids, connectionString, password)