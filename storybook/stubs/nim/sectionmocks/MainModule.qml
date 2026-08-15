// Mock of src/app/modules/main/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "mainModule"

    property bool mainLoaded: true
    property bool isOnline: true
    property bool notificationAvailable: false
    property string appNetworkId: "1"
    property var activeSection: null
    property ListModel sectionsModel: ListModel {}

    // Addresses already shown to the user, so the "new address" hint is not
    // raised for every generated account.
    property var shownAddresses: ({})

    signal resolvedENS(string resolvedPubKey, string resolvedAddress, string uuid)

    function addressWasShown(address) {
        const seen = !!root.shownAddresses[address]
        root.shownAddresses[address] = true
        return seen
    }

    function setActiveSectionById(id) {}
    function resolveENS(value, uuid) { root.resolvedENS("", "", uuid) }
    function signOutAndQuit() {}
}
