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

    function getOrCreateStorageProfile(userId, offTheRecord) {
        const key = root._key(userId, offTheRecord)
        let p = root.profiles[key]

        if (!p) {
            const storageName = offTheRecord
                ? ("IncognitoProfile_" + userId)
                : ("Profile_" + userId)

            const prototype = root._getProfilePrototype(storageName, offTheRecord)
            p = prototype.instance()
            root.profiles[key] = p
        }

        return p
    }

    function getProfile(profileParams) {
        return getOrCreateStorageProfile(profileParams.userId, profileParams.offTheRecord)
    }

    function scriptListForParams(profileParams) {
        if (!profileParams.scripts || profileParams.scripts.length === 0)
            return []
        return profileParams.scripts.map(path => createScriptFromPath(path))
    }
}
