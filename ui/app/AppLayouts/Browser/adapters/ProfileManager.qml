import QtQuick
import QtWebEngine

import StatusQ.Internal

QtObject {
    id: root

    /// A Download re-issued through BrowserProfileUtils that no live Web View
    /// initiated (host-side Retry needs no Tab — ADR 0006 §7). View-attributed
    /// re-issues are delivered by the owning WebViewAdapter instead.
    signal viewlessDownloadRequested(var download, string token)

    // Chromium default UA (same for all profiles in a Qt build). Snapshot before
    // Binding override — httpUserAgent="" does not restore navigator.userAgent.
    property string defaultHttpUserAgent: ""

    readonly property QtObject d: QtObject {

        // Cached WebEngine profiles, keyed by key().
        readonly property var profiles: ({})

        readonly property Connections profileUtilsDownloads: Connections {
            target: BrowserProfileUtils
            function onDownloadRequested(webEngineView, download, token) {
                if (webEngineView)
                    return
                root.viewlessDownloadRequested(download, token)
            }
        }

        // Local previews get a profile of their own, never shared with browsing:
        // separate cache and cookie jar, and the only profile allowed to reach
        // file:// (see the two local-URL policies below).
        function key(userUID, offTheRecord, localPreview) {
            if (localPreview)
                return userUID + "::preview"
            return userUID + "::" + (offTheRecord ? "otr" : "default")
        }

        function createScriptFromPath(scriptEntry) {
            const path = scriptEntry.path ?? scriptEntry
            const runOnSubFrames = scriptEntry.runOnSubFrames ?? true
            const pathStr = path.toString()
            const name = pathStr.split("/").pop()
            return {
                name: name,
                sourceUrl: path,
                injectionPoint: WebEngineScript.DocumentCreation,
                worldId: WebEngineScript.MainWorld,
                runsOnSubFrames: runOnSubFrames
            }
        }

        function getProfilePrototype(storageName, offTheRecord, key) {
            const storageNameProp = storageName
                ? `storageName: "${storageName.replace(/"/g, '\\"')}"`
                : ""
            const persistentCookiesPolicy = offTheRecord
                ? "persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies"
                : ""

            return Qt.createQmlObject(`
                import QtWebEngine
                WebEngineProfilePrototype {
                    ${storageNameProp}
                    ${persistentCookiesPolicy}
                }
            `, root, "ProfilePrototype_" + key)
        }
    }

    function getOrCreateStorageProfile(profileParams) {
        const localPreview = !!profileParams.localPreview
        const key = d.key(profileParams.userId, profileParams.offTheRecord,
                          localPreview)
        let p = d.profiles[key]

        if (!p) {
            // A local preview is always off the record and never named, so it
            // keeps no storage of its own whatever tab it was opened from.
            const prototype = d.getProfilePrototype(
                localPreview ? "" : profileParams.storageName,
                localPreview || profileParams.offTheRecord,
                key)
            p = prototype.instance()
            // Qt allows one live profile per data path and returns null on collision,
            // which happens while a previous Browser instance is still being torn down.
            // Returning null keeps the Web View on the default profile; dereferencing
            // it here would abort before the cache write and crash the render path.
            if (!p) {
                console.error("ProfileManager: no profile for", key,
                              "- another profile still holds this data path")
                return null
            }
            // Live cookie index for per-site clear (Qt 6 loadAllCookies is a no-op
            // for re-emitting existing cookies — see BrowserProfileUtils).
            BrowserProfileUtils.trackProfile(p)
            // Backend-owned local-browsing policy (ADR 0006 §8): browsing
            // profiles reach no file:// at all; the local-preview profile
            // reaches only the downloads and player-page directories.
            if (localPreview)
                BrowserProfileUtils.installLocalPreviewUrlPolicy(p)
            else
                BrowserProfileUtils.installBrowsingUrlPolicy(p)
            if (!root.defaultHttpUserAgent)
                root.defaultHttpUserAgent = p.httpUserAgent
            d.profiles[key] = p
        }

        return p
    }

    function getProfile(profileParams) {
        return getOrCreateStorageProfile(profileParams)
    }

    function scriptListForParams(profileParams) {
        // Nothing of ours runs in a local preview — no site_utils, no dapp
        // injectors — whatever the params were built with.
        if (profileParams.localPreview)
            return []
        if (!profileParams.scripts || profileParams.scripts.length === 0)
            return []
        return profileParams.scripts.map(path => d.createScriptFromPath(path))
    }

}
