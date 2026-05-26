import QtQuick

import utils

QtObject {
    id: root

    virtual property var snapshotsCache: ({})

    function put(category, key, value) {}

    function get(category, key) {
        return ""
    }

    function purge(category, validKeys) {}

    function getRestoreOpenTabs() {
        return get(BrowserPreferenceKeys.settingsCategory, BrowserPreferenceKeys.keyRestoreOpenTabs) === "true"
    }

    function setRestoreOpenTabs(value) {
        put(BrowserPreferenceKeys.settingsCategory, BrowserPreferenceKeys.keyRestoreOpenTabs, value ? "true" : "false")
    }

    function getOpenTabs() {
        const raw = get(BrowserPreferenceKeys.settingsCategory, BrowserPreferenceKeys.keyOpenTabs)
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
        put(BrowserPreferenceKeys.settingsCategory, BrowserPreferenceKeys.keyOpenTabs, JSON.stringify(tabsArray || []))
    }

    function getCurrentTabIndex() {
        return parseInt(get(BrowserPreferenceKeys.settingsCategory, BrowserPreferenceKeys.keyCurrentTabIndex)) || 0
    }

    function setCurrentTabIndex(idx) {
        put(BrowserPreferenceKeys.settingsCategory, BrowserPreferenceKeys.keyCurrentTabIndex, String(idx | 0))
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

        const snapshot = get(BrowserPreferenceKeys.snapshotsCategory, uid)
        if (snapshot)
            snapshotsCache[uid] = snapshot
        return snapshot || ""
    }

    function setSnapshot(uid, dataUri) {
        if (!uid || !dataUri)
            return

        snapshotsCache[uid] = dataUri
        put(BrowserPreferenceKeys.snapshotsCategory, uid, dataUri)
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
        purge(BrowserPreferenceKeys.snapshotsCategory, list)
    }
}
