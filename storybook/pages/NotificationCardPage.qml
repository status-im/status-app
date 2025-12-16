import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.ActivityCenter.controls
import Models
import Storybook

import StatusQ.Core.Theme
import StatusQ.Components

import utils

SplitView {
    id: root

    Logs { id: logs }

    QtObject {
        id: d

        readonly property var oneAttachment: ["https://picsum.photos/320/240?10"]
        readonly property var threeAttachments: [
            "https://picsum.photos/320/240?1",
            "https://picsum.photos/320/240?2",
            "https://picsum.photos/320/240?9"
        ]
        readonly property var sevenAttachments: [
            "https://picsum.photos/320/240?3",
            "https://picsum.photos/320/240?4",
            "https://picsum.photos/320/240?5",
            "https://picsum.photos/320/240?6",
            "https://picsum.photos/320/240?7",
            "https://picsum.photos/320/240?8",
            "https://picsum.photos/320/240?1"
        ]
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillHeight: true
            SplitView.fillWidth: true

            NotificationCard {
                Tracer {
                    visible: baseEditor.showTracer
                }
                anchors.centerIn: parent
                width: baseEditor.cardWidth

                // Card states related
                unread: undreadCheck.checked
                selected: selectedCheck.checked

                // Avatar related
                avatarSource: avatarEditor.changeAvatarImage ? "https://i.pravatar.cc/128?img=5" : Assets.png("status-logo-icon")
                badgeIconName: avatarEditor.changeBadgeIcon ? "action-mention" : "action-reply"
                isCircularAvatar: avatarEditor.isRoundedAvatar

                // Header row related
                title: headerEditor.titleField
                chatKey: headerEditor.chatkeyTextField
                isContact: headerEditor.isContactCheck
                trustIndicator: headerEditor.isTrustedCheck ? StatusContactVerificationIcons.TrustedType.Verified :
                                                                headerEditor.isUntTrustCheck ? StatusContactVerificationIcons.TrustedType.Untrustworthy :
                                                                                               StatusContactVerificationIcons.TrustedType.None
                // Context row related
                primaryText: contextEditor.primartyText
                iconName: contextEditor.iconType
                secondaryText: contextEditor.secondaryText
                separatorIconName: contextEditor.separatorType

                // Action text
                actionText: actionText.text

                // Content block related
                preImageSource: contentEditor.preImageVisible ? "https://picsum.photos/320/240?6" : ""
                preImageRadius: contentEditor.preImageWithRadius ? 8 : 0
                content: contentEditor.content
                attachments: contentEditor.oneAttachment ? d.oneAttachment :
                                                           contentEditor.threeAttachments ? d.threeAttachments :
                                                                                            contentEditor.sevenAttachments ? d.sevenAttachments : []

                // Timestamp related
                timestamp: dateText.text

                // Interactions
                onClicked: logs.logEvent("NotificationCard::onClicked --> Card clicked")
            }
        }

        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 160
            logsView.logText: logs.logText
        }
    }

    ScrollView {
        id: scroll
        SplitView.minimumWidth: 350
        SplitView.preferredWidth: 350
        clip: true

        Pane {
            Theme.padding: Theme.defaultPadding

            ColumnLayout {
                width: scroll.width

                Label {
                    Layout.topMargin: Theme.padding
                    Layout.bottomMargin: Theme.padding
                    text: "GENERAL CARD STATES"
                    font.weight: Font.Bold
                }

                CheckBox {
                    id: undreadCheck
                    text: "Unread?"
                    checked: true
                }

                CheckBox {
                    id: selectedCheck
                    text: "Selected?"
                    checked: true
                }

                Label {
                    Layout.topMargin: Theme.padding
                    Layout.bottomMargin: Theme.padding
                    text: "OTHER CARD PROPS"
                    font.weight: Font.Bold
                }

                Label {
                    text: "Action text:"
                }

                TextField {
                    id: actionText
                    Layout.fillWidth: true
                    Layout.rightMargin: 8
                    text: "New contact request"
                }

                Label {
                    text: "Date:"
                }

                TextField {
                    id: dateText
                    Layout.fillWidth: true
                    Layout.rightMargin: 8
                    text: "1759305614000"
                }

                NotificationCardBaseEditor {
                    id: baseEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true

                    minCardWidth: 308
                    maxCardWidth: 550
                }

                NotificationAvatarEditor {
                    id: avatarEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                    isFullContentAvailable: false
                }

                NotificationHeaderRowEditor {
                    id: headerEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                    areColorEditorsVisible: false
                }

                NotificationContextRowEditor {
                    id: contextEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                    areColorEditorsVisible: false

                }

                NotificationContentBlockEditor {
                    id: contentEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                    fullEditorVisible: false
                }
            }
        }
    }
}
// category: Activity Center
// status: good
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=1135-37804&m=dev
