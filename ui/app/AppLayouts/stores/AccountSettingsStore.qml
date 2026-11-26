import QtQml

import StatusQ.Core.Utils

QObject {
    id: root

    readonly property bool showUsersList: d.settings.expandUsersList

    function setShowUsersList(expanded: bool) {
        d.settings.expandUsersList = expanded
    }

    readonly property bool termsBannerDismissed: d.settings.termsBannerDismissed

    function dismissTermsBanner() {
        d.settings.termsBannerDismissed = true
    }

    QtObject {
        id: d

        readonly property var settings: localAccountSettings
    }
}
