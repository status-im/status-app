import times, chronicles
import uuids
import io_interface

import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/saved_address/service as saved_address_service

import app/core/eventemitter

logScope:
  topics = "wallet-add-account-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    savedAddressService: saved_address_service.Service
    connectionIds: seq[UUID]
    tmpAuthenticatedKeyUid: string
    tmpPin: string
    tmpPassword: string
    tmpSeedPhrase: string
    tmpGeneratedAccount: GeneratedAccountDto
    uniqueFetchingDetailsId: string

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  savedAddressService: saved_address_service.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.savedAddressService = savedAddressService

proc disconnectAll*(self: Controller) =
  for id in self.connectionIds:
    self.events.disconnect(id)

proc delete*(self: Controller) =
  self.disconnectAll()

proc init*(self: Controller) =

  var handlerId = self.events.onWithUUID(SIGNAL_WALLET_ACCOUNT_DERIVED_ADDRESSES_FETCHED) do(e:Args):
    let args = DerivedAddressesArgs(e)
    self.delegate.onDerivedAddressesFetched(args.derivedAddresses, args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_WALLET_ACCOUNT_DERIVED_ADDRESSES_FROM_MNEMONIC_FETCHED) do(e:Args):
    let args = DerivedAddressesArgs(e)
    self.delegate.onDerivedAddressesFromMnemonicFetched(args.derivedAddresses, args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_DERIVED_ADDRESSES_FROM_NOT_IMPORTED_MNEMONIC_FETCHED) do(e:Args):
    let args = DerivedAddressesFromNotImportedMnemonicArgs(e)
    self.delegate.onAddressesFromNotImportedMnemonicFetched(args.derivations, args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_WALLET_ACCOUNT_ADDRESS_DETAILS_FETCHED) do(e:Args):
    let args = DerivedAddressesArgs(e)
    if args.uniqueId != self.uniqueFetchingDetailsId:
      return
    self.delegate.updateDerivedAddresses(args.derivedAddresses, args.error, true)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_WALLET_ACCOUNT_ADDRESS_ALREADY_ADDED_FETCHED) do(e:Args):
    let args = DerivedAddressesArgs(e)
    self.delegate.updateDerivedAddresses(args.derivedAddresses, args.error, false)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_SAVED_ADDRESS_DELETED) do(e:Args):
    let args = SavedAddressArgs(e)
    self.delegate.savedAddressDeleted(args.address, args.errorMsg)
  self.connectionIds.add(handlerId)

proc setAuthenticatedKeyUid*(self: Controller, value: string) =
  self.tmpAuthenticatedKeyUid = value

proc getAuthenticatedKeyUid*(self: Controller): string =
  return self.tmpAuthenticatedKeyUid

proc setPin*(self: Controller, value: string) =
  self.tmpPin = value

proc getPin*(self: Controller): string =
  return self.tmpPin

proc setPassword*(self: Controller, value: string) =
  self.tmpPassword = value

proc getPassword*(self: Controller): string =
  return self.tmpPassword

proc setSeedPhrase*(self: Controller, value: string) =
  self.tmpSeedPhrase = value

proc getSeedPhrase*(self: Controller): string =
  return self.tmpSeedPhrase

proc closeAddAccountPopup*(self: Controller) =
  self.delegate.closeAddAccountPopup()

proc getWalletAccount*(self: Controller, address: string): WalletAccountDto =
  return self.walletAccountService.getAccountByAddress(address)

proc getKeypairs*(self: Controller): seq[KeypairDto] =
  return self.walletAccountService.getKeypairs()

proc getKeypairByKeyUid*(self: Controller, keyUid: string): KeypairDto =
  return self.walletAccountService.getKeypairByKeyUid(keyUid)

proc getSavedAddress*(self: Controller, address: string): SavedAddressDto =
  return self.savedAddressService.getSavedAddress(address)

proc deleteSavedAddress*(self: Controller, address: string) =
  self.savedAddressService.deleteSavedAddress(address)

proc finalizeAction*(self: Controller) =
  self.delegate.finalizeAction()

proc authenticateOrigin*(self: Controller, keyUid = "") =
  discard

proc fetchDerivedAddresses*(self: Controller, derivedFrom: string, paths: seq[string])=
  var hashPassword = true
  if self.getPin().len > 0:
    hashPassword = false
  self.walletAccountService.fetchDerivedAddresses(self.getPassword(), derivedFrom, paths, hashPassword)

proc getRandomMnemonic*(self: Controller): string =
  return self.walletAccountService.getRandomMnemonic()

proc fetchDetailsForAddresses*(self: Controller, addresses: seq[string]) =
  self.uniqueFetchingDetailsId = $now().toTime().toUnix()
  self.walletAccountService.fetchDetailsForAddresses(self.uniqueFetchingDetailsId, addresses)

