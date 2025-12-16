import QtQuick
import QtTest

import Models
import Storybook

import StatusQ.TestHelpers

import AppLayouts.HomePage
import AppLayouts.Profile.stores as ProfileStores

import utils

Item {
    id: root
    width: 1000
    height: 800

    HomePageAdaptor {
        id: homePageAdaptor

        sectionsBaseModel: SectionsModel {}
        chatsBaseModel: ChatsModel {}
        chatsSearchBaseModel: ChatsSearchModel {}
        walletsBaseModel: WalletAccountsModel {}
        dappsBaseModel: DappsModel {}

        syncingBadgeCount: 2
        messagingBadgeCount: 4
        showBackUpSeed: true
        backUpSeedBadgeCount: 1
        keycardEnabled: true

        searchPhrase: controlUnderTest ? controlUnderTest.searchPhrase : ""

        profileId: mockProfileStore.pubKey
    }

    ProfileStores.ProfileStore {
        id: mockProfileStore
        readonly property string pubKey: "0xdeadbeef"
        readonly property string compressedPubKey: "zxDeadBeef"
        readonly property string name: "John Roe"
        readonly property string icon: ModelsData.icons.rarible
        readonly property int colorId: 7
        readonly property bool usesDefaultName: false
        property int currentUserStatus: Constants.currentUserStatus.automatic
    }

    Component {
        id: componentUnderTest
        HomePage {
            width: root.width
            height: root.height

            homePageEntriesModel: homePageAdaptor.homePageEntriesModel
            sectionsModel: homePageAdaptor.sectionsModel
            pinnedModel: homePageAdaptor.pinnedModel

            profileStore: mockProfileStore

            getEmojiHashFn: function(pubKey) { // <- root.utilsStore.getEmojiHash(pubKey)
                if (pubKey === "")
                    return ""

                return["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮","🤷🏻‍♂️", "🤦🏻", "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]
            }
            getLinkToProfileFn: function(pubKey) { // <- root.rootStore.contactStore.getLinkToProfile(pubKey)
                return Constants.userLinkPrefix + pubKey
            }

            useNewDockIcons: false

            onItemActivated: function(key, sectionType, itemId) {
                homePageAdaptor.setTimestamp(key, new Date().valueOf())
            }
            onItemPinRequested: function(key, pin) {
                homePageAdaptor.setPinned(key, pin)
                if (pin)
                    homePageAdaptor.setTimestamp(key, new Date().valueOf()) // update the timestamp so that the pinned dock items are sorted by their recency
            }
            onSetCurrentUserStatusRequested: function (status) {
                profileStore.currentUserStatus = status
            }
        }
    }

    SignalSpy {
        id: dynamicSpy

        function setup(t, s) {
            clear()
            target = t
            signalName = s
        }

        function cleanup() {
            target = null
            signalName = ""
            clear()
        }
    }

    property HomePage controlUnderTest: null

    StatusTestCase {
        name: "HomePage"

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function cleanup() {
            dynamicSpy.cleanup()
            homePageAdaptor.clear() // cleanup the pinned items
        }

        function test_basic_geometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_homePageProfileButton() {
            const btn = findChild(controlUnderTest, "homeProfileButton")
            verify(!!btn)
            mouseClick(btn)
            const popupMenu = findChild(btn, "userStatusContextMenu")
            verify(!!popupMenu)
            tryCompare(popupMenu, "opened", true)
        }

        function test_gridItem_search_and_click_data() {
            return [
                        {tag: "wallet", sectionType: Constants.appSection.wallet,
                            key: "1;0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884", searchStr: "Fab"}, // Fab
                        {tag: "chat", sectionType: Constants.appSection.chat, key: "2;id1", searchStr: "Punx"}, // 1-1 chat
                        {tag: "group chat", sectionType: Constants.appSection.chat, key: "2;id5", searchStr: "Channel Y_3"}, // group chat
                        {tag: "community", sectionType: Constants.appSection.community, key: "3;id106", searchStr: "Dribb"}, // Dribble
                        {tag: "dApp", sectionType: Constants.appSection.dApp, key: "999;https://dapp.test/2", searchStr: "dapp 2"}, // Test dApp 2
                        {tag: "settings", sectionType: Constants.appSection.profile, key: "4;1", searchStr: "passw"}, // Settings/Password
                    ]
        }

        function test_gridItem_search_and_click(data) {
            const grid = findChild(controlUnderTest, "homeGrid")
            verify(!!grid)
            tryVerify(() => grid.width > 0)
            tryVerify(() => grid.height > 0)

            const searchField = findChild(controlUnderTest, "homeSearchField")
            verify(!!searchField)
            tryCompare(searchField, "cursorVisible", true)
            searchField.clear()
            tryCompare(searchField, "text", "")
            keyClickSequence(data.searchStr)
            tryCompare(searchField, "text", data.searchStr)

            waitForRendering(grid)

            const gridBtn = findChild(grid, "homeGridItemLoader_" + data.key).item
            tryVerify(() => !!gridBtn)

            waitForItemPolished(grid)

            dynamicSpy.setup(controlUnderTest, "itemActivated") // signal itemActivated(string key, int sectionType, string itemId)

            mouseClick(gridBtn)

            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.key)
            compare(dynamicSpy.signalArguments[0][1], data.sectionType)
            compare(dynamicSpy.signalArguments[0][1], gridBtn.sectionType)
            compare(dynamicSpy.signalArguments[0][2], gridBtn.itemId)
        }

        function test_dock_regular_buttons_data() {
            return [
                        {tag: "wallet", sectionType: Constants.appSection.wallet, sectionName: "Wallet"},
                        {tag: "chat", sectionType: Constants.appSection.chat, sectionName: "Messages"},
                        {tag: "communitiesPortal", sectionType: Constants.appSection.communitiesPortal, sectionName: "Communities"},
                        {tag: "market", sectionType: Constants.appSection.market, sectionName: "Market"},
                        {tag: "node", sectionType: Constants.appSection.node, sectionName: "Node"}, // not enabled by default
                        {tag: "settings", sectionType: Constants.appSection.profile, sectionName: "Settings"},
                    ]
        }

        function test_dock_regular_buttons(data) {
            const dock = findChild(controlUnderTest, "homeDock")
            verify(!!dock)
            tryVerify(() => dock.width > 0)
            tryVerify(() => dock.height > 0)

            const dockBtn = findChild(dock, "regularDockButton" + data.sectionName)
            verify(!!dockBtn)

            if (dockBtn.enabled) { // "Node" is disabled by default
                dynamicSpy.setup(controlUnderTest, "itemActivated") // signal itemActivated(string key, int sectionType, string itemId)
                mouseClick(dockBtn)

                tryCompare(dynamicSpy, "count", 1)
                compare(dynamicSpy.signalArguments[0][1], data.sectionType)
            }
        }

        function test_pin_unpin_from_grid_data() {
            return [
                        {tag: "pin button"},
                        {tag: "RMB context menu"},
                        {tag: "long press context menu"},
                    ]
        }

        function test_pin_unpin_from_grid(data) {
            const keyId = "4;12" // Settings/About

            const grid = findChild(controlUnderTest, "homeGrid")
            verify(!!grid)

            const gridBtn = findChild(grid, "homeGridItemLoader_" + keyId).item
            tryVerify(() => !!gridBtn)

            mouseMove(gridBtn)
            waitForItemPolished(gridBtn)

            // pin
            const pinButton = findChild(gridBtn, "pinButton")
            if (data.tag === "pin button") {
                verify(!!pinButton)
                mouseMove(pinButton)
                tryCompare(pinButton, "visible", true)
                mouseClick(pinButton)
            } else {
                if (data.tag === "RMB context menu") {
                    mouseRightClick(gridBtn)
                } else if (data.tag === "long press context menu") {
                    mouseLongPress(gridBtn)
                }

                var ctxMenu = null
                tryVerify(function () {
                    ctxMenu = findChild(gridBtn, "homeGridItemContextMenu")
                    return !!ctxMenu
                })
                // click the "Pin" menu item
                const pinMenuItem = ctxMenu.itemAt(0)
                verify(!!pinMenuItem)
                tryCompare(pinMenuItem.action, "objectName", "pinAction")
                mouseClick(pinMenuItem)
            }

            // verify pinned
            tryCompare(gridBtn, "pinned", true)

            const dock = findChild(controlUnderTest, "homeDock")
            verify(!!dock)

            waitForRendering(dock)
            waitForItemPolished(dock)

            // verify dock and pinned model has the new button
            var dockBtn = findChild(dock, "pinnedDockButton" + gridBtn.title)
            verify(!!dockBtn)
            tryCompare(homePageAdaptor.pinnedModel, "count", 1)

            // verify the pinned dock button emits itemActivated properly
            wait(1000)
            dynamicSpy.setup(controlUnderTest, "itemActivated") // signal itemActivated(string key, int sectionType, string itemId)
            mouseClick(dockBtn)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], keyId)

            // unpin
            if (data.tag === "pin button") {
                mouseMove(pinButton)
                tryCompare(pinButton, "visible", true)
                mouseClick(pinButton)
            } else {
                if (data.tag === "RMB context menu") {
                    mouseRightClick(gridBtn)
                } else if (data.tag === "long press context menu") {
                    mouseLongPress(gridBtn)
                }

                var ctxMenu = null
                tryVerify(function () {
                    ctxMenu = findChild(gridBtn, "homeGridItemContextMenu")
                    return !!ctxMenu
                })
                // click the "Unpin" menu item
                const unpinMenuItem = ctxMenu.itemAt(0)
                verify(!!unpinMenuItem)
                tryCompare(unpinMenuItem.action, "objectName", "pinAction")
                mouseClick(unpinMenuItem)
            }

            // verify button unpinned and the pinned model is down to 0
            tryCompare(gridBtn, "pinned", false)
            tryVerify(function () {
                dockBtn = findChild(dock, "pinnedDockButton" + gridBtn.title)
                return dockBtn === null
            })
            tryCompare(homePageAdaptor.pinnedModel, "count", 0)
        }

        function test_pin_from_grid_unpin_from_dock() {
            const keyId = "4;12" // Settings/About

            const grid = findChild(controlUnderTest, "homeGrid")
            verify(!!grid)

            const gridBtn = findChild(grid, "homeGridItemLoader_" + keyId).item
            tryVerify(() => !!gridBtn)

            mouseMove(gridBtn)
            waitForItemPolished(gridBtn)

            // pin
            const pinButton = findChild(gridBtn, "pinButton")
            verify(!!pinButton)
            mouseMove(pinButton)
            tryCompare(pinButton, "visible", true)
            mouseClick(pinButton)

            // verify pinned
            tryCompare(gridBtn, "pinned", true)

            var dock = findChild(controlUnderTest, "homeDock")
            verify(!!dock)

            waitForRendering(dock)
            waitForItemPolished(dock)

            // verify dock and pinned model has the new button
            var dockBtn = findChild(dock, "pinnedDockButton" + gridBtn.title)
            verify(!!dockBtn)
            tryCompare(homePageAdaptor.pinnedModel, "count", 1)

            // trigger the dock button's context menu
            mouseRightClick(dockBtn)
            const ctxMenu = findChild(dockBtn, "homeDockButtonCtxMenu")
            verify(!!ctxMenu)
            tryCompare(ctxMenu, "opened", true)

            // click the "Unpin" menu item
            const unpinMenuItem = ctxMenu.itemAt(0)
            verify(!!unpinMenuItem)
            tryCompare(unpinMenuItem.action, "objectName", "unpinAction")
            mouseClick(unpinMenuItem)

            // verify the pinned model is down to 0 and the button (eventually) disappears from the dock
            tryVerify(function () {
                dockBtn = findChild(dock, "pinnedDockButton" + gridBtn.title)
                return dockBtn === null
            })
            tryCompare(homePageAdaptor.pinnedModel, "count", 0)
        }
    }
}
