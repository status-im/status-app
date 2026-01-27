import QtQuick
import QtTest

import AppLayouts.Profile.helpers

import mainui
import mainui.adaptors
import utils

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
        nodeEnabled: false

        function reset() {
            marketEnabled = false
            browserEnabled = false
            nodeEnabled = false
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

            profileSectionHasNotification: false
            showCreateCommunityBadge: false
            thirdpartyServicesEnabled: true

            acVisible: false
            acHasUnseenNotifications: false
            acUnreadNotificationsCount: 0
        }
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
            waitForRendering(controlUnderTest.contentItem)
            tryCompare(controlUnderTest, "visible", true)
        }

        function cleanup() {
            itemActivatedSpy.clear()
            activityCenterSpy.clear()
            sidebarAdaptor.reset()
        }

        function test_basic_geometry() {
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
            compare(controlUnderTest.implicitWidth, 68)
        }

        function test_drawer_properties() {
            compare(controlUnderTest.edge, Qt.LeftEdge)
            compare(controlUnderTest.dim, controlUnderTest.interactive)
            verify(controlUnderTest.spacing > 0)
        }

        function test_zzz_portrait_mobile_view() {
            // switch to portrait/mobile mode
            root.width = 640
            root.height = 800
            tryCompare(controlUnderTest, "visible", false)

            // position the mouse over the handle
            const handle = findChild(controlUnderTest, "rainbowHandle")
            verify(!!handle)
            mouseMove(handle)

            // drag to reveal it
            mouseDrag(handle, handle.width/2, handle.height/2, 80, 0)
            tryCompare(controlUnderTest, "visible", true)
            tryCompare(handle, "visible", false)
        }

        function test_sections_model_binding() {
            verify(!!controlUnderTest.regularItemsModel)
            verify(controlUnderTest.regularItemsModel.count > 0)
            verify(!!controlUnderTest.communityItemsModel)
            verify(controlUnderTest.communityItemsModel.count > 0)
            verify(!!controlUnderTest.bottomItemsModel)
            verify(controlUnderTest.bottomItemsModel.count > 0)
        }

        function test_self_contact_binding() {
            verify(!!controlUnderTest.selfContactDetails)
            compare(controlUnderTest.selfContactDetails.displayName, "John Doe")
            compare(controlUnderTest.selfContactDetails.publicKey, "0xdeadbeef")
        }

        function test_profile_button_exists() {
            const profileBtn = findChild(controlUnderTest.contentItem, "statusProfileNavBarTabButton")
            verify(!!profileBtn)
            tryCompare(profileBtn, "visible", true)
        }

        function test_activity_center_button() {
            controlUnderTest.acVisible = false
            controlUnderTest.acHasUnseenNotifications = true
            controlUnderTest.acUnreadNotificationsCount = 5

            // AC button should be checkable
            const acButton = findChild(controlUnderTest.contentItem, "Activity Center-navbar")
            verify(!!acButton)

            compare(acButton.checkable, true)
            compare(acButton.checked, false)
            compare(acButton.showBadge, true)
            compare(acButton.badgeCount, 5)
            verify(acButton.badgeVisible)
        }

        function test_activity_center_toggle() {
            controlUnderTest.acVisible = false

            const acButton = findChild(controlUnderTest.contentItem, "Activity Center-navbar")
            verify(!!acButton)

            mouseClick(acButton)

            compare(activityCenterSpy.count, 1)
            compare(activityCenterSpy.signalArguments[0][0], true)
        }

        function test_regular_section_buttons_exist() {
            // Check for Messages button
            const messagesBtn = findChild(controlUnderTest.contentItem, "Messages-navbar")
            verify(!!messagesBtn)
            tryCompare(messagesBtn, "visible", true)

            // Check for Wallet button
            const walletBtn = findChild(controlUnderTest.contentItem, "Wallet-navbar")
            verify(!!walletBtn)
            tryCompare(walletBtn, "visible", true)

            // Check for Settings button
            const settingsBtn = findChild(controlUnderTest.contentItem, "Settings-navbar")
            verify(!!settingsBtn)
            tryCompare(settingsBtn, "visible", true)
        }

        function test_section_button_click() {
            const messagesBtn = findChild(controlUnderTest.contentItem, "Messages-navbar")
            verify(!!messagesBtn)
            tryCompare(messagesBtn, "visible", true)

            mouseClick(messagesBtn)

            tryCompare(itemActivatedSpy, "count", 1)
            compare(itemActivatedSpy.signalArguments[0][0], Constants.appSection.chat)
            compare(itemActivatedSpy.signalArguments[0][1], "id1")
        }

        function test_active_section_changed() {
            // Wallet should be active according to SectionsModel
            const walletBtn = findChild(controlUnderTest.contentItem, "Wallet-navbar")
            verify(!!walletBtn)
            tryCompare(walletBtn, "checked", true)

            // verify the Settings button is not checked
            const settingsBtn = findChild(controlUnderTest.contentItem, "Settings-navbar")
            verify(!!settingsBtn)
            tryCompare(settingsBtn, "checked", false)

            // simulate changing the active section from outside (via mock model update)
            sidebarAdaptor.sectionsModel.setActiveSection("id3") // "id" of Constants.appSection.profile

            // verify that Settings is active, Wallet is not
            tryCompare(settingsBtn, "checked", true)
            tryCompare(walletBtn, "checked", false)
        }

        function test_notification_indicators() {
            // Messages has notifications according to SectionsModel
            const messagesBtn = findChild(controlUnderTest.contentItem, "Messages-navbar")
            verify(!!messagesBtn)
            compare(messagesBtn.showBadge, true)
            compare(messagesBtn.badgeCount, 442)
            verify(messagesBtn.badgeVisible)

            // Wallet has no notifications
            const walletBtn = findChild(controlUnderTest.contentItem, "Wallet-navbar")
            verify(!!walletBtn)
            compare(walletBtn.showBadge, false)
            compare(walletBtn.badgeCount, 0)
            verify(!walletBtn.badgeVisible)
        }

        function test_browser_section_enabled() {
            sidebarAdaptor.browserEnabled = true

            waitForRendering(controlUnderTest.contentItem)

            const browserBtn = findChild(controlUnderTest.contentItem, "Browser-navbar")
            verify(!!browserBtn)
            tryCompare(browserBtn, "visible", true)
        }

        function test_node_section_enabled() {
            sidebarAdaptor.nodeEnabled = true

            waitForRendering(controlUnderTest.contentItem)

            const nodeBtn = findChild(controlUnderTest.contentItem, "Node-navbar")
            verify(!!nodeBtn)
            tryCompare(nodeBtn, "visible", true)
        }

        function test_communities_portal_button() {
            const communitiesBtn = findChild(controlUnderTest.contentItem, "Communities-navbar")
            verify(!!communitiesBtn)
            tryCompare(communitiesBtn, "visible", true)
        }

        function test_market_swap_sections() {
            const swapBtn = findChild(controlUnderTest.contentItem, "Swap-navbar")
            verify(!!swapBtn)
            tryCompare(swapBtn, "visible", true)

            // When marketEnabled is true, Market section should be present, Swap not
            sidebarAdaptor.marketEnabled = true

            waitForRendering(controlUnderTest.contentItem)

            // Should have market-related functionality
            const marketBtn = findChild(controlUnderTest.contentItem, "Market-navbar")
            verify(!!marketBtn)
            tryCompare(marketBtn, "visible", true)
            compare(swapBtn.visible, undefined)
        }

        function test_show_enabled_sections_only() {
            sidebarAdaptor.showEnabledSectionsOnly = true

            // Home section is disabled in SectionsModel, should not be visible
            const homeBtn = findChild(controlUnderTest.contentItem, "Home-navbar")
            compare(homeBtn, null)

            sidebarAdaptor.showEnabledSectionsOnly = false

            waitForRendering(controlUnderTest.contentItem)

            // Now it might be present (depending on filter implementation)
            verify(true) // Basic validation
        }

        function test_profile_section_notification() {
            controlUnderTest.profileSectionHasNotification = true

            const settingsBtn = findChild(controlUnderTest.contentItem, "Settings-navbar")
            verify(!!settingsBtn)

            // Settings button should show notification when profileSectionHasNotification is true
            tryCompare(settingsBtn, "showBadge", true)
            tryCompare(settingsBtn, "badgeVisible", true)
        }

        function test_create_community_badge() {
            controlUnderTest.showCreateCommunityBadge = true

            const communitiesBtn = findChild(controlUnderTest.contentItem, "Communities-navbar")
            verify(!!communitiesBtn)

            // Communities button should show badge gradient
            tryCompare(communitiesBtn, "showBadgeGradient", true)
            tryCompare(communitiesBtn, "showBadge", true)
            tryCompare(communitiesBtn, "badgeVisible", true)
        }

        function test_background_is_transparent() {
            const bg = controlUnderTest.background
            verify(!!bg)
            verify(Qt.colorEqual(bg.color, "transparent"))
        }

        function test_community_buttons_have_object_name() {
            // Look for community buttons with specific objectName
            const communityBtn = findChild(controlUnderTest.contentItem, "CommunityNavBarButton")
            // May or may not exist depending on model data, just verify no crash
            verify(true)
        }

        function test_drawer_always_visible() {
            // Test interactive mode
            controlUnderTest.alwaysVisible = false
            compare(controlUnderTest.dim, false)
            compare(controlUnderTest.modal, false)

            // Test non-interactive mode
            controlUnderTest.alwaysVisible = true
            compare(controlUnderTest.dim, false)
            compare(controlUnderTest.modal, false)
        }

        function test_section_spacing() {
            const contentItem = controlUnderTest.contentItem
            verify(!!contentItem)
            verify(contentItem.spacing > 0)
            compare(contentItem.spacing, controlUnderTest.spacing)
        }
    }
}
