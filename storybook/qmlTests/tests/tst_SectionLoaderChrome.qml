import QtQuick
import QtTest

import AppLayouts.stores as AppStores

import mainui.sectionLoaders

// Pins the loader-owned section chrome: every StatusSectionLayout slot must
// hold its skeleton until the matching per-panel readiness flag flips, not
// until the section item merely exists. The section is replaced by a stub with
// writable flags, so the contract is checked as a binding rather than as a
// race against real incubation.
Item {
    id: root

    width: 800
    height: 600

    AppStores.RootStore { id: appRootStore }
    AppStores.AccountSettingsStore { id: appAccountSettingsStore }

    Component {
        id: sectionStubComp

        Item {
            property bool headerReady: false
            property bool leftPanelReady: false
            property bool centerPanelReady: false
            property bool rightPanelReady: false

            readonly property Item headerContent: Item {}
            readonly property Item leftPanel: Item {}
            readonly property Item centerPanel: Item {}
            readonly property Item rightPanel: Item {}

            readonly property bool showRightPanel: true
            readonly property var viewSubsectionHistory: null
            readonly property bool ownsFullPage: false
            property bool navToMsgDetails: false
        }
    }

    Component {
        id: chatLoaderComp

        ChatLoader {
            anchors.fill: parent

            // The stub stands in for the section, so the loader must not run
            // its own asynchronous load
            active: false
            asynchronous: false

            rootStore: appRootStore
            accountSettingsStore: appAccountSettingsStore
            contactsStore: null
            featureFlagsStore: null
            sharedRootStore: null
            currencyStore: null
            communityTokensStore: null
            networkConnectionStore: null
            networksStore: null
            transactionStore: null
            tokensStore: null
            walletAssetsStore: null
            advancedStore: null
            createChatPropertiesStore: null
            contactsAdaptor: null
            popupHandler: null
            emojiPopupLoader: null
            stickersPopupLoader: null
            createChatViewOpened: false
            isPortraitMode: false
        }
    }

    Component {
        id: communityChatLoaderComp

        CommunityChatLoader {
            anchors.fill: parent

            active: false
            asynchronous: false

            rootStore: appRootStore
            accountSettingsStore: appAccountSettingsStore
            contactsStore: null
            featureFlagsStore: null
            sharedRootStore: null
            currencyStore: null
            communityTokensStore: null
            networkConnectionStore: null
            networksStore: null
            transactionStore: null
            tokensStore: null
            walletAssetsStore: null
            advancedStore: null
            communitiesStore: null
            messagingRootStore: null
            createChatPropertiesStore: null
            contactsAdaptor: null
            popupHandler: null
            emojiPopupLoader: null
            stickersPopupLoader: null
            sectionId: "community-1"
            sectionItemModel: null
            createChatViewOpened: false
            isPortraitMode: false
        }
    }

    TestCase {
        id: testCase

        name: "SectionLoaderChrome"
        when: windowShown

        readonly property var slotSpecs: [
            { flag: "headerReady", slot: "headerContent", skeleton: "headerSkeleton" },
            { flag: "leftPanelReady", slot: "leftPanel", skeleton: "leftPanelSkeleton" },
            { flag: "centerPanelReady", slot: "centerPanel", skeleton: "centerPanelSkeleton" },
            { flag: "rightPanelReady", slot: "rightPanel", skeleton: "rightPanelSkeleton" }
        ]

        function createLoaderWithStub(comp) {
            const loader = createTemporaryObject(comp, root)
            verify(!!loader)
            loader.sourceComponent = sectionStubComp
            loader.active = true
            verify(!!loader.item, "the stub section must be installed, not the real one")
            return loader
        }

        function loaderCases() {
            return [
                { tag: "ChatLoader", comp: chatLoaderComp },
                { tag: "CommunityChatLoader", comp: communityChatLoaderComp }
            ]
        }

        function test_perPanelSwap_data() { return loaderCases() }

        // Each slot holds its own skeleton while its own flag is down and
        // swaps to the section's panel when that flag flips.
        function test_perPanelSwap(data) {
            const loader = createLoaderWithStub(data.comp)
            const stub = loader.item
            const chrome = findChild(loader, "sectionChrome")
            verify(!!chrome, "section chrome not found")

            for (const spec of slotSpecs) {
                const skeleton = findChild(loader, spec.skeleton)
                verify(!!skeleton, "skeleton not found: " + spec.skeleton)

                verify(chrome[spec.slot] === skeleton,
                       spec.slot + " must show its skeleton while " + spec.flag + " is false")
                verify(skeleton.active,
                       spec.skeleton + " must be alive while its slot shows it")

                stub[spec.flag] = true

                verify(chrome[spec.slot] === stub[spec.slot],
                       spec.slot + " must show the section panel once " + spec.flag + " is true")
                verify(!skeleton.active,
                       spec.skeleton + " must be released once its slot swapped")
            }
        }

        function test_slotsAreIndependent_data() { return loaderCases() }

        // Retiring one slot must leave the other three on their skeletons.
        function test_slotsAreIndependent(data) {
            const loader = createLoaderWithStub(data.comp)
            const stub = loader.item
            const chrome = findChild(loader, "sectionChrome")

            stub.headerReady = true

            verify(chrome.headerContent === stub.headerContent)
            verify(chrome.leftPanel === findChild(loader, "leftPanelSkeleton"))
            verify(chrome.centerPanel === findChild(loader, "centerPanelSkeleton"))
            verify(chrome.rightPanel === findChild(loader, "rightPanelSkeleton"))
        }
    }
}
