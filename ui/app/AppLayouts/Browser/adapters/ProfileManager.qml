pragma Singleton
import QtQuick
import QtWebEngine

QtObject {
    id: root
    property var profiles: ({})

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

    function _getProfilePrototype(storageName, offTheRecord) {
        const storageNameProp = offTheRecord
            ? ""
            : `storageName: "${storageName.replace(/"/g, '\\"')}"`
        const persistentCookiesPolicy = offTheRecord
            ? "persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies"
            : ""

        return Qt.createQmlObject(`
            import QtWebEngine
            WebEngineProfilePrototype {
                ${storageNameProp}
                ${persistentCookiesPolicy}
            }
        `, root, "ProfilePrototype_" + storageName)
    }

    function getProfile(profileParams) {
        const key = root._key(profileParams.userId, profileParams.offTheRecord)
        let p = root.profiles[key]

        if (!p) {
            const storageName = profileParams.offTheRecord
                ? ("IncognitoProfile_" + profileParams.userId)
                : ("Profile_" + profileParams.userId)

            const prototype = root._getProfilePrototype(storageName, profileParams.offTheRecord)
            p = prototype.instance()
            root.profiles[key] = p
        }

        if (profileParams.userAgent && p.httpUserAgent !== profileParams.userAgent) {
            p.httpUserAgent = profileParams.userAgent
        }

        if (profileParams.scripts && profileParams.scripts.length > 0) {
            const scripts = profileParams.scripts.map(path => createScriptFromPath(path))
            p.userScripts.collection = scripts
        }

        return p
    }
}
