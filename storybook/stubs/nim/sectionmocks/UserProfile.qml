// Mock of shared/userProfile context property for Storybook
import QtQuick

QtObject {
    readonly property string contextPropertyName: "userProfile"

    property string pubKey: "0xdeadbeef"
    property string keyUid: "0xprofilekeyuid"
    property bool usingBiometricLogin: false
    property bool migratedToColdWallet: false
}
