import QtQuick
import utils

BrowserPreferencesStoreBase {
    override property var snapshotsCache: ({})

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
}
