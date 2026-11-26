import QtQuick
import utils

QtObject {
    id: root

    property var privacyModule

    // Module Properties
    readonly property bool mnemonicBackedUp: privacyModule.mnemonicBackedUp
    readonly property string keyUid: userProfile.keyUid
    readonly property bool migratedToColdWallet: userProfile.migratedToColdWallet
    // Created by the app without a password, until the user sets one
    readonly property bool zeroOnboarded: userProfile.zeroOnboarded
    readonly property bool passwordChangeAvailable: !root.migratedToColdWallet && !root.zeroOnboarded
    readonly property bool signOutAvailable: !root.zeroOnboarded

    signal profilePasswordSet(bool success, string errorMsg)

    readonly property Connections privacyModuleConnections: Connections {
        target: root.privacyModule
        function onProfilePasswordSet(success: bool, errorMsg: string) {
            root.profilePasswordSet(success, errorMsg)
        }
    }

    function setProfilePassword(newPassword) {
        root.privacyModule.setProfilePassword(newPassword)
    }

    readonly property var appSettingsInst: appSettings

    // The following properties wrap Privacy and Security View related properties:
    readonly property bool isStatusNewsViaRSSEnabled: appSettingsInst.newsRSSEnabled

    function setNewsRSSEnabled(isStatusNewsViaRSSEnabled) {
        appSettingsInst.newsRSSEnabled = isStatusNewsViaRSSEnabled
    }

    function changePassword(password, newPassword, rekey = false) {
        root.privacyModule.changePassword(password, newPassword, rekey)
    }

    function isProfileMigratedToDEKEncryption() {
        return root.privacyModule.isProfileMigratedToDEKEncryption()
    }

    function getBiometricCredentialForStorage(keyUid, password) {
        return root.privacyModule.getBiometricCredentialForStorage(keyUid, password)
    }

    function setBiometricPreferenceNotNow() {
        root.privacyModule.setBiometricPreferenceNotNow()
    }

    // "Stay logged in" — per-account preference + DEK-only credential conversion
    readonly property bool stayLoggedIn: localAccountSettings.stayLoggedIn

    function setStayLoggedIn(value) {
        localAccountSettings.stayLoggedIn = value
    }

    function setAutoLoginSuppressed(keyUid, value) {
        return localAppSettings.setAutoLoginSuppressed(keyUid, value)
    }

    function getStayLoggedInCredentialForStorage(keyUid, password) {
        return root.privacyModule.getStayLoggedInCredentialForStorage(keyUid, password)
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
