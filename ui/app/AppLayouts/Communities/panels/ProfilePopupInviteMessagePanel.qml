import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

import utils
import shared
import shared.panels
import shared.views
import shared.status

ColumnLayout {
    id: root
    objectName: "CommunityProfilePopupInviteMessagePanel_ColumnLayout"

    property var contactsModel
    property var pubKeys: ([])

    property alias inviteMessage: messageInput.text

    spacing: Theme.padding

    QtObject {
        id: d

        readonly property int maxMsgLength: 140
        readonly property int msgHeight: 108
    }

    StatusInput {
        id: messageInput
        input.edit.objectName: "CommunityProfilePopupInviteMessagePanel_MessageInput"
        label: qsTr("Invitation Message")
        charLimit: d.maxMsgLength
        placeholderText: qsTr("The message a contact will get with community invitation")
        leftPadding: Theme.padding
        rightPadding: Theme.padding
        input.multiline: true
        input.implicitHeight: d.msgHeight
        input.verticalAlignment: TextEdit.AlignTop
        Layout.minimumHeight: 150 // TODO: implicitHeight is not calculated well from input.implicitHeight
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
    }

    StatusModalDivider {
        Layout.fillWidth: true
    }

    StyledText {
        text: qsTr("Invites will be sent to:")
        font.pixelSize: Theme.primaryTextFontSize
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
    }

    PickedContacts {
        id: existingContacts

        contactsModel: root.contactsModel
        itemSpacing: Theme.bigPadding
        pubKeys: root.pubKeys
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: Theme.halfPadding
        Layout.rightMargin: Theme.halfPadding
    }
}
