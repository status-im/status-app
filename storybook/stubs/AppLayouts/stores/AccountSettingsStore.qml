import QtQuick

QtObject {
    property bool showUsersList: false

    function setShowUsersList(show) {
        showUsersList = show
    }

    property bool termsBannerDismissed: false

    function dismissTermsBanner() {
        termsBannerDismissed = true
    }
}
