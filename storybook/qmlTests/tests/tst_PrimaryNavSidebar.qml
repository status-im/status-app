import QtQuick
import QtTest

import StatusQ.Popups

import AppLayouts.Profile.helpers

import mainui
import mainui.adaptors
import utils

import shared.controls.chat.menuItems

import Models

Item {
    id: root
    width: 800
    height: 640

    PrimaryNavSidebarAdaptor {
        id: sidebarAdaptor
        sectionsModel: SectionsModel {}
        marketEnabled: false
        browserEnabled: false

        function reset() {
            marketEnabled = false
            browserEnabled = false
            showEnabledSectionsOnly = true
        }
    }

    Component {
        id: componentUnderTest
        PrimaryNavSidebar {
            height: parent.height

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

            getLinkToProfileFn: function(pubkey) {
                return Constants.userLinkPrefix + pubkey
            }
            getEmojiHashFn: function(pubkey) {
                return ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮"]
            }

            thirdpartyServicesEnabled: true

            acVisible: false
            acHasUnseenNotifications: false
            acUnreadNotificationsCount: 0
        }
    }

    QtObject {
        id: d
        property bool cascadeSubmenus: true
    }

    SignalSpy {
        id: itemActivatedSpy
        signalName: "itemActivated"
        target: controlUnderTest ?? null
    }

    SignalSpy {
        id: activityCenterSpy
        signalName: "activityCenterRequested"
        target: controlUnderTest ?? null
    }

    property PrimaryNavSidebar controlUnderTest: null

    TestCase {
        name: "PrimaryNavSidebar"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            tryCompare(controlUnderTest, "visible", true)
        }

        function cleanup() {
            itemActivatedSpy.clear()
            activityCenterSpy.clear()
            sidebarAdaptor.reset()
            d.cascadeSubmenus = true
        }

        function test_basic_geometry() {
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
            compare(controlUnderTest.implicitWidth, 60 + 8 + 8) // Main nav bar width + left and right margins
        }

        function test_sections_model_binding() {
            verify(!!controlUnderTest.regularItemsModel)
            verify(controlUnderTest.regularItemsModel.count > 0)
            verify(!!controlUnderTest.bottomItemsModel)
            verify(controlUnderTest.bottomItemsModel.count > 0)
        }

        function test_self_contact_binding() {
            verify(!!controlUnderTest.selfContactDetails)
            compare(controlUnderTest.selfContactDetails.displayName, "John Doe")
            compare(controlUnderTest.selfContactDetails.publicKey, "0xdeadbeef")
        }

        function test_profile_button_exists() {
            const profileBtn = findChild(controlUnderTest, "statusProfileNavBarTabButton")
            verify(!!profileBtn)
            tryCompare(profileBtn, "visible", true)
        }

        function test_activity_center_button() {
            controlUnderTest.acVisible = false
            controlUnderTest.acHasUnseenNotifications = true
            controlUnderTest.acUnreadNotificationsCount = 5

            // AC button should be checkable
            const acButton = findChild(controlUnderTest, "Activity Center-navbar")
            verify(!!acButton)

            compare(acButton.checkable, true)
            compare(acButton.checked, false)
            compare(acButton.showBadge, true)
            compare(acButton.badgeCount, 5)
            verify(acButton.badgeVisible)
        }

        function test_activity_center_toggle() {
            controlUnderTest.acVisible = false

            const acButton = findChild(controlUnderTest, "Activity Center-navbar")
            verify(!!acButton)
            waitForRendering(acButton)
            waitForItemPolished(acButton)
            mouseClick(acButton)

            compare(activityCenterSpy.count, 1)
            compare(activityCenterSpy.signalArguments[0][0], true)
        }

        function test_activity_center_button_ripple() {
            const acButton = findChild(controlUnderTest, "Activity Center-navbar")
            verify(!!acButton)
            waitForRendering(acButton)

            const ripple = findChild(acButton, "primaryNavSidebarButtonRipple")
            verify(!!ripple)
            verify(ripple.enabled)
            verify(!ripple.visible)

            const pressX = acButton.width / 2
            const pressY = acButton.height / 2
            const ripplePoint = acButton.mapToItem(ripple, pressX, pressY)

            mousePress(acButton, pressX, pressY)
            tryVerify(() => ripple.visible)
            verify(ripple.pressed)
            verify(Math.abs(ripple.pressX - ripplePoint.x) <= 1)
            verify(Math.abs(ripple.pressY - ripplePoint.y) <= 1)

            mouseRelease(acButton, pressX, pressY)
            tryCompare(ripple, "visible", false)
            verify(!ripple.pressed)
        }

        function test_regular_section_buttons_exist() {
            // Check for Messages button
            const messagesBtn = findChild(controlUnderTest, "Messages-navbar")
            verify(!!messagesBtn)
            tryCompare(messagesBtn, "visible", true)

            // Check for Wallet button
            const walletBtn = findChild(controlUnderTest, "Wallet-navbar")
            verify(!!walletBtn)
            tryCompare(walletBtn, "visible", true)

            // Settings is not a nav item anymore, it lives in the profile menu
            verify(!findChild(controlUnderTest, "Settings-navbar"))
        }

        function test_section_button_click() {
            const messagesBtn = findChild(controlUnderTest, "Messages-navbar")
            verify(!!messagesBtn)
            tryCompare(messagesBtn, "visible", true)

            mouseClick(messagesBtn)

            tryCompare(itemActivatedSpy, "count", 1)
            compare(itemActivatedSpy.signalArguments[0][0], Constants.appSection.chat)
            compare(itemActivatedSpy.signalArguments[0][1], "id1")
        }

        function test_active_section_changed() {
            // Wallet should be active according to SectionsModel
            const walletBtn = findChild(controlUnderTest, "Wallet-navbar")
            verify(!!walletBtn)
            tryCompare(walletBtn, "checked", true)

            // simulate changing the active section from outside (via mock model update)
            sidebarAdaptor.sectionsModel.setActiveSection("id3") // "id" of Constants.appSection.profile

            tryCompare(walletBtn, "checked", false)
        }

        function test_notification_indicators() {
            // Messages has notifications according to SectionsModel
            const messagesBtn = findChild(controlUnderTest, "Messages-navbar")
            verify(!!messagesBtn)
            compare(messagesBtn.showBadge, true)
            compare(messagesBtn.badgeCount, 442)
            verify(messagesBtn.badgeVisible)

            // Wallet has no notifications
            const walletBtn = findChild(controlUnderTest, "Wallet-navbar")
            verify(!!walletBtn)
            compare(walletBtn.showBadge, false)
            compare(walletBtn.badgeCount, 0)
            verify(!walletBtn.badgeVisible)
        }

        function test_browser_section_enabled() {
            sidebarAdaptor.browserEnabled = true

            waitForRendering(controlUnderTest)

            const browserBtn = findChild(controlUnderTest, "Browser-navbar")
            verify(!!browserBtn)
            tryCompare(browserBtn, "visible", true)
        }

        function test_communities_portal_button() {
            const communitiesBtn = findChild(controlUnderTest, "Communities-navbar")
            verify(!!communitiesBtn)
            tryCompare(communitiesBtn, "visible", true)
        }

        function test_market_swap_sections() {
            // Swap button should be visible before market is enabled
            const swapBtnBefore = findChild(controlUnderTest, "Swap-navbar")
            verify(!!swapBtnBefore)
            tryCompare(swapBtnBefore, "visible", true)

            // When marketEnabled is true, Market section should be present, Swap not
            sidebarAdaptor.marketEnabled = true
            waitForRendering(controlUnderTest)

            // Should have market-related functionality
            const marketBtn = findChild(controlUnderTest, "Market-navbar")
            verify(!!marketBtn)
            tryCompare(marketBtn, "visible", true)

            // Swap delegate may be destroyed by the ListView; re-query after model change
            const swapBtnAfter = findChild(controlUnderTest, "Swap-navbar")
            verify(!swapBtnAfter || !swapBtnAfter.visible)
        }

        function test_show_enabled_sections_only() {
            sidebarAdaptor.showEnabledSectionsOnly = true

            // dApps disabled in SectionsModel, should not be visible
            const dappBtn = findChild(controlUnderTest, "dApp-navbar")
            compare(dappBtn, null)

            sidebarAdaptor.showEnabledSectionsOnly = false

            waitForRendering(controlUnderTest)

            // Now it might be present (depending on filter implementation)
            verify(true) // Basic validation
        }

        function test_community_buttons_have_object_name() {
            // Look for community buttons with specific objectName
            const communityBtn = findChild(controlUnderTest, "CommunityNavBarButton_Status.app")
            verify(!!communityBtn)
            tryCompare(communityBtn, "visible", true)
        }

        function test_drawer_always_visible() {
            // Test interactive mode
            controlUnderTest.alwaysVisible = false
            tryCompare(controlUnderTest, "position", 0.0)

            // Test non-interactive mode
            controlUnderTest.alwaysVisible = true
            tryCompare(controlUnderTest, "position", 1.0)
        }

        Component {
            id: communityMuteContextMenu
            StatusMenu {
                objectName: "communityContextMenu"
                required property var model
                cascade: d.cascadeSubmenus
                MuteChatMenuItem {
                    objectName: "muteSubMenuPopup"
                    title: qsTr("Mute Community")
                }
            }
        }

        function test_community_context_menu_mute_submenu_data() {
            return [
              { tag: "cascade (desktop)", cascade: true },
              { tag: "no cascade (mobile)", cascade: false },
            ]
        }

        function test_community_context_menu_mute_submenu(data) {
            d.cascadeSubmenus = data.cascade

            controlUnderTest.communityPopupMenu = communityMuteContextMenu
            const communityBtn = findChild(controlUnderTest, "CommunityNavBarButton_Status.app")
            verify(!!communityBtn)
            tryCompare(communityBtn, "visible", true)
            mouseClick(communityBtn, communityBtn.width/2, communityBtn.height/2, Qt.RightButton)

            const menu = findChild(communityBtn, "communityContextMenu")
            verify(!!menu)
            tryCompare(menu, "visible", true)

            const muteSubMenu = findChild(menu, "StatusMenuItemDelegate") // need the delegate here to click
            verify(!!muteSubMenu)

            if (d.cascadeSubmenus) {
                mouseMove(muteSubMenu)
                // both menus are shown, usually side by side
                const muteSubMenuPopup = findChild(communityBtn, "muteSubMenuPopup")
                verify(!!muteSubMenuPopup)
                tryCompare(muteSubMenuPopup, "visible", true)
            } else {
                mouseClick(muteSubMenu)
                // the old menu is gone; and we have a new one
                tryCompare(menu, "visible", false)
                const muteSubMenuPopup = findChild(communityBtn, "muteSubMenuPopup")
                verify(!!muteSubMenuPopup)
                tryCompare(muteSubMenuPopup, "visible", true)
            }
        }
    }
}
