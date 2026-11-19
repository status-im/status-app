import QtQuick
import QtTest

import AppLayouts.stores as AppStores

import mainui.sectionLoaders

// Desktop keeps the Browser layout from the first visit on, also once the
// Browser is turned off in settings (its Tabs live in the layout).
Item {
    id: root

    width: 800
    height: 600

    AppStores.RootStore {
        id: appRootStore
    }

    Component {
        id: loaderComp

        BrowserLoader {
            anchors.fill: parent

            userUID: "0xdeadbeef"
            sectionName: "browser"

            rootStore: appRootStore
            featureFlagsStore: null
            advancedStore: null
            networksStore: null
            currencyStore: null
            transactionStore: null
            popupHandler: null
        }
    }

    TestCase {
        name: "BrowserLoaderDesktop"
        when: windowShown

        function test_nothingLoadsBeforeTheFirstVisit() {
            const loader = createTemporaryObject(loaderComp, root, { sectionEnabled: true })

            verify(!loader.active)
        }

        function test_aDisabledBrowserIsNeverLoaded() {
            const loader = createTemporaryObject(loaderComp, root,
                                                 { sectionEnabled: false, sectionCurrent: true })

            verify(!loader.active)
        }

        function test_turningTheBrowserOffKeepsTheLayout() {
            const loader = createTemporaryObject(loaderComp, root,
                                                 { sectionEnabled: true, sectionCurrent: true })
            tryVerify(() => !!loader.item)
            const layout = loader.item

            loader.sectionCurrent = false
            loader.sectionEnabled = false

            verify(loader.active)
            compare(loader.item, layout)

            loader.sectionEnabled = true
            compare(loader.item, layout)
        }
    }
}
