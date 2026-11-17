import QtQml

import StatusQ.Core.Utils

QObject {
    id: root

    readonly property bool showUsersList: d.settings.expandUsersList

    function setShowUsersList(expanded: bool) {
        d.settings.expandUsersList = expanded
    }

    QtObject {
        id: d

        readonly property var settings: localAccountSettings
    }
}
