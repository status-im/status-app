import QtQuick
import QtQuick.Controls
import QtTest

import Models

import mainui
import mainui.adaptors

import AppLayouts.Profile.helpers

import utils

Item {
    id: root
    width: 800
    height: 900

    readonly property var sectionsModel: SectionsModel {}

    PrimaryNavSidebarAdaptor {
        id: sidebarAdaptor
        sectionsModel: root.sectionsModel
        marketEnabled: true
        browserEnabled: true
    }

    ContactDetails {
        id: selfDetails
        publicKey: "0xdeadbeef"
        compressedPubKey: "zxDeadBeef"
        displayName: "John Doe"
        colorId: 7
        usesDefaultName: false
        onlineStatus: Constants.currentUserStatus.automatic
    }

    Component {
        id: sidebarComponent

        PrimaryNavSidebar {
            height: root.height

            regularItemsModel: sidebarAdaptor.regularItemsModel
            communityItemsModel: sidebarAdaptor.communityItemsModel
            bottomItemsModel: sidebarAdaptor.bottomItemsModel

            selfContactDetails: selfDetails

            getEmojiHashFn: function(pubKey) { return ["\ud83d\ude03"] }
            getLinkToProfileFn: function(pubKey) { return "" }
            acVisible: false
            acHasUnseenNotifications: false
            acUnreadNotificationsCount: 0
            thirdpartyServicesEnabled: true
            profileSectionHasNotification: false
        }
    }

    TestCase {
        id: testCase
        name: "PrimaryNavSidebarBench"
        when: windowShown

        function pendingLoaders(item) : int {
            let pending = 0
            if ((item instanceof Loader) && item.active && item.status !== Loader.Ready)
                pending++
            for (let i = 0; i < item.children.length; i++)
                pending += pendingLoaders(item.children[i])
            return pending
        }

        function test_creationTime() {
            const WARMUP = 2
            const RUNS = 10
            let syncTotal = 0
            let readyTotal = 0

            for (let i = 0; i < WARMUP + RUNS; i++) {
                const t0 = Date.now()
                const obj = sidebarComponent.createObject(root)
                const t1 = Date.now()
                verify(!!obj)

                tryVerify(() => pendingLoaders(obj) === 0, 30000)
                const t2 = Date.now()

                // sanity: content actually materialized
                verify(!!findChild(obj, "statusProfileNavBarTabButton"))
                verify(!!findChild(obj, "Activity Center-navbar"))

                if (i >= WARMUP) {
                    syncTotal += t1 - t0
                    readyTotal += t2 - t0
                }

                obj.destroy()
                wait(50)
            }

            console.info("PrimaryNavSidebar creation: blocking avg %1 ms, time-to-ready avg %2 ms (n=%3)"
                         .arg((syncTotal / RUNS).toFixed(1))
                         .arg((readyTotal / RUNS).toFixed(1))
                         .arg(RUNS))
        }
    }
}
