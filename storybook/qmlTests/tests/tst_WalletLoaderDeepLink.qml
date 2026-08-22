import QtQuick
import QtTest

import AppLayouts.stores as AppStores

import mainui.sectionLoaders

// RED (stack PR #21918): WalletLoader became asynchronous, but the wallet
// deep-link entry point (AppMain.qml, onAppSectionBySectionTypeChanged) still
// dereferences the loaded item in the same tick as the section activation:
// `appView.children[...wallet].item.openDesiredView(subsection, ...)`. With
// async incubation `item` is null at that point, so activity-center and toast
// redirects to a transaction throw a TypeError and the txHash payload is
// dropped. The loader must expose a queuing openDesiredView forwarder (the
// pattern ProfileLoader.forceSubsectionNavigation already uses) that replays
// the navigation once the section finishes incubating.
Item {
    id: root

    width: 800
    height: 600

    AppStores.RootStore { id: appRootStore }
    AppStores.ContactsStore { id: appContactsStore }
    AppStores.FeatureFlagsStore { id: appFeatureFlagsStore }

    Loader { id: dummyLoader }

    WalletLoader {
        id: walletLoader
        anchors.fill: parent

        // never load the real section in the test harness
        active: false

        rootStore: appRootStore
        contactsStore: appContactsStore
        featureFlagsStore: appFeatureFlagsStore
        sharedRootStore: null
        networkConnectionStore: null
        networksStore: null
        communitiesStore: null
        transactionStore: null
        popupHandler: null
        dappsServiceLoader: dummyLoader
        emojiPopupLoader: dummyLoader
    }

    TestCase {
        name: "WalletLoaderDeepLink"
        when: windowShown

        function test_deepLinkSurvivesAsyncIncubation() {
            verify(walletLoader.asynchronous,
                   "precondition: the wallet section loads asynchronously")

            // AppMain fires the deep link in the same tick as the section
            // activation, when `item` does not exist yet — the loader itself
            // must accept and queue the navigation.
            verify(typeof walletLoader.openDesiredView === "function",
                   "WalletLoader must expose openDesiredView and queue it until "
                   + "the section item exists; today AppMain dereferences "
                   + "`.item.openDesiredView(...)` and throws while incubating")
        }
    }
}
