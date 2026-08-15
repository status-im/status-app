import QtQuick

QtObject {
    property bool isProduction: false
    // WalletLoader picks the privacy wall vs the real layout off this
    property bool thirdpartyServicesEnabled: true
    property bool navToMsgDetails: false
    property bool navToMsgList: false

    function setNavToMsgDetailsFlag(navigate) {
        navToMsgDetails = navigate
    }

    function setNavToMsgListFlag(navigate) {
        navToMsgList = navigate
    }
}
