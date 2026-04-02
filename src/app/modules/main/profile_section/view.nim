import nimqml

import ./io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.delegate = delegate
    result.setup()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc getContactsModule(self: View): QVariant {.slot.} =
    return self.delegate.getContactsModule()
  QtProperty[QVariant] contactsModule:
    read = getContactsModule

  proc getProfileModule(self: View): QVariant {.slot.} =
    return self.delegate.getProfileModule()
  QtProperty[QVariant] profileModule:
    read = getProfileModule

  proc getAdvancedModule(self: View): QVariant {.slot.} =
    return self.delegate.getAdvancedModule()
  QtProperty[QVariant] advancedModule:
    read = getAdvancedModule

  proc getDevicesModule(self: View): QVariant {.slot.} =
    return self.delegate.getDevicesModule()
  QtProperty[QVariant] devicesModule:
    read = getDevicesModule

  proc getSyncModule(self: View): QVariant {.slot.} =
    return self.delegate.getSyncModule()
  QtProperty[QVariant] syncModule:
    read = getSyncModule

  proc getWakuModule(self: View): QVariant {.slot.} =
    return self.delegate.getWakuModule()
  QtProperty[QVariant] wakuModule:
    read = getWakuModule

  proc getNotificationsModule(self: View): QVariant {.slot.} =
    return self.delegate.getNotificationsModule()
  QtProperty[QVariant] notificationsModule:
    read = getNotificationsModule

  proc getPrivacyModule(self: View): QVariant {.slot.} =
    return self.delegate.getPrivacyModule()
  QtProperty[QVariant] privacyModule:
    read = getPrivacyModule

  proc getEnsUsernamesModule(self: View): QVariant {.slot.} =
    return self.delegate.getEnsUsernamesModule()
  QtProperty[QVariant] ensUsernamesModule:
    read = getEnsUsernamesModule

  proc getCommunitiesModule(self: View): QVariant {.slot.} =
    return self.delegate.getCommunitiesModule()
  QtProperty[QVariant] communitiesModule:
    read = getCommunitiesModule

  proc getKeycardModule(self: View): QVariant {.slot.} =
    return self.delegate.getKeycardModule()
  QtProperty[QVariant] keycardModule:
    read = getKeycardModule

  proc getKeycardNewModule(self: View): QVariant {.slot.} =
    return self.delegate.getKeycardNewModule()
  QtProperty[QVariant] keycardNewModule:
    read = getKeycardNewModule

  proc getWalletModule(self: View): QVariant {.slot.} =
    return self.delegate.getWalletModule()
  QtProperty[QVariant] walletModule:
    read = getWalletModule

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

