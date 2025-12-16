import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme


Control {
    id: root

    property alias preImageVisible: preImageVisible.checked
    property alias preImageWithRadius: preImageWithRadius.checked
    property alias content: textField.text
    property alias maxCharsContent: maxCharsContent.value
    property alias areImagesClickable: areImagesClickable.checked
    property alias changeImageCursorShape: changeImageCursorShape.checked
    property alias noAttachments: noAttachments.checked
    property alias oneAttachment: oneAttachment.checked
    property alias threeAttachments: threeAttachments.checked
    property alias sevenAttachments: sevenAttachments.checked

    property bool fullEditorVisible: true

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
            text: "CONTENT BLOCK"
            font.weight: Font.Bold
        }

        CheckBox {
            id: preImageVisible
            Layout.leftMargin: Theme.padding
            text: "Is Pre-Image?"
            checked: true
        }

        CheckBox {
            id: preImageWithRadius
            Layout.leftMargin: Theme.padding
            text: "Is Pre-Image With Radius?"
            checked: true
        }


        Label {
            Layout.leftMargin: Theme.padding
            text: "Text Content:"
        }

        TextField {
            id: textField
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            text: "hey, <a href='status:user:robert'>@robertf.ox.eth</a>, " +
                  "Do we still plan to ship this with v2.1 or postpone to the next release cycle?"
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "Max Chars [120 - 250]:"
            visible: root.fullEditorVisible
        }

        Slider {
            id: maxCharsContent
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            stepSize: 1
            from: 120
            to: 250
            value: from
            visible: root.fullEditorVisible
        }

        CheckBox {
            id: areImagesClickable
            Layout.leftMargin: Theme.padding
            text: "Are Images Clickable?"
            checked: false
            visible: root.fullEditorVisible
        }

        Switch {
            id: changeImageCursorShape
            Layout.leftMargin: Theme.padding
            text: "Change Image Cursor Shape"
            checked: false
            visible: root.fullEditorVisible
        }

        Label {
            Layout.leftMargin: Theme.padding
            text: "How Many Attachments?"
        }

        RadioButton {
            id: noAttachments
            Layout.leftMargin: Theme.padding
            text: "None"
        }

        RadioButton {
            id: oneAttachment
            Layout.leftMargin: Theme.padding
            text: "One"
            checked: true
        }

        RadioButton {
            id: threeAttachments
            Layout.leftMargin: Theme.padding
            text: "Three"
        }

        RadioButton {
            id: sevenAttachments
            Layout.leftMargin: Theme.padding
            text: "Seven"
        }
    }
}
