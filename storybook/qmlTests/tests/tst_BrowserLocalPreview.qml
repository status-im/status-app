import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.webview

/**
 * Local preview tabs (ADR 0006 §8): a tab opened to display a downloaded file
 * is isolated from browsing — its own ephemeral profile, no injected scripts,
 * and its params never seed a browsing tab. The WebEngine settings and the
 * local-URL policy that complete the isolation live in the Backend
 * (WebViewAdapter / browserprofileutils.cpp) and are not reachable from QML.
 */
Item {
    id: root

    width: 400
    height: 400

    readonly property url profileManagerUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/adapters/ProfileManager.qml")

    Component {
        id: hostStackComponent

        Item { width: 1; height: 1 }
    }

    Component {
        id: browsingParamsComponent

        ProfileParams {
            userId: "user-1"
            userAgent: ""
            scripts: ["site_utils.js"]
            offTheRecord: false
        }
    }

    Component {
        id: previewParamsComponent

        ProfileParams {
            userId: "user-1"
            userAgent: ""
            scripts: []
            offTheRecord: true
            localPreview: true
        }
    }

    // Kind-agnostic params; userId / offTheRecord / localPreview per instance.
    Component {
        id: bareParamsComponent

        ProfileParams {
            userAgent: ""
            scripts: []
        }
    }

    Component {
        id: fakeWebViewComponent

        Item {
            property ProfileParams profileParams: null
            property url url: ""
            property string uid: ""
            property string title: ""
            property url icon: ""
            property bool offTheRecord: profileParams ? profileParams.offTheRecord
                                                      : false
        }
    }

    Component {
        id: tabsModelComponent

        QtObject {
            property int currentIndex: 0
            property int count: 1

            function createEmptyTab() {}
            function removeTab(index) {}
        }
    }

    Component {
        id: browserWebViewContextComponent

        BrowserWebViewContext {
            required property Item hostStack
            required property var tabsModelRef

            thirdpartyServicesEnabled: true
            isDebugEnabled: false
            isMobile: true // no WebEngine ProfileManager under test
            hasPopups: false
            browserSettings: QtObject {}
            connectorController: null
            dappsEnabled: false
            hostStackLayout: hostStack
            tabsModel: tabsModelRef
            defaultProfileParams: ProfileParams {
                userId: "user-1"
                userAgent: ""
                scripts: ["site_utils.js"]
                offTheRecord: false
            }
            otrProfileParams: ProfileParams {
                userId: "user-1"
                userAgent: ""
                scripts: ["site_utils.js"]
                offTheRecord: true
            }
            bookmarksStore: QtObject {}
            downloadsStore: QtObject {}
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
        name: "BrowserLocalPreview"
        when: windowShown

        function createProfileManager() {
            const component = Qt.createComponent(root.profileManagerUrl)
            verify(component.status === Component.Ready, component.errorString())
            return createTemporaryObject(component, root)
        }

        /// Params for one profile kind: browsing, incognito, or local preview.
        function params(userId, offTheRecord, localPreview) {
            return createTemporaryObject(bareParamsComponent, root, {
                userId: userId,
                offTheRecord: offTheRecord,
                localPreview: localPreview
            })
        }

        // A preview keeps nothing on disk whatever tab it was opened from.
        function test_previewParams_areNeverNamedStorage() {
            const preview = createTemporaryObject(previewParamsComponent, root)
            compare(preview.storageName, "")

            // Even if built without the incognito flag: local preview implies it.
            preview.offTheRecord = false
            compare(preview.storageName, "")

            const browsing = createTemporaryObject(browsingParamsComponent, root)
            compare(browsing.storageName, "Profile_user-1")
            compare(browsing.localPreview, false, "browsing params default to off")
        }

        // Which profile a view gets is the observable fact: a preview never
        // lands on the profile that backs browsing, incognito or not.
        function test_previewProfile_isSeparateFromBrowsing() {
            const pm = createProfileManager()

            const preview = pm.getProfile(params("user-1", true, true))
            const browsing = pm.getProfile(params("user-1", false, false))
            const incognito = pm.getProfile(params("user-1", true, false))

            verify(!!preview && !!browsing && !!incognito, "each kind gets a profile")
            // Equivalent params share one profile — params are a key, not an identity.
            compare(pm.getProfile(params("user-1", false, false)), browsing)
            verify(preview !== browsing)
            verify(preview !== incognito)
            verify(browsing !== incognito)
            // Incognito does not split the preview profile in two.
            compare(pm.getProfile(params("user-1", false, true)), preview)
            // …but the user does, like every other profile.
            verify(pm.getProfile(params("user-2", true, true)) !== preview)
        }

        // Nothing of ours runs in a preview: no site_utils, no dapp injectors.
        function test_previewParams_getNoUserScripts() {
            const pm = createProfileManager()

            const browsing = createTemporaryObject(browsingParamsComponent, root)
            compare(pm.scriptListForParams(browsing).length, 1)

            const preview = createTemporaryObject(previewParamsComponent, root)
            compare(pm.scriptListForParams(preview).length, 0)

            // The flag decides, not the (empty) script list it was built with.
            preview.scripts = ["site_utils.js", "ethereum_injector.js"]
            compare(pm.scriptListForParams(preview).length, 0)
        }

        // A preview's isolated, script-free profile must not back a browsing tab
        // opened from it (Ctrl+T, window.open, closing the last tab).
        function test_browsingTabs_neverInheritPreviewParams() {
            const hostStack = createTemporaryObject(hostStackComponent, root)
            const tabsModel = createTemporaryObject(tabsModelComponent, root)
            const ctx = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel
            })

            const browsingParams = createTemporaryObject(browsingParamsComponent, root)
            const view = createTemporaryObject(fakeWebViewComponent, hostStack,
                                               { profileParams: browsingParams })
            compare(ctx.currentBrowsingProfileParams, browsingParams,
                    "an ordinary tab passes its own params on")

            view.profileParams = createTemporaryObject(previewParamsComponent, root)
            compare(ctx.currentBrowsingProfileParams, ctx.defaultProfileParams,
                    "a preview tab hands over the default profile instead")
        }

        // Leaving incognito swaps a tab's params; a preview has none to swap to.
        function test_incognitoToggle_doesNotReachPreviewTabs() {
            const hostStack = createTemporaryObject(hostStackComponent, root)
            const tabsModel = createTemporaryObject(tabsModelComponent, root)
            const ctx = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel
            })

            const previewParams = createTemporaryObject(previewParamsComponent, root)
            const view = createTemporaryObject(fakeWebViewComponent, hostStack,
                                               { profileParams: previewParams })

            ctx.setIncognitoCurrent(false)
            compare(view.profileParams, previewParams)
            ctx.setIncognitoCurrent(true)
            compare(view.profileParams, previewParams)

            // An ordinary tab still switches.
            view.profileParams = createTemporaryObject(browsingParamsComponent, root)
            ctx.setIncognitoCurrent(true)
            compare(view.profileParams, ctx.otrProfileParams)
        }

        // A restored session reopens URLs in browsing tabs, so a preview tab
        // must never enter it — the file it showed is no page to come back to,
        // and restoring it would put a local path in a browsing profile.
        function test_previewTabs_areNeverSaved() {
            const determineRealURL = function(url) { return url }

            const browsing = createTemporaryObject(fakeWebViewComponent, root, {
                profileParams: createTemporaryObject(browsingParamsComponent, root),
                url: "https://example.com/page",
                uid: "tab-1",
                title: "Example"
            })
            const dto = BrowserSessionUtils.buildTabDto(browsing, [], determineRealURL)
            verify(!!dto, "an ordinary tab is saved")
            compare(dto.url, "https://example.com/page")

            const previewParams = createTemporaryObject(previewParamsComponent, root)
            const preview = createTemporaryObject(fakeWebViewComponent, root, {
                profileParams: previewParams,
                url: "file:///tmp/downloads/report.pdf",
                uid: "tab-2",
                title: "report.pdf"
            })
            compare(BrowserSessionUtils.buildTabDto(preview, [], determineRealURL), null)

            // …and the flag is what decides, not the incognito mode it implies:
            // a filter change there must not silently start persisting previews.
            previewParams.offTheRecord = false
            compare(preview.offTheRecord, false)
            compare(BrowserSessionUtils.buildTabDto(preview, [], determineRealURL), null)
        }
    }
}
