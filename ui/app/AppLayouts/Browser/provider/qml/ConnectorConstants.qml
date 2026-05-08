pragma Singleton

import QtQuick

QtObject {
    readonly property string baseClientId: "status-desktop/dapp-browser"
    readonly property string ephemeralClientIdSuffix: "#ephemeral"

    function isEphemeralClientId(id) {
        const s = id === undefined || id === null ? "" : String(id)
        return s.length > 0 && s.endsWith(ephemeralClientIdSuffix)
    }

    function clientIdFor(offTheRecord) {
        return offTheRecord ? baseClientId + ephemeralClientIdSuffix : baseClientId
    }
}
