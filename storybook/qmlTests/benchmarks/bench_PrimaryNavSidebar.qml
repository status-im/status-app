import QtQuick
import QtTest

import AppLayouts.Profile.helpers

import mainui
import mainui.adaptors
import utils
import Models

import Benchmark

/*
  PrimaryNavSidebar, the app's main navigation: 8 sidebars side by side
  (one is always shown in the app; 8 make its cost measurable), 760 px
  tall or 300 px. With the sample sections the list overflows at both
  heights, so its edge fade is on.

  Variants: tall, short (static, scroll).
*/
Item {
    id: root

    width: 1000
    height: 800

    PrimaryNavSidebarAdaptor {
        id: sidebarAdaptor
        sectionsModel: SectionsModel {}
        marketEnabled: false
        browserEnabled: false
    }

    BenchmarkRunner {
        id: runner

        anchors.fill: parent
        count: 8
        cellWidth: 80
        cellHeight: 760

        delegate: PrimaryNavSidebar {
            required property int index

            width: runner.cellWidth
            height: runner.cellHeight
            selfContactDetails: ContactDetails {
                publicKey: "0xdeadbeef"
                compressedPubKey: "zxDeadBeef"
                displayName: "John Doe"
                icon: ModelsData.icons.rarible
                colorId: 7
                usesDefaultName: false
                onlineStatus: Constants.currentUserStatus.automatic
            }
            regularItemsModel: sidebarAdaptor.regularItemsModel
            communityItemsModel: sidebarAdaptor.communityItemsModel
            bottomItemsModel: sidebarAdaptor.bottomItemsModel
            getLinkToProfileFn: pubkey => Constants.userLinkPrefix + pubkey
            getEmojiHashFn: pubkey => ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮"]
            thirdpartyServicesEnabled: true
            acVisible: false
            acHasUnseenNotifications: false
            acUnreadNotificationsCount: 0
        }
    }

    TestCase {
        name: "Bench"
        when: windowShown

        function bench(height) {
            runner.cellHeight = height
            runner.scenarios = ["static", "scroll"]
            runner.start()
            tryVerify(() => runner.result !== null, 300000)
            console.info("BENCH-RESULT " + JSON.stringify(runner.result))
        }

        function test_tall() { bench(760) }
        function test_short() { bench(300) }
    }
}
