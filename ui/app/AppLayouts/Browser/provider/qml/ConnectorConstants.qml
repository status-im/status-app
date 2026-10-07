pragma Singleton

import QtQuick

QtObject {
    readonly property string baseClientId: "status-desktop/dapp-browser"
    readonly property string ephemeralClientIdSuffix: "#ephemeral"
    readonly property string insufficientNetworkFeeMessage: qsTr("Not enough funds on this network to pay the network fee.")

    function isEphemeralClientId(id) {
        const s = id === undefined || id === null ? "" : String(id)
        return s.length > 0 && s.endsWith(ephemeralClientIdSuffix)
    }

    function clientIdFor(offTheRecord) {
        return offTheRecord ? baseClientId + ephemeralClientIdSuffix : baseClientId
    }
}
