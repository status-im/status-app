import QtQuick

QtObject {
    property bool isProduction: false
    // WalletLoader picks the privacy wall vs the real layout off this
    property bool thirdpartyServicesEnabled: true
    property bool navToMsgDetails: false
    property bool navToMsgList: false

    // ENS resolution round-trip, as used by the send modal's recipient field
    signal ensNameResolved(string resolvedPubKey, string resolvedAddress, string uuid)

    function resolveENS(ensName, uuid) {
        ensNameResolved("", "", uuid)
    }

    function setNavToMsgDetailsFlag(navigate) {
        navToMsgDetails = navigate
    }

    function setNavToMsgListFlag(navigate) {
        navToMsgList = navigate
    }
}
