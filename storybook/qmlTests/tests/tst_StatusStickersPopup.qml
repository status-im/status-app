import QtQuick
import QtTest

import AppLayouts.Chat.stores as ChatStores
import shared.status
import shared.stores as SharedStores

// The picker lives only while open, so opening it is what starts the pack load.
Item {
    id: root

    width: 600
    height: 600

    QtObject {
        id: stickersModuleMock

        property int numInstalledStickerPacks: 0
        property var recent: ListModel {}
        property var stickerPacks: ListModel {}
        property bool packsLoaded: false
        property bool packsLoadFailed: false
        property int loadCalls: 0

        signal stickerPackInstalled(string packId)

        function loadStickers() { ++loadCalls }
        function getRecentStickers() {}
        function getInstalledStickerPacks() {}
    }

    SharedStores.NetworkConnectionStore {
        id: networkConnectionStoreMock
    }

    ChatStores.RootStore {
        id: storeMock
        stickersModuleInst: stickersModuleMock
        networkConnectionStore: networkConnectionStoreMock
    }

    Component {
        id: popupComponent

        StatusStickersPopup {
            directParent: root
            height: 440
            store: storeMock
        }
    }

    TestCase {
        name: "StatusStickersPopup"
        when: windowShown

        function init() {
            stickersModuleMock.packsLoaded = false
            stickersModuleMock.packsLoadFailed = false
            stickersModuleMock.loadCalls = 0
            networkConnectionStoreMock.isOnline = true
        }

        function openPopup() {
            const popup = createTemporaryObject(popupComponent, root)
            popup.open()
            tryCompare(popup, "opened", true)
            return popup
        }

        function test_openingStartsANeverAttemptedLoad() {
            openPopup()
            compare(stickersModuleMock.loadCalls, 1)
        }

        function test_openingRetriesAFailedLoad() {
            stickersModuleMock.packsLoadFailed = true
            openPopup()
            compare(stickersModuleMock.loadCalls, 1)
        }

        function test_openingKeepsLoadedPacks() {
            stickersModuleMock.packsLoaded = true
            openPopup()
            compare(stickersModuleMock.loadCalls, 0)
        }

        function test_offlineOpenLoadsWhenBackOnline() {
            networkConnectionStoreMock.isOnline = false
            openPopup()
            compare(stickersModuleMock.loadCalls, 0)

            networkConnectionStoreMock.isOnline = true
            compare(stickersModuleMock.loadCalls, 1)
        }
    }
}