proc addWalletAccount*(self: Controller, createKeystoreFile, doPasswordHashing: bool, name, address, path, publicKey,
  keyUid, accountType, colorId, emoji: string, hideFromTotalBalance: bool): bool =
  var password: string
  if createKeystoreFile:
    password = self.getPassword()
    if password.len == 0:
      info "cannot create keystore file if provided password is empty", name=name, address=address
      return false
  let err = self.walletAccountService.addWalletAccount(password, doPasswordHashing, name, address, path, publicKey,
    keyUid, accountType, colorId, emoji, hideFromTotalBalance)
  if err.len > 0:
    info "adding wallet account failed", name=name, address=address
    return false
  return true

proc addNewPrivateKeyKeypair*(self: Controller, privateKey: string, doPasswordHashing: bool,
  keypairName: string, accountCreationDetails: AccountCreationDetails): bool =
  let password = self.getPassword() # password must not be empty in this context
  if password.len == 0:
    info "cannot create keystore file if provided password is empty", keypairName=keypairName
    return false
  let err = self.walletAccountService.addNewPrivateKeyKeypair(privateKey, password, doPasswordHashing, keypairName,
    accountCreationDetails)
  if err.len > 0:
    info "adding new keypair from private key failed", keypairName=keypairName
    return false
  return true

proc addNewSeedPhraseKeypair*(self: Controller, seedPhrase: string, doPasswordHashing: bool, keypairName: string,
  accountCreationDetails: AccountCreationDetails): bool =
  let password = self.getPassword() # password must not be empty in this context
  if password.len == 0:
    info "cannot create keystore file if provided password is empty", keypairName=keypairName
    return false
  let err = self.walletAccountService.addNewSeedPhraseKeypair(seedPhrase, password, doPasswordHashing, keypairName,
    coldWallet = wallet_account_service.ColdWalletTypeNoNone, accountCreationDetails)
  if err.len > 0:
    info "adding new keypair from seed phrase failed", keypairName=keypairName
    return false
  return true

proc updateAccount*(self: Controller, address: string, accountName: string, colorId: string, emoji: string): bool =
  return self.walletAccountService.updateWalletAccount(address, accountName, colorId, emoji)

proc getKeyUidForSeedPhrase*(self: Controller, seedPhrase: string): string =
  let acc = self.accountsService.createAccountFromMnemonic(seedPhrase)
  return acc.keyUid

proc createAccountFromSeedPhrase*(self: Controller, seedPhrase: string): GeneratedAccountDto =
  self.setSeedPhrase(seedPhrase)
  self.tmpGeneratedAccount = self.accountsService.createAccountFromMnemonic(seedPhrase)
  return self.tmpGeneratedAccount

proc fetchAddressesFromNotImportedSeedPhrase*(self: Controller, seedPhrase: string, paths: seq[string] = @[]) =
  self.accountsService.fetchAddressesFromNotImportedMnemonic(seedPhrase, paths)

proc createAccountFromPrivateKey*(self: Controller, privateKey: string): GeneratedAccountDto =
  self.tmpGeneratedAccount = self.accountsService.createAccountFromPrivateKey(privateKey)
  return self.tmpGeneratedAccount

proc getGeneratedAccount*(self: Controller): GeneratedAccountDto =
  return self.tmpGeneratedAccount

proc buildNewPrivateKeyKeypairAndAddItToOrigin*(self: Controller) =
  self.delegate.buildNewPrivateKeyKeypairAndAddItToOrigin()

proc buildNewSeedPhraseKeypairAndAddItToOrigin*(self: Controller) =
  self.delegate.buildNewSeedPhraseKeypairAndAddItToOrigin()

proc fetchAddressesFromKeycard*(self: Controller, bip44Paths: seq[string]) =
  discard

proc getNumOfAddressesToGenerateForKeypair*(self: Controller, keyUid: string): int =
  return self.walletAccountService.getNumOfAddressesToGenerateForKeypair(keyUid)

proc resolveSuggestedPathForKeypair*(self: Controller, keyUid: string): string =
  return self.walletAccountService.resolveSuggestedPathForKeypair(keyUid)

proc isChecksumValidForAddress*(self: Controller, address: string): bool =
  return self.walletAccountService.isChecksumValidForAddress(address)

proc remainingAccountCapacity*(self: Controller): int =
  return self.walletAccountService.remainingAccountCapacity()

proc remainingKeypairCapacity*(self: Controller): int =
  return self.walletAccountService.remainingKeypairCapacity()

proc remainingWatchOnlyAccountCapacity*(self: Controller): int =
  return self.walletAccountService.remainingWatchOnlyAccountCapacity()
