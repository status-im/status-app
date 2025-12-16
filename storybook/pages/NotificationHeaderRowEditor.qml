import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme


Control {
    id: root

    property alias titleField: titleField.text
    property alias chatkeyTextField: chatkeyTextField.text
    property alias isContactCheck: isContactCheck.checked
    property alias isTrustedCheck: isTrustedCheck.checked
    property alias isNoneCheck: isNoneCheck.checked
    property alias isUntTrustCheck: isUntTrustCheck.checked
    property alias changeTitleColor: changeTitleColor.checked
    property alias changeKeyColor: changeKeyColor.checked

    property bool  areColorEditorsVisible: true

    background: Rectangle {
        color: "lightgray"
        opacity: 0.2
        radius: 8
    }

    contentItem: ColumnLayout {

        Label {
            Layout.topMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.bottomMargin: Theme.padding
            text: "HEADER ROW EDITOR"
            font.weight: Font.Bold
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Title"
        }

        TextField {
            id: titleField
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            text: "anna.eth"
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Chat key"
        }

        TextField {
            id: chatkeyTextField
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            text: "zQ3saaaedswar2hFSf8wkhHbPsw94NAL5rSggHSYRPfL222TF"
        }

        CheckBox {
            id: isContactCheck
            Layout.leftMargin: Theme.padding
            text: "Is Contact?"
            checked: true
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Trust state:"
        }

        RadioButton {
            id: isNoneCheck

            Layout.leftMargin: Theme.padding
            text: "None"
            checked: true
        }

        RadioButton {
            id: isTrustedCheck

            Layout.leftMargin: Theme.padding
            text: "Trusted"
        }

        RadioButton {
            id: isUntTrustCheck

            Layout.leftMargin: Theme.padding
            text: "Untrustworthy?"
        }

        Switch {
            id: changeTitleColor
            Layout.leftMargin: Theme.padding
            text: "Change Title Color"
            visible: root.areColorEditorsVisible
        }

        Switch {
            id: changeKeyColor
            Layout.leftMargin: Theme.padding
            text: "Change Key Color"
            visible: root.areColorEditorsVisible
        }
    }
}

