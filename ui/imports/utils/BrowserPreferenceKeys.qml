pragma Singleton

import QtQuick

QtObject {
    readonly property string snapshotsCategory: "BrowserSnapshots"
    readonly property string settingsCategory: "BrowserSettings"
    readonly property string keyOpenTabs: "openTabs"
    readonly property string keyCurrentTabIndex: "currentTabIndex"
    readonly property string keyRestoreOpenTabs: "restoreOpenTabs"
}
