import QtQuick

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.status

import AppLayouts.Browser.webview
import AppLayouts.Profile.popups
import AppLayouts.Profile.views.browser

SettingsContentBase {
    id: root

    required property string userUID
    property var accountSettings

    property Component searchEngineModal: SearchEngineModal {
        accountSettings: root.accountSettings
    }

    Item {
        id: rootItem
        width: root.contentWidth
        height: childrenRect.height

        Column {
            id: layout
            anchors.top: parent.top
            anchors.left: parent.left
            width: parent.width
            spacing: Theme.padding
            padding: Theme.halfPadding

            HomePageView {
                width: parent.width
                accountSettings: root.accountSettings
            }

            StatusSettingsLineButton {
                width: parent.width
                leftPadding: 0
                background: null
                text: qsTr("Search engine for address bar")
                currentValue: SearchEnginesConfig.getEngineName(accountSettings.selectedBrowserSearchEngineId)
                onClicked: searchEngineModal.createObject(root).open()
            }

            DefaultDAppExplorerView {
                width: parent.width
                accountSettings: root.accountSettings
            }

            OpenLinksInView {
                width: parent.width
                accountSettings: root.accountSettings
            }

            StatusListItem {
                width: parent.width
                leftPadding: 0
                bgColor: StatusColors.transparent
                title: qsTr("Show bookmarks bar")
                components: [
                    StatusSwitch {
                        checked: accountSettings.shouldShowFavoritesBar
                        onToggled: { accountSettings.shouldShowFavoritesBar = checked }
                    }
                ]
                onClicked: accountSettings.shouldShowFavoritesBar = !accountSettings.shouldShowFavoritesBar
            }

            StatusListItem {
                width: parent.width
                leftPadding: 0
                bgColor: StatusColors.transparent
                title: qsTr("Restore open tabs")
                subTitle: qsTr("Turn on to save your tabs only on this device and restore them next time. Turning off deletes all saved session data.")
                statusListItemSubTitle.font.pixelSize: Theme.fontSize(13)
                components: [
                    StatusSwitch {
                        id: restoreTabsSwitch
                        checked: BrowserUiSettings.restoreOpenTabs
                        onToggled: {
                            BrowserUiSettings.restoreOpenTabs = checked
                            if (!checked) // clear settings
                                BrowserUiSettings.openTabs = []
                            BrowserUiSettings.sync()
                        }
                    }
                ]
                onClicked: restoreTabsSwitch.click()
            }
        }
    }
}
