import chronicles
import io_interface

import app/core/eventemitter
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/transaction/service as transaction_service
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/common/utils as common_utils
import app/modules/shared/keypairs

logScope:
  topics = "signing-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    transactionService: transaction_service.Service
    keycardServiceV2: keycard_serviceV2.Service

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  transactionService: transaction_service.Service,
  keycardServiceV2: keycard_serviceV2.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.transactionService = transactionService
  result.keycardServiceV2 = keycardServiceV2

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_KEYCARD_STATE_UPDATED) do(e: Args):
    let args = KeycardEventArg(e)
    self.delegate.onKeycardStateUpdated(args.keycardEvent)

  self.events.on(SIGNAL_KEYCARD_SIGN_FINISHED) do(e: Args):
    let args = KeycardSignArgs(e)
    self.delegate.onKeycardSignFinished(args.signature, args.error)

proc verifyPassword*(self: Controller, password: string): bool =
  return self.accountsService.verifyPassword(password)

proc signMessage*(self: Controller, address: string, password: string, txHash: string): tuple[res: string, err: string] =
  let hashedPassword = common_utils.hashPassword(password)
  return self.transactionService.signMessage(address, hashedPassword, txHash)

proc startKeycardSigning*(self: Controller, keyUid: string, pin: string, txHash: string, path: string) =
  self.keycardServiceV2.asyncSign(keyUid, pin, txHash, path)

proc stopKeycardSigning*(self: Controller) =
  self.keycardServiceV2.asyncStop()

proc isKeypairMigratedToKeycard*(self: Controller, keyUid: string): bool =
  let keypair = self.walletAccountService.getKeypairByKeyUid(keyUid)
  if keypair.isNil:
    return false
  return keypair.migratedToKeycard()

proc buildKeyPairForProcessing*(self: Controller, keyUid: string): KeyPairItem =
  let keypair = self.walletAccountService.getKeypairByKeyUid(keyUid)
  if keypair.isNil:
    return nil
  return buildKeypairItem(keypair, areTestNetworksEnabled = false)
