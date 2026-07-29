import QtQuick

QtObject {
    id: root

    property var logosNetworkModule

    readonly property int peerCount: logosNetworkModule ? logosNetworkModule.peerCount : -1
    readonly property bool peerCountLoading: logosNetworkModule ? logosNetworkModule.peerCountLoading : false
    readonly property string peerCountError: logosNetworkModule ? logosNetworkModule.peerCountError : ""

    function refreshPeerCount() {
        if (!root.logosNetworkModule) {
            return
        }
        root.logosNetworkModule.refreshPeerCount()
    }
}
