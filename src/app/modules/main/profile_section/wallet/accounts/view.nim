import nimqml, sequtils, strutils

import ./io_interface
import ./model
import app/modules/shared_models/keypair_model
import app/modules/shared_models/keypair_item
import app/modules/shared_models/keypair_account_item
import app/modules/shared_models/wallet_account_item
import app/modules/shared_models/currency_amount

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      accounts: Model
      accountsVariant: QVariant
      keyPairModel: KeyPairModel
      selectedKeyPair: KeyPairItem
      selectedAccount: KeyPairAccountItem

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.accounts = newModel()
    result.accountsVariant = newQVariant(result.accounts)
    result.keyPairModel = newKeyPairModel()

  proc getSelectedKeyPair*(self: View): QVariant {.slot.} =
    if self.selectedKeyPair.isNil:
      return newQVariant()
    return newQVariant(self.selectedKeyPair)

  proc selectedKeyPairChanged(self: View) {.signal.}

  QtProperty[QVariant] selectedKeyPair:
    read = getSelectedKeyPair
    notify = selectedKeyPairChanged

  proc getSelectedAccount*(self: View): QVariant {.slot.} =
    if self.selectedAccount.isNil:
      return newQVariant()
    return newQVariant(self.selectedAccount)

  proc selectedAccountChanged(self: View) {.signal.}

  QtProperty[QVariant] selectedAccount:
    read = getSelectedAccount
    notify = selectedAccountChanged

  proc setSelectedAccount*(self: View, address: string) {.slot.} =
    let (selectedKeyPair, selectedAccount) = self.keyPairModel.findKeyPairAndAccountByAddresss(address)
    self.selectedKeyPair = selectedKeyPair
    self.selectedAccount = selectedAccount
    self.selectedKeyPairChanged()
    self.selectedAccountChanged()

  proc refreshSelectedAccount(self: View) =
    if self.selectedAccount.isNil:
      return
    self.setSelectedAccount(self.selectedAccount.getAddress())

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc accountsChanged*(self: View) {.signal.}

  proc getAccounts(self: View): QVariant {.slot.} =
    return self.accountsVariant

  QtProperty[QVariant] accounts:
    read = getAccounts
    notify = accountsChanged

  proc setItems*(self: View, items: seq[WalletAccountItem]) =
    self.accounts.setItems(items)

  proc updateAccount(self: View, address: string, accountName: string, colorId: string, emoji: string) {.slot.} =
    self.delegate.updateAccount(address, accountName, colorId, emoji)

  proc onUpdatedAccount*(self: View, account: WalletAccountItem) =
    self.accounts.onUpdatedAccount(account)
    self.keyPairModel.onUpdatedAccount(account.keyUid, account.address, account.name, account.colorId, account.emoji)
    self.refreshSelectedAccount()

  proc onUpdatedKeypairOperability*(self: View, keyUid, operability: string) =
    self.keyPairModel.onUpdatedKeypairOperability(keyUid, operability)
    self.refreshSelectedAccount()

  proc onHideFromTotalBalanceUpdated*(self: View, keyUid, address: string, hideFromTotalBalance: bool) =
    self.keyPairModel.onHideFromTotalBalanceUpdated(keyUid, address, hideFromTotalBalance)
    self.refreshSelectedAccount()

  proc deleteAccount*(self: View, address: string, password: string) {.slot.} =
    self.delegate.deleteAccount(address, password)

  proc deleteKeypair*(self: View, keyUid: string, password: string) {.slot.} =
    self.delegate.deleteKeypair(keyUid, password)

  proc keyPairModel*(self: View): KeyPairModel =
    return self.keyPairModel

  proc keyPairModelChanged*(self: View) {.signal.}
  proc getKeyPairModel(self: View): QAbstractListModel {.slot.} =
    return self.keyPairModel
  QtProperty[QAbstractListModel] keyPairModel:
    read = getKeyPairModel
    notify = keyPairModelChanged

  proc setKeyPairModelItems*(self: View, items: seq[KeyPairItem]) =
    self.keyPairModel.setItems(items)
    self.keyPairModelChanged()
    self.refreshSelectedAccount()

  proc keypairNameExists*(self: View, name: string): bool {.slot.} =
    return self.keyPairModel.keypairNameExists(name)

  proc renameKeypair*(self: View, keyUid: string, name: string) {.slot.} =
    self.delegate.renameKeypair(keyUid, name)

  proc moveAccount(self: View, fromRow: int, toRow: int) {.slot.} =
    discard self.accounts.moveItem(fromRow, toRow)

  proc moveAccountFinally(self: View, fromRow: int, toRow: int) {.slot.} =
    self.delegate.moveAccountFinally(fromRow, toRow)

  proc setBalanceForKeyPairs*(self: View, address: string, balance: CurrencyAmount) =
    self.keyPairModel.setBalanceForAddress(address, balance)
    self.refreshSelectedAccount()

  proc updateWatchAccountHiddenFromTotalBalance*(self: View, address: string, hideFromTotalBalance: bool) {.slot.} =
    self.delegate.updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance)

  proc delete*(self: View) =
    self.QObject.delete

