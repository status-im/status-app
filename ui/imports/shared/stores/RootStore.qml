import QtQuick
import utils

QtObject {
    id: root

    readonly property GifStore gifStore: GifStore {}

    property var profileSectionModuleInst: profileSectionModule
    property var privacyModule: profileSectionModuleInst.privacyModule
    property var appSettingsInst: Global.appIsReady && !!appSettings? appSettings : null
    property var accountSettings: Global.appIsReady && !!localAccountSettings? localAccountSettings : null

    readonly property bool neverAskAboutUnfurlingAgain: !!accountSettings ? accountSettings.neverAskAboutUnfurlingAgain : false
    readonly property bool gifUnfurlingEnabled: !!accountSettings ? accountSettings.gifUnfurlingEnabled : false

    required property CurrenciesStore currencyStore

    function setNeverAskAboutUnfurlingAgain(value) {
        localAccountSettings.neverAskAboutUnfurlingAgain = value;
    }

    function getPasswordStrengthScore(password) {
        return root.privacyModule.getPasswordStrengthScore(password)
    }
}
