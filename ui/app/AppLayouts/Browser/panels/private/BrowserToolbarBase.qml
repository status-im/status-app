import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models

import StatusQ.Core.Theme
import StatusQ.Popups

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

    required property var historyModel

    signal requestAllOpenTabsView()
    signal addBookmarkRequested()
    signal editBookmarkRequested()
    signal removeBookmarkRequested()
    signal requestStopLoadingPage()
    signal requestReloadPage()
    signal requestGoForward()
    signal requestGoBack()
    signal requestLaunchInBrowser(string url)
    signal requestSearch()
    signal requestOpenDapp(string url)
    signal requestDisconnectDapp(string dappUrl)
    signal requestWalletMenu()
    signal openSettingMenu(var target, point pos)
    signal goIncognito(bool checked)
    signal requestDownloadsView()

    signal goBackOrForwardRequested(int offset)

    padding: 6

    background: Rectangle {
        color: root.currentTabIncognito ? Theme.palette.privacyColors.primary : Theme.palette.background
    }

    function requestHistoryPopup(parent, pos) {
        historyMenuComp.createObject(root).popup(parent, pos)
    }

    Component {
        id: historyMenuComp

        StatusMenu {
            id: historyMenu

            Instantiator {
                model: root.historyModel
                StatusMenuItem {
                    text: model.title
                    icon.source: model.icon
                    onTriggered: root.goBackOrForwardRequested(model.offset)
                    checkable: !enabled
                    checked: !enabled
                    enabled: model.offset
                }
                onObjectAdded: function(index, object) {
                    historyMenu.insertItem(index, object)
                }
                onObjectRemoved: function(index, object) {
                    historyMenu.removeItem(object)
                }
            }
            onClosed: destroy()
        }
    }
}
