import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebView

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import Models
import Storybook

import shared.controls.chat.menuItems

import utils

import AppLayouts.Profile.stores as ProfileStores

import mainui

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    QtObject {
        id: d

        readonly property var sectionsModel: SectionsModel {}

        property bool acVisible

        property int activeSectionType: Constants.appSection.wallet
        property string activeSectionId: "id2"
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Label {
            anchors.centerIn: parent
            visible: secondaryWindow.visible
            text: "Interact with the sidebar in the secondary window"
        }
        Button {
            anchors.centerIn: parent
            text: "Reopen"
            visible: !secondaryWindow.visible
            onClicked: secondaryWindow.visible = true
        }
    }

    Window {
        id: secondaryWindow
        visible: true
        width: 800
        height: 640
        title: "PrimaryNavSidebar"
        color: Theme.palette.baseColor4 // doesn't get the proper StatusQ palette w/o Theme.xxx

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 2
            anchors.leftMargin: sidebar.alwaysVisible ? sidebar.width : 2
            Behavior on anchors.leftMargin {PropertyAnimation {duration: ThemeUtils.AnimationDuration.Fast}}

            WebView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                url: "https://status.app"
            }

            StatusButton {
                icon.name: "more"
                enabled: !sidebar.alwaysVisible
                onClicked: sidebar.open()

                tooltip.text: "Open sidebar"
                tooltip.orientation: StatusToolTip.Orientation.Bottom
            }
            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Active section type/id: %1/\"%2\"".arg(d.activeSectionType).arg(d.activeSectionId)
            }
            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Window size: %1x%2".arg(secondaryWindow.width).arg(secondaryWindow.height)
            }
            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: sidebar.alwaysVisible ? "alwaysVisible: <b>true</b> (%1)".arg("pushes the content; background not dimmed")
                                            : "alwaysVisible: <b>false</b> (%1)".arg("open the sidebar by dragging on the left edge, or click the above button; background dimmed")
            }
            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Sidebar position: %1".arg(sidebar.position)
            }
        }

        PrimaryNavSidebar {
            id: sidebar
            height: parent.height

            sectionsModel: d.sectionsModel

            acVisible: d.acVisible
            acHasUnseenNotifications: ctrlAcHasUnseenNotifications.checked // <- ActivityCenterStore.hasUnseenNotifications
            acUnreadNotificationsCount: ctrlAcUnreadNotificationsCount.value // <- ActivityCenterStore.unreadNotificationsCount

            profileStore: ProfileStores.ProfileStore {
                id: profileStore
                readonly property string pubKey: "0xdeadbeef"
                readonly property string compressedPubKey: "zxDeadBeef"
                readonly property string name: "John Doe"
                readonly property string icon: ModelsData.icons.rarible
                readonly property int colorId: 7
                readonly property bool usesDefaultName: false
                property int currentUserStatus: Constants.currentUserStatus.automatic
            }

            getEmojiHashFn: function(pubKey) { // <- root.utilsStore.getEmojiHash(pubKey)
                if (pubKey === "")
                    return ""

                return["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮","🤷🏻‍♂️", "🤦🏻", "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]
            }
            getLinkToProfileFn: function(pubKey) { // <- root.rootStore.contactsStore.getLinkToProfile(pubKey)
                return Constants.userLinkPrefix + pubKey
            }

            communityPopupMenu: Component {
                StatusMenu {
                    id: communityContextMenu

                    required property var model
                    required property int index

                    readonly property bool isSpectator: model.spectated && !model.joined

                    onClosed: destroy()

                    StatusAction {
                        text: qsTr("Invite People")
                        icon.name: "share-ios"
                        objectName: "invitePeople"
                    }

                    StatusAction {
                        text: qsTr("Community Info")
                        icon.name: "info"
                    }

                    StatusAction {
                        text: qsTr("Community Rules")
                        icon.name: "text"
                    }

                    StatusMenuSeparator {}

                    MuteChatMenuItem {
                        enabled: !model.muted
                        title: qsTr("Mute Community")
                    }

                    StatusAction {
                        enabled: model.muted
                        text: qsTr("Unmute Community")
                        icon.name: "notification"
                    }

                    StatusAction {
                        text: qsTr("Mark as read")
                        icon.name: "check-circle"
                    }

                    StatusAction {
                        text: qsTr("Edit Shared Addresses")
                        icon.name: "wallet"
                        enabled: {
                            if (model.memberRole === Constants.memberRole.owner || communityContextMenu.isSpectator)
                                return false
                            return true
                        }
                    }

                    StatusMenuSeparator { visible: leaveCommunityMenuItem.enabled }

                    StatusAction {
                        id: leaveCommunityMenuItem
                        objectName: "leaveCommunityMenuItem"
                        // allow to leave community for the owner in non-production builds
                        enabled: model.memberRole !== Constants.memberRole.owner || !production
                        text: {
                            if (communityContextMenu.isSpectator)
                                return qsTr("Close Community")
                            return qsTr("Leave Community")
                        }
                        icon.name: communityContextMenu.isSpectator ? "close-circle" : "arrow-left"
                        type: StatusAction.Type.Danger
                    }
                }
            }

            showEnabledSectionsOnly: ctrlShowEnabledSectionsOnly.checked
            marketEnabled: ctrlMarketEnabled.checked
            browserEnabled: ctrlBrowserEnabled.checked
            nodeEnabled: ctrlNodeEnabled.checked
            thirdpartyServicesEnabled: ctrlThirdPartyServices.checked
            showCreateCommunityBadge: ctrlShowCreateCommunityBadge.checked
            profileSectionHasNotification: ctrlSettingsHasNotification.checked

            onItemActivated: function (sectionType, id) {
                logs.logEvent("onItemActivated", ["sectionType", "sectionId"], arguments)
                sectionsModel.setActiveSection(id)
                d.activeSectionType = sectionType
                d.activeSectionId = id
            }
            onActivityCenterRequested: function (shouldShow) {
                logs.logEvent("onActivityCenterRequested", ["shouldShow"], arguments)
                d.acVisible = shouldShow
            }
            onSetCurrentUserStatusRequested: function (status) {
                profileStore.currentUserStatus = status
                logs.logEvent("onSetCurrentUserStatusRequested", ["status"], arguments) // <- root.rootStore.setCurrentUserStatus(status)
            }
            onViewProfileRequested: logs.logEvent("onViewProfileRequested", ["pubKey"], arguments) // <- Global.openProfilePopup(pubKey)
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 330
        SplitView.preferredHeight: 330
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        RowLayout {
            anchors.fill: parent

            ColumnLayout {
                Label { text: "Sections config:" }
                Switch {
                    id: ctrlShowEnabledSectionsOnly
                    text: "Show enabled sections only"
                    checked: true
                }
                Switch {
                    id: ctrlMarketEnabled
                    text: "Market enabled"
                    checked: true
                }
                Switch {
                    id: ctrlBrowserEnabled
                    text: "Browser enabled"
                    checked: true
                }
                Switch {
                    id: ctrlNodeEnabled
                    text: "Node mgmt enabled"
                    checked: false
                }
                Switch {
                    id: ctrlThirdPartyServices
                    text: "Third party services enabled"
                    checked: true
                }
                Switch {
                    id: ctrlSettingsHasNotification
                    text: "Settings has notification"
                }
                Switch {
                    id: ctrlShowCreateCommunityBadge
                    text: "Show create community badge"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Label { text: "Activity Center:" }
                Switch {
                    id: ctrlAcHasUnseenNotifications
                    text: "Has unseen notifications"
                    checked: true
                }
                RowLayout {
                    Label { text: "Notifications count:" }
                    SpinBox {
                        id: ctrlAcUnreadNotificationsCount
                        from: 0
                        to: 101
                        value: 4
                        editable: true
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=4185-86833&t=lNokXnXl5AHjxHan-0
// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=4185-86833&t=hN6bacud6gPREDcH-0
