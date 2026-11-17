import QtQuick

QtObject {
    readonly property string contextPropertyName: "localAccountSettings"

    property string storeToKeychainValue: "notNow"
    property bool freshProfile: false
    property bool stayLoggedIn: false

    property bool spellCheckEnabled: true
    property bool spellCheckSkipCapitalizedWords: true
}
