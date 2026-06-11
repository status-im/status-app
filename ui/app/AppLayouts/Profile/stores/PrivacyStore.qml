import QtQuick
import utils

QtObject {
    id: root

    property var privacyModule

    // Module Properties
    readonly property bool mnemonicBackedUp: privacyModule.mnemonicBackedUp
    readonly property string keyUid: userProfile.keyUid

    readonly property var appSettingsInst: appSettings

    // The following properties wrap Privacy and Security View related properties:
    readonly property bool isStatusNewsViaRSSEnabled: appSettingsInst.newsRSSEnabled

    function setNewsRSSEnabled(isStatusNewsViaRSSEnabled) {
        appSettingsInst.newsRSSEnabled = isStatusNewsViaRSSEnabled
    }

    function changePassword(password, newPassword) {
        root.privacyModule.changePassword(password, newPassword)
    }

    function getMnemonic() {
        return root.privacyModule.getMnemonic()
    }

    function removeMnemonic() {
        root.privacyModule.removeMnemonic()
    }

    function validatePassword(password) {
        return root.privacyModule.validatePassword(password)
    }

    function mnemonicWasShown() {
        root.privacyModule.mnemonicWasShown()
    }

    readonly property bool thirdpartyServicesEnabled: appSettingsInst.thirdpartyServicesEnabled
    function toggleThirdpartyServicesEnabledRequested() {
        appSettingsInst.thirdpartyServicesEnabled = !appSettingsInst.thirdpartyServicesEnabled
        Global.displaySuccessToastMessage(appSettingsInst.thirdpartyServicesEnabled ?
                                          qsTr("Third-party services successfully enabled"):
                                          qsTr("Third-party services successfully disabled"))
    }
}
