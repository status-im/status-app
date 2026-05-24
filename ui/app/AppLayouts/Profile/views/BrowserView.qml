import QtQuick

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.status

import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Profile.popups
import AppLayouts.Profile.views.browser

SettingsContentBase {
    id: root

    required property string userUID
    required property BrowserStores.BrowserPreferencesStore browserPreferencesStore
    property var accountSettings

    QtObject {
        id: d
        property bool restoreOpenTabs: root.browserPreferencesStore.getRestoreOpenTabs()
    }

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
                        checked: d.restoreOpenTabs
                        onToggled: {
                            d.restoreOpenTabs = checked
                            root.browserPreferencesStore.setRestoreOpenTabs(checked)
                            if (!checked)
                                root.browserPreferencesStore.clearOpenTabsSession()
                        }
                    }
                ]
                onClicked: restoreTabsSwitch.click()
            }
        }
    }
}
