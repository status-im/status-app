import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.webview

/// Keep-alive reasons and Drop on the Tab set (CONTEXT): which Web Views a
/// Drop spares, and the two facts BrowserDropPolicy reads.
Item {
    id: root

    width: 400
    height: 400

    Component {
        id: hostStackComponent

        Item { width: 1; height: 1 }
    }

    Component {
        id: fakeTabComponent

        Item {
            property url url: ""
            property var adapterItem: null
            property bool playingAudio: false
            property bool retained: false
            property int dropCalls: 0
            readonly property QtObject bridge: QtObject {
                readonly property QtObject connectorManager: QtObject {
                    property bool hasPendingRequests: false
                }
            }

            function drop() { dropCalls += 1; adapterItem = null }
            function detachView() {}
        }
    }

    Component {
        id: downloadsStoreComponent

        QtObject {
            property var busyViews: []
            readonly property bool hasNonTerminalDownloads: busyViews.length > 0

            function viewHasNonTerminalDownloads(view) {
                return busyViews.indexOf(view) !== -1
            }
        }
    }

    Component {
        id: tabsModelComponent

        QtObject {
            property int currentIndex: 0
            property int count: 3
        }
    }

    Component {
        id: contextComponent

        BrowserWebViewContext {
            required property Item hostStack
            required property var tabsModelRef
            required property var downloadsStoreRef

            thirdpartyServicesEnabled: true
            isDebugEnabled: false
            isMobile: true
            hasPopups: false
            browserSettings: QtObject {}
            connectorController: null
            dappsEnabled: false
            hostStackLayout: hostStack
            tabsModel: tabsModelRef
            defaultProfileParams: ProfileParams {
                userId: ""
                userAgent: ""
                scripts: []
                offTheRecord: false
            }
            otrProfileParams: ProfileParams {
                userId: ""
                userAgent: ""
                scripts: []
                offTheRecord: true
            }
            bookmarksStore: QtObject {}
            downloadsStore: downloadsStoreRef
            determineRealURLFn: function(url) { return url }
            downloadRequestHandler: function() {}
            linkLongPressHandler: function() {}
            sslErrorHandler: function() {}
            jsDialogHandler: function() {}
            findTextFinishedHandler: function() {}
            savedSessionContext: QtObject {
                function seedWebView() {}
            }
        }
    }

    TestCase {
        name: "BrowserKeepAlive"
        when: windowShown

        property Item hostStack: null
        property var store: null
        property var context: null
        property var tabs: []

        function init() {
            hostStack = createTemporaryObject(hostStackComponent, root)
            store = createTemporaryObject(downloadsStoreComponent, root)
            const tabsModel = createTemporaryObject(tabsModelComponent, root)
            tabs = []
            for (let i = 0; i < 3; ++i) {
                tabs.push(createTemporaryObject(fakeTabComponent, hostStack, {
                    url: "https://site" + i + ".example/",
                    adapterItem: root
                }))
            }
            context = createTemporaryObject(contextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel,
                downloadsStoreRef: store
            })
        }

        function test_idleTabsHaveNoReason() {
            verify(context.hasLivePage)
            verify(!context.hasKeepAliveReason)
        }

        function test_eachReasonCounts() {
            tabs[0].playingAudio = true
            verify(context.hasKeepAliveReason, "audible media")
            tabs[0].playingAudio = false

            tabs[1].bridge.connectorManager.hasPendingRequests = true
            verify(context.hasKeepAliveReason, "a dApp request awaiting the user")
            tabs[1].bridge.connectorManager.hasPendingRequests = false

            store.busyViews = [tabs[2]]
            verify(context.hasKeepAliveReason, "a non-terminal Download")
            store.busyViews = []

            verify(!context.hasKeepAliveReason)
        }

        function test_dropSparesTheViewsWithAReason() {
            tabs[0].playingAudio = true
            store.busyViews = [tabs[2]]

            context.dropIdleViews()

            compare(tabs[0].dropCalls, 0)
            compare(tabs[1].dropCalls, 1)
            compare(tabs[2].dropCalls, 0)
        }

        function test_droppedOrBlankTabsShowNoPage() {
            tabs[1].url = ""
            context.dropIdleViews()

            verify(!context.hasLivePage)
        }
    }
}
