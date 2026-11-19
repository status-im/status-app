import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores

import mainui.sectionLoaders

Item {
    id: root

    width: 800
    height: 600

    AppStores.RootStore { id: appRootStore }

    Component {
        id: portalComponent

        Item {
            readonly property alias store: store
            readonly property alias loader: loader
            property bool portalActive: false
            property bool storeReady: true

            anchors.fill: parent

            CommunitiesStore {
                id: store

                property var calls: []

                readonly property string communityTags: "[]"
                readonly property ListModel curatedCommunitiesModel: ListModel {}

                function refreshCuratedCommunities() {
                    calls.push("refresh")
                }

                function stopCuratedCommunitiesRefresh() {
                    calls.push("stop")
                }

                function retryCuratedCommunitiesRefresh() {
                    calls.push("retry")
                }
            }

            CommunitiesPortalLoader {
                id: loader

                anchors.fill: parent
                active: parent.portalActive

                userUID: "0xdeadbeef"
                sectionName: "communitiesPortal"
                rootStore: appRootStore
                communitiesStore: parent.storeReady ? store : null
            }
        }
    }

    TestCase {
        name: "CommunitiesPortalLoader"
        when: windowShown

        property Item portal: null

        function createPortal(properties = {}) {
            portal = createTemporaryObject(portalComponent, root, properties)
            verify(!!portal)
            return portal
        }

        function cleanup() {
            portal.portalActive = false
            portal = null
        }

        function test_curatedRefreshFollowsThePortal() {
            const portal = createPortal()
            compare(portal.store.calls, [])

            portal.portalActive = true
            compare(portal.store.calls, ["refresh"])

            portal.portalActive = false
            compare(portal.store.calls, ["refresh", "stop"])

            portal.portalActive = true
            compare(portal.store.calls, ["refresh", "stop", "refresh"])
        }

        function test_refreshRequestedByThePortalIsPassedToTheStore() {
            const portal = createPortal({ portalActive: true })
            tryVerify(() => !!portal.loader.item)

            portal.loader.item.curatedRefreshRequested()

            compare(portal.store.calls, ["refresh", "retry"])
        }

        function test_pullToRefreshIsForMobileOnly() {
            const portal = createPortal({ portalActive: true })
            tryVerify(() => !!portal.loader.item)

            compare(portal.loader.item.pullToRefreshEnabled, SQUtils.Utils.isMobile)
            compare(portal.loader.item.pullToRefreshEnabled, false)
        }

        function test_storeArrivingAfterThePortalOpensRefreshes() {
            const portal = createPortal({ portalActive: true, storeReady: false })
            compare(portal.store.calls, [])
            verify(!portal.loader.item)

            portal.storeReady = true
            compare(portal.store.calls, ["refresh"])
            tryVerify(() => !!portal.loader.item)

            portal.portalActive = false
            compare(portal.store.calls, ["refresh", "stop"])
        }

        function test_portalActiveFromTheStartRefreshes() {
            const portal = createPortal({ portalActive: true })
            compare(portal.store.calls, ["refresh"])
        }
    }
}
