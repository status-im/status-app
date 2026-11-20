import QtQuick
import QtTest

import AppLayouts.stores as AppStores

import mainui.sectionLoaders
import StatusQ.Core

// Without a Backend that brings a dropped Browser back as it was (desktop,
// iOS for now), the layout stays from the first visit on, also once the
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
        name: "BrowserLoader"
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
    
        function test_theHostBackendCannotBringADroppedBrowserBack() {
            const loader = createTemporaryObject(loaderComp, root)

            verify(!loader.dropSupported)
        }

        function test_withoutDropSupportPressureKeepsTheLayout() {
            const loader = createTemporaryObject(loaderComp, root, { dropSupported: false,
                                                                      sectionCurrent: true })
            tryVerify(() => !!loader.item)

            loader.sectionCurrent = false
            SystemUtils.memoryPressure(true)

            verify(loader.active)
        }

        function test_withDropSupportPressureDropsTheLayout() {
            const loader = createTemporaryObject(loaderComp, root, { dropSupported: true,
                                                                      sectionCurrent: true })
            tryVerify(() => !!loader.item)

            loader.sectionCurrent = false
            SystemUtils.memoryPressure(true)

            verify(!loader.active)
            verify(!loader.item)
        }
    }
}
