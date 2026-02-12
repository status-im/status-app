import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

Control {
    id: root

    required property bool isMobile

    required property bool currentTabIncognito
    required property bool currentTabIsDownloads

    required property bool canGoBack
    required property bool canGoForward

    required property int openTabsCount
    required property bool currentTabIsBookmark
    required property bool currentTabLoading
    required property var browserDappsModel

    signal requestAllOpenTabsView()
    signal addBookmarkRequested()
    signal requestStopLoadingPage()
    signal requestReloadPage()
    signal requestHistoryPopup()
    signal requestGoForward()
    signal requestGoBack()
    signal requestLaunchInBrowser(string url)
    signal requestSearch()
    signal requestOpenDapp(string url)
    signal requestDisconnectDapp(string dappUrl)
    signal requestWalletMenu()
    signal openSettingMenu(var target)
    signal goIncognito(bool checked)
    signal requestDownloadsView()

    padding: 6

    background: Rectangle {
        color: root.currentTabIncognito ? Theme.palette.privacyColors.primary : Theme.palette.background
    }
}
