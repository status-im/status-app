import QtQuick

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.status

import AppLayouts.Profile.popups
import AppLayouts.Profile.views.browser

SettingsContentBase {
    id: root

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
                id: homePageView
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
                id: dAppExplorerView
                width: parent.width
                accountSettings: root.accountSettings
            }

            OpenLinksInView {
                width: parent.width
                accountSettings: root.accountSettings
            }

            StatusListItem {
                id: showFavouritesItem
                width: parent.width
                leftPadding: 0
                bgColor: StatusColors.transparent
                title: qsTr("Show bookmarks bar")
                components: [
                    StatusSwitch {
                        id: favSwitch
                        checked: accountSettings.shouldShowFavoritesBar
                        onToggled: { accountSettings.shouldShowFavoritesBar = checked }
                    }
                ]
                onClicked: accountSettings.shouldShowFavoritesBar = !accountSettings.shouldShowFavoritesBar
            }
        }
    }
}
