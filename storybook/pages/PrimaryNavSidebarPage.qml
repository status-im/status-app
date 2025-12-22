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

import AppLayouts.Profile.helpers

import mainui
import mainui.adaptors

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
        color: Theme.palette.statusAppLayout.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 2
            anchors.leftMargin: sidebar.alwaysVisible ? sidebar.width + Theme.halfPadding : 2
            Behavior on anchors.leftMargin {PropertyAnimation {duration: ThemeUtils.AnimationDuration.Fast}}

            WebView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.verticalStretchFactor: 2
                url: "https://status.app"
                visible: d.activeSectionType === Constants.appSection.browser
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

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        PrimaryNavSidebar {
            id: sidebar
            height: parent.height

            PrimaryNavSidebarAdaptor {
                id: sidebarAdaptor
                sectionsModel: d.sectionsModel
                showEnabledSectionsOnly: ctrlShowEnabledSectionsOnly.checked
                marketEnabled: ctrlMarketEnabled.checked
                browserEnabled: ctrlBrowserEnabled.checked
                nodeEnabled: ctrlNodeEnabled.checked
            }

            regularItemsModel: sidebarAdaptor.regularItemsModel
            communityItemsModel: sidebarAdaptor.communityItemsModel
            bottomItemsModel: sidebarAdaptor.bottomItemsModel

            acVisible: d.acVisible
            acHasUnseenNotifications: ctrlAcHasUnseenNotifications.checked // <- ActivityCenterStore.hasUnseenNotifications
            acUnreadNotificationsCount: ctrlAcUnreadNotificationsCount.value // <- ActivityCenterStore.unreadNotificationsCount

            selfContactDetails: ContactDetails {
                publicKey: "0xdeadbeef"
                compressedPubKey: "zxDeadBeef"
                displayName: "John Doe"
                icon: ModelsData.icons.rarible
                colorId: 7
                usesDefaultName: false
                onlineStatus: Constants.currentUserStatus.automatic
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

                    readonly property bool isSpectator: model.spectated && !model.joined

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

            thirdpartyServicesEnabled: ctrlThirdPartyServices.checked
            showCreateCommunityBadge: ctrlShowCreateCommunityBadge.checked
            profileSectionHasNotification: ctrlSettingsHasNotification.checked

            onItemActivated: function (sectionType, sectionId) {
                logs.logEvent("onItemActivated", ["sectionType", "sectionId"], arguments)
                d.sectionsModel.setActiveSection(sectionId)
                d.activeSectionType = sectionType
                d.activeSectionId = sectionId
            }
            onActivityCenterRequested: function (shouldShow) {
                logs.logEvent("onActivityCenterRequested", ["shouldShow"], arguments)
                d.acVisible = shouldShow
            }
            onSetCurrentUserStatusRequested: function (status) {
                selfContactDetails.onlineStatus = status
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
// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=3948-44690&m=dev
