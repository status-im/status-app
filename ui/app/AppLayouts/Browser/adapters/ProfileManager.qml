import QtQuick
import QtWebEngine

import StatusQ.Internal

QtObject {
    id: root
    property var profiles: ({})
    // Chromium default UA (same for all profiles in a Qt build). Snapshot before
    // Binding override — httpUserAgent="" does not restore navigator.userAgent.
    property string defaultHttpUserAgent: ""

    function _key(userUID, offTheRecord) {
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

    function _getProfilePrototype(storageName, offTheRecord, key) {
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

    function getOrCreateStorageProfile(profileParams) {
        const key = root._key(profileParams.userId, profileParams.offTheRecord)
        let p = root.profiles[key]

        if (!p) {
            const prototype = root._getProfilePrototype(
                profileParams.storageName,
                profileParams.offTheRecord,
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
            // Backend-owned local-browsing policy (ADR 0006 §8): only the
            // downloads and player-page directories are reachable via file://.
            BrowserProfileUtils.installLocalUrlPolicy(p)
            if (!root.defaultHttpUserAgent)
                root.defaultHttpUserAgent = p.httpUserAgent
            root.profiles[key] = p
        }

        return p
    }

    function getProfile(profileParams) {
        return getOrCreateStorageProfile(profileParams)
    }

    function scriptListForParams(profileParams) {
        if (!profileParams.scripts || profileParams.scripts.length === 0)
            return []
        return profileParams.scripts.map(path => createScriptFromPath(path))
    }
}
