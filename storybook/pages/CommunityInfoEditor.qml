import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import utils

ColumnLayout {
    id: root

    property string name: "Socks"
    property string description: "We like the sock. A community of Unisocks wearers we like the sock.\n\nUnisocks wearers we like the sock."

    property int membersCount: 184
    property bool amISectionAdmin: true
    property bool isCommunityEditable: true
    property color color: "orchid"
    property url image: Assets.png("tokens/UNI")
    property bool colorVisible: false
    property url banner: ctrlCommunityBanner.checked ? Assets.png("settings/communities") : ""
    property bool adminControlsEnabled: true

    ColumnLayout {
        Label {
            Layout.fillWidth: true
            text: "Name"
        }
        TextField {
            background: Rectangle { border.color: 'lightgrey' }
            Layout.preferredWidth: 200
            text: root.name
            onTextChanged: root.name = text
        }
    }

    ColumnLayout {
        Label {
            Layout.fillWidth: true
            text: "Description"
        }
        TextArea {
            background: Rectangle { border.color: 'lightgrey' }
            Layout.preferredWidth: 200
            Layout.preferredHeight: implicitHeight
            text: root.description
            onTextChanged: root.description = text
            wrapMode: TextEdit.Wrap
        }
    }

    ColumnLayout {
        Label {
            Layout.fillWidth: true
            text: "Community members:"
        }

        Slider {
            value: root.membersCount
            from: 0
            to: 3000
            onValueChanged: root.membersCount = value
        }
    }

    ColumnLayout {
        visible: root.colorVisible
        Label {
            Layout.fillWidth: true
            text: "Community color:"
        }

        RadioButton {
            checked: true
            text: "Orchid"
            onCheckedChanged: if(checked) root.color = "orchid"
        }
        RadioButton {
            text: "Blue"
            onCheckedChanged: if(checked) root.color = "blue"
        }
        RadioButton {
            text: "Orange"
            onCheckedChanged: if(checked) root.color = "orange"
        }
    }

    ColumnLayout {
        Label {
            Layout.fillWidth: true
            text: "Community image:"
        }

        RadioButton {
            checked: true
            text: qsTr("UNI")
            onCheckedChanged: if(checked) root.image = Assets.png("tokens/UNI")
        }
        RadioButton {
            text: qsTr("SOCKS")
            onCheckedChanged: if(checked) root.image = Assets.png("tokens/SOCKS")
        }
        RadioButton {
            text: qsTr("Status")
            onCheckedChanged: if(checked) root.image = Assets.png("tokens/SNT")
        }
    }

    RowLayout {
        visible: root.adminControlsEnabled
        Label {
            text: "Is community admin:"
        }

        CheckBox {
            checked: root.amISectionAdmin
            onCheckedChanged: root.amISectionAdmin = checked
        }
    }
    RowLayout {
        visible: root.adminControlsEnabled
        Label {
            text: "Is community editable:"
        }

        CheckBox {
            checked: root.isCommunityEditable
            onCheckedChanged: root.isCommunityEditable = checked
        }
    }
    ColumnLayout {
        Label {
            text: "Banner"
        }

        RadioButton {
            checked: true
            text: "No banner"
        }
        RadioButton {
            id: ctrlCommunityBanner
            text: "Communities"
        }
    }
}
