import QtQuick

QtObject {
    property bool isProduction: false
    property bool navToMsgDetails: false
    property bool navToMsgList: false

    function setNavToMsgDetailsFlag(navigate) {
        navToMsgDetails = navigate
    }

    function setNavToMsgListFlag(navigate) {
        navToMsgList = navigate
    }
}
