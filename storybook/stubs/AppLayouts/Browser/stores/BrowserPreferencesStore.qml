import QtQuick

QtObject {
    id: root

    readonly property string _snapshotsCategory: "BrowserSnapshots"
    readonly property string _settingsCategory: "BrowserSettings"
    readonly property string _keyOpenTabs: "openTabs"
    readonly property string _keyCurrentTabIndex: "currentTabIndex"
    readonly property string _keyRestoreOpenTabs: "restoreOpenTabs"
    property var snapshotsCache: ({})
    property var _preferences: ({})

    function _prefKey(category, key) {
        return category + "\0" + key
    }

    function put(category, key, value) {
        _preferences[_prefKey(category, key)] = String(value)
    }

    function get(category, key) {
        return _preferences[_prefKey(category, key)] || ""
    }

    function purge(category, validKeys) {
        const keep = {}
        for (const key of (validKeys || [])) {
            keep[_prefKey(category, key)] = true
        }

        const nextPreferences = {}
        for (const prefKey in _preferences) {
            if (!prefKey.startsWith(category + "\0") || keep[prefKey]) {
                nextPreferences[prefKey] = _preferences[prefKey]
            }
        }
        _preferences = nextPreferences
    }

    function getRestoreOpenTabs() {
        return get(_settingsCategory, _keyRestoreOpenTabs) === "true"
    }

    function setRestoreOpenTabs(value) {
        put(_settingsCategory, _keyRestoreOpenTabs, value ? "true" : "false")
    }

    function getOpenTabs() {
        const raw = get(_settingsCategory, _keyOpenTabs)
        if (!raw)
            return []
        try {
            const parsed = JSON.parse(raw)
            if (!Array.isArray(parsed))
                return []
            return parsed.filter(t => t && String(t.url || "").trim() !== "")
        } catch (e) {
            return []
        }
    }

    function setOpenTabs(tabsArray) {
        put(_settingsCategory, _keyOpenTabs, JSON.stringify(tabsArray || []))
    }

    function getCurrentTabIndex() {
        return parseInt(get(_settingsCategory, _keyCurrentTabIndex)) || 0
    }

    function setCurrentTabIndex(idx) {
        put(_settingsCategory, _keyCurrentTabIndex, String(idx | 0))
    }

    function clearOpenTabsSession() {
        setOpenTabs([])
        setCurrentTabIndex(0)
    }

    function getSnapshot(uid) {
        if (!uid)
            return ""

        if (snapshotsCache[uid])
            return snapshotsCache[uid]

        const snapshot = get(_snapshotsCategory, uid)
        if (snapshot)
            snapshotsCache[uid] = snapshot
        return snapshot || ""
    }

    function setSnapshot(uid, dataUri) {
        if (!uid || !dataUri)
            return

        snapshotsCache[uid] = dataUri
        put(_snapshotsCategory, uid, dataUri)
    }

    function purgeSnapshots(validUids) {
        const list = Array.isArray(validUids) ? validUids.filter(uid => !!uid) : []
        const keep = {}
        for (const uid of list) {
            keep[uid] = true
        }

        const nextCache = {}
        for (const uid in snapshotsCache) {
            if (keep[uid])
                nextCache[uid] = snapshotsCache[uid]
        }
        snapshotsCache = nextCache
        purge(_snapshotsCategory, list)
    }
}
