import QtQuick
import QtTest

import AppLayouts.Browser.webview

Item {
    id: root

    Component {
        id: paramsComponent

        QtObject {
            property bool localPreview: false
        }
    }

    Component {
        id: viewComponent

        QtObject {
            property var profileParams: null
            property string uid: ""
            property string title: ""
            property url icon: ""
            property var url: ""
            property bool offTheRecord: false
        }
    }

    // Stands in for BrowserWebViewContext and the tab bar together.
    Component {
        id: tabHostComponent

        QtObject {
            property var views: []
            property int count: 0
            property int activated: -1
            property int currentIndex: 0

            function createEmptyTab(params, startPage, focus, url, title, icon, uid) {
                const view = viewComponent.createObject(null, {
                    profileParams: params, url: url || "", title: title || "", uid: uid || ""
                })
                views.push(view)
                count = views.length
                return view
            }
            function getWebView(index) { return views[index] ?? null }
            function activateTab(index) { activated = index }
            function ensureCurrentWebViewLoaded() {}
        }
    }

    Component {
        id: sessionComponent

        BrowserSavedSessionContext {
            currentWebView: null
            determineRealURL: url => url
        }
    }

    TestCase {
        name: "BrowserSavedSessionContext"

        readonly property var savedTabs: [
            { uuid: "t1", url: "https://a.example", title: "A" },
            { uuid: "t2", url: "file:///Users/me/a.pdf", title: "a.pdf",
              openedFile: "/Users/me/a.pdf" },
            { uuid: "t3", url: "https://b.example", title: "B" }
        ]

        function createSession(currentIndex, fileReachable, tabsToRestore = savedTabs) {
            const host = createTemporaryObject(tabHostComponent, root)
            const defaultParams = createTemporaryObject(paramsComponent, root)
            const previewParams = createTemporaryObject(paramsComponent, root, { localPreview: true })
            const session = createTemporaryObject(sessionComponent, root, {
                webViewContext: host,
                tabs: host,
                defaultProfileParams: defaultParams,
                preferencesStore: {
                    getRestoreOpenTabs: () => true,
                    getOpenTabs: () => tabsToRestore,
                    getCurrentTabIndex: () => currentIndex,
                    purgeSnapshots: uids => {}
                },
                keepsOpenedFiles: true,
                restoreOpenedFileFn: tab => {
                    if (!fileReachable)
                        return false
                    host.createEmptyTab(previewParams, false, false, "", tab.title, "", tab.uuid)
                    return true
                }
            })
            return { session: session, host: host, defaultParams: defaultParams }
        }

        function test_anOpenedFileIsRestoredInItsPlace() {
            const t = createSession(1, true)

            t.session.restoreSession()

            compare(t.host.views.map(v => v.uid), ["t1", "t2", "t3"])
            verify(t.host.views[1].profileParams.localPreview)
            compare(t.host.views[2].profileParams, t.defaultParams)
            tryCompare(t.host, "activated", 1)
        }

        // Browsing Tabs never take a Preview Tab's profile, whatever comes first.
        function test_browsingTabsAfterAnOpenedFileKeepTheirProfile() {
            const t = createSession(0, true, [savedTabs[1], savedTabs[0]])

            t.session.restoreSession()

            compare(t.host.views.map(v => v.uid), ["t2", "t1"])
            compare(t.host.views[1].profileParams, t.defaultParams)
        }

        // An unsaved Tab before the current one must not shift the saved index.
        function test_theCurrentTabIsSavedByItsPlaceAmongSavedTabs() {
            const host = createTemporaryObject(tabHostComponent, root)
            const params = createTemporaryObject(paramsComponent, root)
            let savedIndex = -1
            const session = createTemporaryObject(sessionComponent, root, {
                webViewContext: host,
                tabs: host,
                defaultProfileParams: params,
                preferencesStore: {
                    getRestoreOpenTabs: () => true,
                    setOpenTabs: tabs => {},
                    setCurrentTabIndex: index => savedIndex = index
                }
            })
            host.createEmptyTab(params, false, false, "https://private.example", "P", "", "p")
                .offTheRecord = true
            host.createEmptyTab(params, false, false, "https://a.example", "A", "", "a")
            host.createEmptyTab(params, false, false, "https://b.example", "B", "", "b")
            host.currentIndex = 1

            session.saveSession()

            compare(session.persistedTabs.map(t => t.uuid), ["a", "b"])
            compare(savedIndex, 0)
        }

        function test_aGoneFileIsLeftOut() {
            const t = createSession(2, false)

            t.session.restoreSession()

            compare(t.host.views.map(v => v.uid), ["t1", "t3"])
            tryCompare(t.host, "activated", 1)
        }
    }
}
