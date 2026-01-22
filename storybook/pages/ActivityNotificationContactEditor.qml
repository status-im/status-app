import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

ColumnLayout {
    spacing: 8
    width: parent.width

    property QtObject contactDetailsMock: QtObject {
        readonly property string localNickname: nickname.text
        readonly property string name: contactName.text
        readonly property string displayName: contactName.text
        readonly property string alias: contactAlias.text
        readonly property string compressedPubKey: compressedPK.text
        readonly property string thumbnailImage: ""
        readonly property bool isContact: isContact.checked
        readonly property int trustStatus: isTrusted.checked ? 0 /*Not verified*/ : 2 /*Untrusted*/
        readonly property bool added: isContactAdded.checked
        readonly property bool isContactRequestReceived: isRequestReceived.checked
        readonly property bool isBlocked: false
        readonly property bool ensVerified: false
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: "Local Nickname:"
        font.weight: Font.Bold
    }

    TextField {
        id: nickname
        Layout.fillWidth: true
        text: "anna.eth"
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: "Contact Name:"
        font.weight: Font.Bold
    }

    TextField {
        id: contactName
        Layout.fillWidth: true
        text: "Anna"
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: "Alias:"
        font.weight: Font.Bold
    }

    TextField {
        id: contactAlias
        Layout.fillWidth: true
        text: "ui-dev"
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 8
        text: "Compressed PK:"
        font.weight: Font.Bold
    }

    TextField {
        id: compressedPK
        Layout.fillWidth: true
        text: "zQ3...Ww4PG2"
    }

    Switch {
        id: isContact
        text: "Is Contact?"
        checked: true
    }

    Switch {
        id: isTrusted
        text: "Is Trusted?"
        checked: true
    }


    Switch {
        id: isContactAdded
        text: "Is Contact Added?"
        checked: true
    }

    Switch {
        id: isRequestReceived
        text: "Is Contact Request Received?"
        checked: true
    }
}
