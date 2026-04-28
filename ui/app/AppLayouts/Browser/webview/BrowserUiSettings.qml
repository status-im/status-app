pragma Singleton
import QtCore

// Session keys use `userProfile.pubKey` from the engine context so the category
// is correct before any binding reads properties (no delayed initialize()).
Settings {
    id: root

    category: "BrowserSettings_%1".arg(userProfile.pubKey)

    property bool restoreOpenTabs
    property var openTabs: []
    property int currentTabIndex: 0
}
