import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.ActivityCenter.controls
import Models
import Storybook

import StatusQ.Core.Theme

import utils

SplitView {
    id: root

    Logs { id: logs }

    property string badgeIconName: "action-reply"

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            NotificationAvatar {
                anchors.centerIn: parent
                Tracer {
                    visible: avatarEditor.showImplicitSizeArea
                }
                avatarSource: !avatarEditor.isAvatarImageOrLetter ?
                                  (avatarEditor.changeAvatarImage ? "https://i.pravatar.cc/128?img=5" : Assets.png("status-logo-icon")) : ""
                avatarLetterText: avatarEditor.avatarText
                avatarLetterColor: avatarEditor.changeAvatarLetterColor ? "red" : "green"
                isAvatarLetterAcronym: avatarEditor.isAvatarLetterAcronym
                avatarMaxTextLen: 10
                badgeIconName: root.badgeIconName
                density: avatarEditor.density
                circular: avatarEditor.isRoundedAvatar
                includeBadgeInImplicit: avatarEditor.includeBadgeInImplicit
                isAvatarClickable: avatarEditor.isAvatarClickable
                isBadgeClickable: avatarEditor.isBadgeClickable
                onBadgeClicked: logs.logEvent("NotificationAvatar:: Badge clicked!")
                onAvatarClicked: logs.logEvent("NotificationAvatar:: Avatar clicked!")
            }
        }

        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 160
            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            NotificationAvatarEditor {
                id: avatarEditor
                changeBadgeIconVisible: false
            }

            Label {
                text: "Possible Action Icons:"
                font.weight: Font.Medium
            }

            RadioButton {
                text: "Reply"
                checked: true
                onCheckedChanged: badgeIconName = "action-reply"
            }

            RadioButton {
                text: "Mention"
                onCheckedChanged: badgeIconName = "action-mention"
            }

            RadioButton {
                text: "Add"
                onCheckedChanged: badgeIconName = "action-add"
            }

            RadioButton {
                text: "Chat"
                onCheckedChanged: badgeIconName = "action-chat"
            }

            RadioButton {
                text: "Warn"
                onCheckedChanged: badgeIconName = "action-warn"
            }

            RadioButton {
                text: "Coin"
                onCheckedChanged: badgeIconName = "action-coin"
            }

            RadioButton {
                text: "Admin"
                onCheckedChanged: badgeIconName = "action-admin"
            }

            RadioButton {
                text: "Check"
                onCheckedChanged: badgeIconName = "action-check"
            }

            RadioButton {
                text: "Sync"
                onCheckedChanged: badgeIconName = "action-sync"
            }

            RadioButton {
                text: "Sync-Failed"
                onCheckedChanged: badgeIconName = "action-sync-fail"
            }
        }
    }
}
// category: Activity Center
// status: good
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=1135-37804&m=dev
