import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import utils

/**
  * One destination row of the share picker: avatar, name, per-type subtitle
  * (contact: elided compressed key + online dot; group: members count;
  * community channel: "#name" + community name) and a trailing checkbox.
  * Row click and checkbox click both emit toggled(chatId); the checked state
  * is owned by the host.
  */
StatusListItem {
    id: root

    required property string chatId
    required property string name
    required property string color
    required property int colorId
    required property string icon
    required property string emoji
    required property int chatType
    required property int membersCount
    required property int onlineStatus
    required property string sectionName

    property bool checked: false
    // False while the selection is full: the row can't be ticked, only unticked.
    property bool selectable: true

    signal toggled(string chatId)

    QtObject {
        id: d

        readonly property bool isContact: root.chatType === Constants.chatType.oneToOne
        readonly property bool isGroup: root.chatType === Constants.chatType.privateGroupChat
        readonly property bool isChannel: root.chatType === Constants.chatType.communityChat
    }

    implicitHeight: 56
    leftPadding: 12
    rightPadding: 12

    title: d.isChannel ? "#" + root.name : root.name
    subTitle: {
        if (d.isContact)
            return Utils.getElidedCompressedPk(root.chatId)
        if (d.isGroup)
            return qsTr("%n member(s)", "", root.membersCount)
        return root.sectionName
    }
    highlighted: root.checked
    enabled: root.checked || root.selectable
    opacity: enabled ? 1 : ThemeUtils.disabledOpacity
    bgColor: {
        if (root.checked)
            return Theme.palette.primaryColor3
        if (sensor.containsMouse)
            return Theme.palette.baseColor2
        return Theme.palette.statusListItem.backgroundColor
    }

    statusListItemIcon {
        name: root.name
        active: true
        badge.visible: d.isContact
        badge.color: root.onlineStatus === Constants.onlineStatus.online ? Theme.palette.successColor1 : Theme.palette.baseColor1
        badge.border.color: root.bgColor
    }
    asset.width: 36
    asset.height: 36
    asset.color: root.color ? root.color : Utils.colorForColorId(Theme.palette, root.colorId)
    asset.name: root.icon
    asset.emoji: root.emoji
    asset.charactersLen: 2

    components: [
        StatusCheckBox {
            objectName: "shareDestinationCheckBox"
            checkable: false
            checked: root.checked
            leftSide: false
            onClicked: root.toggled(root.chatId)
        }
    ]

    onClicked: root.toggled(root.chatId)
}
