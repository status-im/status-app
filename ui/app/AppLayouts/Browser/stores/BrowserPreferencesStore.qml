import QtQuick
import utils

BrowserPreferencesStoreBase {
    override property var snapshotsCache: ({})

    function put(category, key, value) {
        browserSection.putPreference(category, key, String(value))
    }

    function get(category, key) {
        return browserSection.getPreference(category, key) || ""
    }

    function purge(category, validKeys) {
        browserSection.purgePreferenceCategory(category, JSON.stringify(validKeys || []))
    }
}
