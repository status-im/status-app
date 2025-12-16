import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

Control {
    id: root

    property alias primartyText: primaryTextField.text
    property alias secondaryText: secondaryTextField.text
    property alias changeIconColor: changeIconColor.checked
    property alias changePrimaryTextColor: changePrimaryTextColor.checked
    property alias changeSecondaryTextColor: changeSecondaryTextColor.checked
    property alias changeSeparatorColor: changeSeparatorColor.checked
    readonly property string iconType: {
        if(iconChat.checked)
            return "chat"
        if(iconCommunities.checked)
            return "communities"
        return ""
    }
    readonly property string separatorType: {
        if(separatorNext.checked)
            return "arrow-next"
        if(separatorArrow.checked)
            return "arrow-right"
        return ""
    }

    property bool  areColorEditorsVisible: true

    background: Rectangle {
        color: "lightgray"
        opacity: 0.2
        radius: 8
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        Label {
            Layout.topMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.bottomMargin: Theme.padding
            text: "CONTEXT ROW EDITOR"
            font.weight: Font.Bold
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Primary text"
        }

        TextField {
            id: primaryTextField
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            text: "CrytpoKitties"
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Secondary text"
        }

        TextField {
            id: secondaryTextField
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            text: "#design"
        }

        Label {
            Layout.leftMargin: Theme.padding
            Layout.topMargin: Theme.halfPadding
            text: "Icon"
            font.weight: Font.Medium
        }

        ColumnLayout {

            Layout.leftMargin: Theme.padding
            RadioButton {
                text: "None"
            }

            RadioButton {
                id: iconCommunities
                text: "Communities"
                checked: true
            }

            RadioButton {
                id: iconChat
                text: "1:1 chat"
            }
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Separator"
            font.weight: Font.Medium
        }

        ColumnLayout {

            Layout.leftMargin: Theme.padding
            RadioButton {
                text: "None"
            }

            RadioButton {
                id: separatorNext
                text: "Arrow-Next"
                checked: true
            }

            RadioButton {
                id: separatorArrow
                text: "Arrow"
            }
        }

        Switch {
            id: changeIconColor
            Layout.leftMargin: Theme.padding
            text: "Change Icon Color"
            visible: root.areColorEditorsVisible
        }

        Switch {
            id: changePrimaryTextColor
            Layout.leftMargin: Theme.padding
            text: "Change Primary Text Color"
            visible: root.areColorEditorsVisible
        }

        Switch {
            id: changeSecondaryTextColor
            Layout.leftMargin: Theme.padding
            text: "Change Secondary Text Color"
            visible: root.areColorEditorsVisible
        }

        Switch {
            id: changeSeparatorColor
            Layout.leftMargin: Theme.padding
            text: "Change Separator Color"
            visible: root.areColorEditorsVisible
        }
    }
}

