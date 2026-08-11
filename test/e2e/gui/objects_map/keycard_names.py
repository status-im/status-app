from objectmaphelper import *

from gui.objects_map.names import statusDesktop_mainWindow, statusDesktop_mainWindow_overlay

# Simulator (KeycardSimulatorController.qml)

keycardSimulatorWindow = {"title": "Keycard Simulator Controller", "type": "QQuickApplicationWindow", "visible": True}
keycardSimStartButton = {"container": keycardSimulatorWindow, "objectName": "keycardSimStartButton",
                         "type": "StatusButton"}
keycardSimCreateEmptyButton = {"container": keycardSimulatorWindow, "objectName": "keycardSimCreateEmptyButton",
                               "type": "StatusButton"}
keycardSimPlugReaderButton = {"container": keycardSimulatorWindow, "objectName": "keycardSimPlugReaderButton",
                              "type": "StatusButton"}
keycardSimInsertButton = {"container": keycardSimulatorWindow, "objectName": "keycardSimInsertButton",
                          "type": "StatusButton"}
keycardSimRemoveButton = {"container": keycardSimulatorWindow, "objectName": "keycardSimRemoveButton",
                          "type": "StatusButton"}
keycardSimCardId = {"container": keycardSimulatorWindow, "objectName": "keycardSimCardId", "type": "TextField"}
keycardSimCardSelector = {"container": keycardSimulatorWindow, "objectName": "keycardSimCardSelector",
                          "type": "ComboBox"}

# Settings → Keycard

mainWindow_KeycardView = {"container": statusDesktop_mainWindow, "objectName": "settings_KeycardView",
                          "type": "KeycardViewNew", "visible": True}
settings_Keycard_ReadKeycardButton = {"container": mainWindow_KeycardView,
                                      "objectName": "settings_Keycard_ReadKeycardButton", "type": "StatusButton",
                                      "visible": True}
keycardSettingsDetailsTitle = {"container": mainWindow_KeycardView,
                               "objectName": "settingsContentBaseSectionTitle", "type": "StatusBaseText",
                               "visible": True}
keycardSettingsKeyPairInfo = {"container": mainWindow_KeycardView, "objectName": "keyPairItemInfo",
                              "type": "StatusListItem", "visible": True}

# Keycard management popup

keycardManagementPopup = {"container": statusDesktop_mainWindow_overlay, "objectName": "KeycardManagementPopup",
                          "type": "PopupItem", "visible": True}
keycardManagementPinInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "keycardManagementPinInput",
                             "type": "StatusPinInput", "visible": True}
keycardManagementRevealSeedPhraseButton = {"container": statusDesktop_mainWindow_overlay,
                                           "objectName": "AddAccountPopup-RevealSeedPhrase", "type": "StatusButton",
                                           "visible": True}
keycardManagementNextButton = {"container": statusDesktop_mainWindow_overlay,
                               "objectName": "keycardManagementNextButton", "type": "StatusButton", "visible": True}
keycardManagementSeedPhraseWord = {
    "container": statusDesktop_mainWindow_overlay,
    "objectName": RegularExpression("SeedPhraseWordAtIndex-*"),
    "type": "StatusSeedPhraseInput",
    "visible": True,
}
keycardManagementContinueButton = {"container": statusDesktop_mainWindow_overlay,
                                   "objectName": "keycardManagementContinueButton", "type": "StatusButton",
                                   "visible": True}
keycardManagementSeedPhraseSwitchBar = {"container": statusDesktop_mainWindow_overlay,
                                        "objectName": "enterSeedPhraseSwitchBar",
                                        "type": "StatusSeedPhraseTabBar", "visible": True}
keycardManagementSeedPhrase12Button = {"container": keycardManagementSeedPhraseSwitchBar,
                                       "objectName": "12SeedButton", "type": "StatusSwitchTabButton"}
keycardManagementSeedPhrase18Button = {"container": keycardManagementSeedPhraseSwitchBar,
                                       "objectName": "18SeedButton", "type": "StatusSwitchTabButton"}
keycardManagementSeedPhrase24Button = {"container": keycardManagementSeedPhraseSwitchBar,
                                       "objectName": "24SeedButton", "type": "StatusSwitchTabButton"}
keycardManagementSeedPhraseInputField = {"container": statusDesktop_mainWindow_overlay,
                                         "objectName": "enterSeedPhraseInputField", "type": "TextField",
                                         "visible": True}
