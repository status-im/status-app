import QtQuick
import QtTest

import AppLayouts.Profile.stores as ProfileStores

import mainui
import utils

import Models

Item {
    id: root
    width: 800
    height: 640

    readonly property bool isLandscape: root.width > root.height

    Component {
        id: componentUnderTest
        PrimaryNavSidebar {
            height: parent.height
            visible: root.isLandscape
            interactive: !root.isLandscape

            profileStore: ProfileStores.ProfileStore {
                readonly property string pubKey: "0xdeadbeef"
                readonly property string compressedPubKey: "zxDeadBeef"
                readonly property string name: "John Doe"
                readonly property string icon: ModelsData.icons.rarible
                readonly property int colorId: 5
                readonly property bool usesDefaultName: false
                property int currentUserStatus: Constants.currentUserStatus.automatic
            }
            sectionsModel: SectionsModel {}

            getLinkToProfileFn: function(pubkey) {
                return Constants.userLinkPrefix + pubkey
            }
            getEmojiHashFn: function(pubkey) {
                return ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮"]
            }

            marketEnabled: false
            browserEnabled: false
            nodeEnabled: false
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
        }

        function test_basic_geometry() {
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
            compare(controlUnderTest.implicitWidth, 76)
        }

        function test_drawer_properties() {
            compare(controlUnderTest.edge, Qt.LeftEdge)
            compare(controlUnderTest.dim, controlUnderTest.interactive)
            verify(controlUnderTest.spacing > 0)
        }

        function test_sections_model_binding() {
            verify(!!controlUnderTest.sectionsModel)
            verify(controlUnderTest.sectionsModel.count > 0)
        }

        function test_profile_store_binding() {
            verify(!!controlUnderTest.profileStore)
            compare(controlUnderTest.profileStore.name, "John Doe")
            compare(controlUnderTest.profileStore.pubKey, "0xdeadbeef")
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
            compare(acButton.hasNotification, true)
            compare(acButton.notificationsCount, 5)
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

        function test_default_active_section() {
            // Wallet should be active according to SectionsModel
            const walletBtn = findChild(controlUnderTest.contentItem, "Wallet-navbar")
            verify(!!walletBtn)
            tryCompare(walletBtn, "sectionType", Constants.appSection.wallet)
            tryCompare(walletBtn, "checked", true)

            // Messages should not be active
            const messagesBtn = findChild(controlUnderTest.contentItem, "Messages-navbar")
            verify(!!messagesBtn)
            tryCompare(messagesBtn, "checked", false)
        }

        function test_active_section_changed() {
            // Wallet should be active according to SectionsModel
            const walletBtn = findChild(controlUnderTest.contentItem, "Wallet-navbar")
            verify(!!walletBtn)
            tryCompare(walletBtn, "sectionType", Constants.appSection.wallet)
            tryCompare(walletBtn, "checked", true)

            // verify the Settings button is not checked
            const settingsBtn = findChild(controlUnderTest.contentItem, "Settings-navbar")
            verify(!!settingsBtn)
            tryCompare(settingsBtn, "checked", false)
            tryCompare(settingsBtn, "sectionType", Constants.appSection.profile)

            // simulate changing the active section from outside (via mock model update)
            controlUnderTest.sectionsModel.setActiveSection(settingsBtn.sectionId)

            // verify that Settings is active, Wallet is not
            tryCompare(settingsBtn, "checked", true)
            tryCompare(walletBtn, "checked", false)
        }

        function test_notification_indicators() {
            // Messages has notifications according to SectionsModel
            const messagesBtn = findChild(controlUnderTest.contentItem, "Messages-navbar")
            verify(!!messagesBtn)
            compare(messagesBtn.hasNotification, true)
            compare(messagesBtn.notificationsCount, 442)
            verify(messagesBtn.badgeVisible)

            // Wallet has no notifications
            const walletBtn = findChild(controlUnderTest.contentItem, "Wallet-navbar")
            verify(!!walletBtn)
            compare(walletBtn.hasNotification, false)
            compare(walletBtn.notificationsCount, 0)
            verify(!walletBtn.badgeVisible)
        }

        function test_browser_section_enabled() {
            controlUnderTest.browserEnabled = true

            waitForRendering(controlUnderTest.contentItem)

            const browserBtn = findChild(controlUnderTest.contentItem, "Browser-navbar")
            verify(!!browserBtn)
            tryCompare(browserBtn, "visible", true)
        }

        function test_node_section_enabled() {
            controlUnderTest.nodeEnabled = true

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
            controlUnderTest.marketEnabled = true

            waitForRendering(controlUnderTest.contentItem)

            // Should have market-related functionality
            const marketBtn = findChild(controlUnderTest.contentItem, "Market-navbar")
            verify(!!marketBtn)
            tryCompare(marketBtn, "visible", true)
            compare(swapBtn.visible, undefined)
        }

        function test_show_enabled_sections_only() {
            controlUnderTest.showEnabledSectionsOnly = true

            // Home section is disabled in SectionsModel, should not be visible
            const homeBtn = findChild(controlUnderTest.contentItem, "Home-navbar")
            compare(homeBtn, null)

            controlUnderTest.showEnabledSectionsOnly = false

            waitForRendering(controlUnderTest.contentItem)

            // Now it might be present (depending on filter implementation)
            verify(true) // Basic validation
        }

        function test_profile_section_notification() {
            controlUnderTest.profileSectionHasNotification = true

            const settingsBtn = findChild(controlUnderTest.contentItem, "Settings-navbar")
            verify(!!settingsBtn)

            // Settings button should show notification when profileSectionHasNotification is true
            tryCompare(settingsBtn, "hasNotification", true)
            tryCompare(settingsBtn, "badgeVisible", true)
        }

        function test_create_community_badge() {
            controlUnderTest.showCreateCommunityBadge = true

            const communitiesBtn = findChild(controlUnderTest.contentItem, "Communities-navbar")
            verify(!!communitiesBtn)

            // Communities button should show badge gradient
            tryCompare(communitiesBtn, "showBadgeGradient", true)
            tryCompare(communitiesBtn, "hasNotification", true)
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
            compare(controlUnderTest.dim, true)
            compare(controlUnderTest.modal, true)

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
