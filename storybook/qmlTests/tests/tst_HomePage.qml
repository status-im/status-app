import QtQuick
import QtTest

import Models
import Storybook

import StatusQ.TestHelpers

import AppLayouts.HomePage

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

            const gridBtn = findChild(grid, "homeGridItemLoader_" + data.key).item
            tryVerify(() => !!gridBtn)

            dynamicSpy.setup(controlUnderTest, "itemActivated") // signal itemActivated(string key, int sectionType, string itemId)

            mouseClick(gridBtn, gridBtn.width/2, gridBtn.height/2, Qt.LeftButton, Qt.NoModifier, 200)

            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.key)
            compare(dynamicSpy.signalArguments[0][1], data.sectionType)
            compare(dynamicSpy.signalArguments[0][1], gridBtn.sectionType)
            compare(dynamicSpy.signalArguments[0][2], gridBtn.itemId)
        }
    }
}
