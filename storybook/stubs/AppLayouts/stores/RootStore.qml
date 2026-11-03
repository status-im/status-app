import QtQuick
import AppLayouts.stores.Messaging as MessagingStores

QtObject {
    readonly property MessagingStores.MessagingRootStore messagingRootStore: MessagingStores.MessagingRootStore {}
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
