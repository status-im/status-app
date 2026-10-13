import QtQuick
import QtTest

import Models
import Storybook

import StatusQ.TestHelpers
import StatusQ.Core.Utils

import AppLayouts.HomePage

import utils

Item {
    id: root
    width: 1000
    height: 800

    HomePageAdaptor {
        id: homePageAdaptor

        sectionsBaseModel: SectionsModel {}
        chatsBaseModel: ChatsModel { id: homeChats }
        chatsSearchBaseModel: ChatsSearchModel {}
        walletsBaseModel: WalletAccountsModel {}
        dappsBaseModel: DappsModel {}

        syncingBadgeCount: 2
        messagingBadgeCount: 4
        showBackUpSeed: true
        backUpSeedBadgeCount: 1
        keycardEnabled: true

        searchPhrase: controlUnderTest ? controlUnderTest.searchPhrase : ""

        profileId: "0xdeadbeef"
    }

    Component {
        id: componentUnderTest
        HomePage {
            width: root.width
            height: root.height

            homePageEntriesModel: homePageAdaptor.homePageEntriesModel
            sectionsModel: homePageAdaptor.sectionsModel
            pinnedModel: homePageAdaptor.pinnedModel

            onItemActivated: function(key, sectionType, itemId) {
                homePageAdaptor.setTimestamp(key, new Date().valueOf())
            }
            onItemPinRequested: function(key, pin) {
                homePageAdaptor.setPinned(key, pin)
                if (pin)
                    homePageAdaptor.setTimestamp(key, new Date().valueOf()) // update the timestamp so that the pinned dock items are sorted by their recency
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
    property int initialChatsCount

    StatusTestCase {
        name: "HomePage"

        function init() {
            root.initialChatsCount = homeChats.count
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function cleanup() {
            dynamicSpy.cleanup()
            homePageAdaptor.clear() // cleanup the pinned items
            if (homeChats.count > root.initialChatsCount)
                homeChats.remove(root.initialChatsCount, homeChats.count - root.initialChatsCount)
        }

        function homeChat(id, isThread, isCategory) {
            return {
                itemId: id, name: id, isThread: isThread, isCategory: isCategory,
                type: Constants.chatType.oneToOne, icon: "", emoji: "", color: "",
                colorId: 1, hasUnreadMessages: false, notificationsCount: 0,
                onlineStatus: 1, lastMessageText: ""
            }
        }

        function test_searchIncludesThreads() {
            const model = homePageAdaptor.homePageEntriesModel
            verify(ModelUtils.indexOf(model, "id", "id1") >= 0)
            homeChats.append(homeChat("filter-thread", true, false))
            homeChats.append(homeChat("filter-channel", false, false))
            homeChats.append(homeChat("filter-category", false, true))
            const searchField = findChild(controlUnderTest, "homeSearchField")
            verify(!!searchField)
            searchField.text = "filter"
            tryCompare(model, "count", 2)
            compare(ModelUtils.modelToArray(model, ["id"]).map(row => row.id).sort(),
                    ["filter-channel", "filter-thread"])
            homeChats.setProperty(root.initialChatsCount, "isThread", false)
            compare(model.count, 2)
            homeChats.setProperty(root.initialChatsCount, "isThread", true)
            compare(model.count, 2)
            homeChats.remove(root.initialChatsCount + 1)
            tryCompare(model, "count", 1)
            compare(ModelUtils.get(model, 0).id, "filter-thread")
            homeChats.remove(root.initialChatsCount)
            tryCompare(model, "count", 0)
            searchField.text = "welcome"
            tryCompare(model, "count", 1)
            compare(ModelUtils.get(model, 0).id, "id2")
        }

        function test_basic_geometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
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
            waitForRendering(grid)
            waitForItemPolished(grid)

            const searchField = findChild(controlUnderTest, "homeSearchField")
            verify(!!searchField)
            tryCompare(searchField, "cursorVisible", true)
            searchField.clear()
            tryCompare(searchField, "text", "")
            keyClickSequence(data.searchStr)
            tryCompare(searchField, "text", data.searchStr)

            // the loader itself appears asynchronously, so retry the lookup too
            let gridBtn = null
            tryVerify(() => {
                const loader = findChild(grid, "homeGridItemLoader_" + data.key)
                gridBtn = loader ? loader.item : null
                return !!gridBtn
            })

            dynamicSpy.setup(controlUnderTest, "itemActivated") // signal itemActivated(string key, int sectionType, string itemId)

            mouseClick(gridBtn, gridBtn.width/2, gridBtn.height/2, Qt.LeftButton, Qt.NoModifier, 200)

            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.key)
            compare(dynamicSpy.signalArguments[0][1], data.sectionType)
            compare(dynamicSpy.signalArguments[0][1], gridBtn.sectionType)
            compare(dynamicSpy.signalArguments[0][2], gridBtn.itemId)
        }

        function test_show_hide_dapps_data() {
            return [
                        { tag: "dapps enabled", showDapps: true },
                        { tag: "dapps disabled", showDapps: false },
                    ]
        }

        function test_show_hide_dapps(data) {
            const dAppsVisible = data.showDapps
            homePageAdaptor.showDapps = dAppsVisible

            const gridView = findChild(controlUnderTest, "homePageGridView")
            verify(!!gridView)
            gridView.forceLayout()
            waitForRendering(gridView)

            var anyDappsFound = false
            const count = gridView.count
            for (var i = 0; i < count; i++) {
                gridView.positionViewAtIndex(i, GridView.Visible)
                const gridItem = gridView.itemAtIndex(i)
                if (!!gridItem && gridItem.item.sectionType === Constants.appSection.dApp) {
                    anyDappsFound = true
                }
            }

            compare(anyDappsFound, dAppsVisible)
        }
    }
}
