import chronicles
import io_interface

import app/core/eventemitter
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/keycardV2/service as keycard_serviceV2
import app/modules/shared/keypairs

logScope:
  topics = "authentication-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    keycardServiceV2: keycard_serviceV2.Service

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  keycardServiceV2: keycard_serviceV2.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.keycardServiceV2 = keycardServiceV2

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_KEYCARD_STATE_UPDATED) do(e: Args):
    let args = KeycardEventArg(e)
    self.delegate.onKeycardStateUpdated(args.keycardEvent)

  self.events.on(SIGNAL_KEYCARD_EXPORT_PUBLIC_KEYS_FINISHED) do(e: Args):
    let args = KeycardExportedPublicKeysArgs(e)
    self.delegate.onKeycardExportPublicKeysFinished(args.exportedPublicKeys, args.error)

proc verifyPassword*(self: Controller, password: string): bool =
  return self.accountsService.verifyPassword(password)

proc startKeycardAuthentication*(self: Controller, keyUid: string, paths: seq[string], exportPrivate: bool,
  exportMasterAddr: bool, pin: string) =
  self.keycardServiceV2.asyncExportPublicKey(keyUid, paths, exportPrivate, exportMasterAddr, pin)

proc stopKeycardAuthentication*(self: Controller) =
  self.keycardServiceV2.stop()

proc isKeypairMigratedToColdWallet*(self: Controller, keyUid: string): bool =
  let keypair = self.walletAccountService.getKeypairByKeyUid(keyUid)
  if keypair.isNil:
    return false
  return keypair.migratedToColdWallet()

proc buildKeyPairForProcessing*(self: Controller, keyUid: string): KeyPairItem =
  let keypair = self.walletAccountService.getKeypairByKeyUid(keyUid)
  if keypair.isNil:
    return nil
  return buildKeypairItem(keypair, areTestNetworksEnabled = false)