import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

import AppLayouts.stores
import AppLayouts.ActivityCenter.helpers

StatusRollArea {
    id: root

    required property bool hasAdmin
    required property bool hasMentions
    required property bool hasReplies
    required property bool hasContactRequests
    required property bool hasMembership
    required property int activeGroup

    signal setActiveGroupRequested(int group)

    bottomPadding: Theme.padding
    showIcon: false
    gradientColor: Theme.palette.baseColor4

    content: RowLayout {
        spacing: 4

        anchors.left: parent.left
        anchors.leftMargin: 12 // By design

        Repeater {
            // NOTE: some entries are hidden until implementation
            model: [ { text: qsTr("All"), group: ActivityCenterTypes.ActivityCenterGroup.All, visible: true, enabled: true },
                { text: qsTr("News"), group: ActivityCenterTypes.ActivityCenterGroup.NewsMessage, visible: true, enabled: true },
                { text: qsTr("Admin"), group: ActivityCenterTypes.ActivityCenterGroup.Admin, visible: root.hasAdmin, enabled: root.hasAdmin },
                { text: qsTr("Mentions"), group: ActivityCenterTypes.ActivityCenterGroup.Mentions, visible: true, enabled: root.hasMentions },
                { text: qsTr("Replies"), group: ActivityCenterTypes.ActivityCenterGroup.Replies, visible: true, enabled: root.hasReplies },
                { text: qsTr("Contact requests"), group: ActivityCenterTypes.ActivityCenterGroup.ContactRequests, visible: true, enabled: root.hasContactRequests },
                { text: qsTr("Transactions"), group: ActivityCenterTypes.ActivityCenterGroup.Transactions, visible: false, enabled: true },
                { text: qsTr("Membership"), group: ActivityCenterTypes.ActivityCenterGroup.Membership, visible: true, enabled: root.hasMembership },
                { text: qsTr("System"), group: ActivityCenterTypes.ActivityCenterGroup.System, visible: false, enabled: true } ]

            StatusFlatButton {
                objectName: "activityCenterGroupButton"
                enabled: modelData.enabled
                visible: modelData.visible
                text: modelData.text
                size: StatusBaseButton.Size.Small
                highlighted: modelData.group === root.activeGroup
                onClicked: root.setActiveGroupRequested(modelData.group)
                onEnabledChanged: if (!enabled && highlighted) root.setActiveGroupRequested(ActivityCenterTypes.ActivityCenterGroup.All)
                Layout.preferredWidth: visible ? implicitWidth : 0
            }
        }

        // Filler
        Item {
            height: root.height
            width: 12 // By design
        }
    }
}
