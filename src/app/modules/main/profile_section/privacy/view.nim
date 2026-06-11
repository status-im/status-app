import nimqml

import ./io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc changePassword*(self: View, password: string, newPassword: string) {.slot.} =
    self.delegate.changePassword(password, newPassword)

  proc passwordChanged(self: View, success: bool, errorMsg: string) {.signal.}
  proc emitPasswordChangedSignal*(self: View, success: bool, errorMsg: string) =
    self.passwordChanged(success, errorMsg)

  proc mnemonicBackedUpChanged(self: View) {.signal.}
  proc isMnemonicBackedUp(self: View): bool {.slot.} =
    return self.delegate.isMnemonicBackedUp()
  QtProperty[bool] mnemonicBackedUp:
    read = isMnemonicBackedUp
    notify = mnemonicBackedUpChanged

  proc emitMnemonicBackedUpSignal*(self: View) =
    self.mnemonicBackedUpChanged()

  proc getMnemonic*(self: View): string {.slot.} =
    return self.delegate.getMnemonic()

  proc removeMnemonic*(self: View) {.slot.} =
    self.delegate.removeMnemonic()

  proc mnemonicWasShown*(self: View) {.slot.} =
    self.delegate.mnemonicWasShown()

  proc messagesFromContactsOnlyChanged*(self: View) {.signal.}
  proc getMessagesFromContactsOnly(self: View): bool {.slot.} =
    return self.delegate.getMessagesFromContactsOnly()
  proc setMessagesFromContactsOnly(self: View, value: bool) {.slot.} =
    if self.getMessagesFromContactsOnly() == value:
      return
    self.delegate.setMessagesFromContactsOnly(value)
    self.messagesFromContactsOnlyChanged()
  QtProperty[bool] messagesFromContactsOnly:
    read = getMessagesFromContactsOnly
    write = setMessagesFromContactsOnly
    notify = messagesFromContactsOnlyChanged

  proc syncingOnMobileNetworkChanged*(self: View) {.signal.}
  proc getSyncingOnMobileNetwork(self: View): bool {.slot.} =
    return self.delegate.getSyncingOnMobileNetwork()
  proc setSyncingOnMobileNetwork(self: View, value: bool) {.slot.} =
    if self.getSyncingOnMobileNetwork() == value:
      return
    self.delegate.setSyncingOnMobileNetwork(value)
    self.syncingOnMobileNetworkChanged()
  QtProperty[bool] syncingOnMobileNetwork:
    read = getSyncingOnMobileNetwork
    write = setSyncingOnMobileNetwork
    notify = syncingOnMobileNetworkChanged

  proc urlUnfurlingModeChanged(self: View) {.signal.}
  proc getUrlUnfurlingMode(self: View): int {.slot.} =
    return self.delegate.urlUnfurlingMode()
  proc setUrlUnfurlingMode(self: View, value: int) {.slot.} =
    if self.getUrlUnfurlingMode() == value:
      return
    self.delegate.setUrlUnfurlingMode(value)

  QtProperty[int] urlUnfurlingMode:
    read = getUrlUnfurlingMode
    write = setUrlUnfurlingMode
    notify = urlUnfurlingModeChanged

  proc getPasswordStrengthScore*(self: View, password: string): int {.slot.} =
    return self.delegate.getPasswordStrengthScore(password)

  proc emitUrlUnfurlingModeUpdated*(self: View, mode: int) =
    self.urlUnfurlingModeChanged()

  proc delete*(self: View) =
    self.QObject.delete

