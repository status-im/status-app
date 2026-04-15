import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared
import shared.panels
import shared.popups
import shared.status
import shared.controls
import shared.stores

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog

import AppLayouts.stores.Messaging 1.0

import "../controls"
import "../popups"
import "../panels"

SettingsContentBase {
    id: root

    property MessagingSettingsStore messagingSettingsStore

    property alias requestsCount: contactRequestsIndicator.requestsCount

    ColumnLayout {
        id: generalColumn
        spacing: 2 * Constants.settingsSection.itemSpacing
        width: root.contentWidth

        ButtonGroup {
            id: showProfilePictureToGroup
        }

        ButtonGroup {
            id: seeProfilePicturesFromGroup
        }

        ButtonGroup {
            id: browserGroup
        }

        StatusListItem {
            id: allowNewContactRequest

            Layout.fillWidth: true
            implicitHeight: 64

            title: qsTr("Receive community messages & requests from non-contacts")

            components: [
                StatusSwitch {
                    id: switch3
                    checked: !root.messagingSettingsStore.messagesFromContactsOnly
                    onCheckedChanged: {
                        // messagesFromContactsOnly needs to be accessed from the module (view),
                        // because otherwise doing `messagesFromContactsOnly = value` only changes the bool property on QML
                        if (root.messagingSettingsStore.messagesFromContactsOnly === checked) {
                            root.messagingSettingsStore.setMessagesFromContactsOnly(!checked)
                        }
                    }
                }
            ]
            onClicked: {
                switch3.checked = !switch3.checked
            }
        }

        StatusListItem {
            id: allowSyncingOnMobileNetwork

            Layout.fillWidth: true
            implicitHeight: 64

            title: qsTr("Message syncing")
            label: root.messagingSettingsStore.syncingOnMobileNetwork
                   ? qsTr("Mobile data and Wi-Fi")
                   : qsTr("Wi-Fi only")
            onClicked: Global.openPopup(syncingOnMobileNetworkPopupComponent)
        }

        Separator {
            Layout.fillWidth: true
        }

        // CONTACTS SECTION
        StatusContactRequestsIndicatorListItem {
            id: contactRequestsIndicator

            objectName: "MessagingView_ContactsListItem_btn"
            Layout.fillWidth: true
            title: qsTr("Contacts, Requests, and Blocked Users")

            onClicked: Global.changeAppSectionBySectionType(Constants.appSection.profile,
                                                            Constants.settingsSubsection.contacts)
        }

        Separator {
            id: separator2
            Layout.fillWidth: true
        }

        // GIF LINK PREVIEWS
        StatusSectionHeadline {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: qsTr("GIF link previews")
        }

        StatusListItem {
            Layout.fillWidth: true
            title: qsTr("Allow show GIF previews")
            objectName: "MessagingView_AllowShowGifs_StatusListItem"
            components: [
                StatusSwitch {
                    id: showGifPreviewsSwitch
                    checked: localAccountSensitiveSettings.gifUnfurlingEnabled
                    onClicked: {
                        localAccountSensitiveSettings.gifUnfurlingEnabled = !localAccountSensitiveSettings.gifUnfurlingEnabled
                    }
                }
            ]
            onClicked: {
                showGifPreviewsSwitch.clicked()
            }
        }

        Separator {
            Layout.fillWidth: true
        }

        // URL UNFRULING
        StatusSectionHeadline {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: qsTr("Website link previews")
        }

        ButtonGroup {
            id: urlUnfurlingGroup
        }

        SettingsRadioButton {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            label: qsTr("Always ask")
            objectName: "MessagingView_AlwaysAsk_RadioButton"
            group: urlUnfurlingGroup
            checked: root.messagingSettingsStore.urlUnfurlingMode === Constants.UrlUnfurlingModeAlwaysAsk
            onClicked: {
                root.messagingSettingsStore.setUrlUnfurlingMode(Constants.UrlUnfurlingModeAlwaysAsk)
            }
        }

        SettingsRadioButton {
            Layout.topMargin: Constants.settingsSection.itemSpacing / 2
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            label: qsTr("Always show previews")
            objectName: "MessagingView_AlwaysShow_RadioButton"
            group: urlUnfurlingGroup
            checked: root.messagingSettingsStore.urlUnfurlingMode === Constants.UrlUnfurlingModeEnableAll
            onClicked: {
                root.messagingSettingsStore.setUrlUnfurlingMode(Constants.UrlUnfurlingModeEnableAll)
            }
        }

        SettingsRadioButton {
            Layout.topMargin: Constants.settingsSection.itemSpacing / 2
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            label: qsTr("Never show previews")
            objectName: "MessagingView_NeverShow_RadioButton"
            group: urlUnfurlingGroup
            checked: root.messagingSettingsStore.urlUnfurlingMode === Constants.UrlUnfurlingModeDisableAll
            onClicked: {
                root.messagingSettingsStore.setUrlUnfurlingMode(Constants.UrlUnfurlingModeDisableAll)
            }
        }
    }

    Component {
        id: syncingOnMobileNetworkPopupComponent

        StatusDialog {
        id: syncingOnMobileNetworkPopup
            width: 420
            padding: Theme.padding
            modal: true
            title: qsTr("Sync messages on mobile data?")
            destroyOnClose: true

            contentItem: ColumnLayout {
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("The Status App uses a lot of data when fetching missed messages. If you have a limited data plan, consider syncing over Wi-Fi only.")
                    wrapMode: Text.WordWrap
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.secondaryAdditionalTextSize
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Theme.radius
                    border.width: 1
                    border.color: Theme.palette.baseColor2
                    color: Theme.palette.baseColor4
                    implicitHeight: infoText.implicitHeight + Theme.padding * 2

                    StatusBaseText {
                        id: infoText
                        anchors.fill: parent
                        anchors.margins: Theme.padding
                        text: qsTr("If you choose to sync over Wi-Fi only, messages sent to you while you are offline will be delivered once you connect to Wi-Fi.")
                        wrapMode: Text.WordWrap
                        color: Theme.palette.baseColor1
                    }
                }
            }

            footer: StatusDialogFooter {
                bottomPadding: Theme.padding + syncingOnMobileNetworkPopup.parent.SafeArea.margins.bottom
                leftButtons: ObjectModel {
                    StatusButton {
                        text: qsTr("Mobile data and Wi-Fi")
                        icon.name: root.messagingSettingsStore.syncingOnMobileNetwork ? "check-circle" : ""
                        onClicked: {
                            root.messagingSettingsStore.setSyncingOnMobileNetwork(true)
                            syncingOnMobileNetworkPopup.close()
                        }
                    }
                }

                rightButtons: ObjectModel {
                    StatusButton {
                        text: qsTr("Wi-Fi only")
                        icon.name: !root.messagingSettingsStore.syncingOnMobileNetwork ? "check-circle" : ""
                        onClicked: {
                            root.messagingSettingsStore.setSyncingOnMobileNetwork(false)
                            syncingOnMobileNetworkPopup.close()
                        }
                    }
                }
            }
        }
    }
}
