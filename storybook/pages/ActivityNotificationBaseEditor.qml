import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

ColumnLayout {
    id: root

    spacing: 8
    implicitWidth: parent.width

    property bool showBaseEditorFields: true

    property QtObject notificationBaseMock: QtObject {
        property string id: "notificationID-111"
        property string chatId: ""
        property string author: ""
        property int notificationType: 0
        property string communityId: "communityID-222"
        property double previousTimestamp: 0
        readonly property string title: title.text
        readonly property string description: desc.text
        readonly property double timestamp: timestamp.text
        readonly property bool read: read.checked
        readonly property bool dismissed: dismissed.checked
        readonly property bool accepted: accepted.checked
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 8

        visible: root.showBaseEditorFields
        text: "Title:"
        font.weight: Font.Bold
    }

    TextField {
        id: title
        Layout.fillWidth: true

        visible: root.showBaseEditorFields
        text: "Some title"
    }

    Label {
        Layout.topMargin: 8
        Layout.fillWidth: true

        visible: root.showBaseEditorFields
        text: "Description:"
        font.weight: Font.Bold
    }

    TextField {
        id: desc
        Layout.fillWidth: true

        visible: root.showBaseEditorFields
        text: "Some notification description"
    }

    Label {
        Layout.topMargin: 8
        Layout.fillWidth: true
        text: "Timestamp:"
        font.weight: Font.Bold
    }

    TextField {
        id: timestamp
        Layout.fillWidth: true
        text: Date.now()
    }

    Label {
        Layout.topMargin: 8
        Layout.fillWidth: true
        text: "Notification Status:"
        font.weight: Font.Bold
    }

    ButtonGroup { id: read_dismissed_accepted }

    RadioButton {
        id: read
        Layout.fillWidth: true
        text: "Read"
    }

    RadioButton {
        id: dismissed
        Layout.fillWidth: true
        text: "Dismissed"
        checked: true
    }

    RadioButton {
        id: accepted
        Layout.fillWidth: true
        text: "Accepted"
    }
}
