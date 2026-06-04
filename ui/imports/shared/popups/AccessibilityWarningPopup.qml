import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Controls

import utils

StatusDialog {
    id: root

    // Comma-separated display names of the active third-party accessibility services.
    // Set before calling open().
    property string serviceNames: ""

    signal revealAccepted()

    width: 480
    title: qsTr("Accessibility services active")
    modal: true
    closePolicy: Popup.NoAutoClose

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            wrapMode: Text.WordWrap
            text: qsTr("Accessibility services on your device may access screen content:")
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
            Layout.bottomMargin: Theme.halfPadding
            spacing: Theme.smallPadding
            visible: root.serviceNames.length > 0

            Repeater {
                model: root.serviceNames.split(", ")
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.halfPadding
                    StatusBaseText {
                        text: "\u2022"
                        font.pixelSize: Theme.primaryTextFontSize
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        text: modelData
                        font.pixelSize: Theme.primaryTextFontSize
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.defaultPadding
            Layout.bottomMargin: Theme.padding
            wrapMode: Text.WordWrap
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.additionalTextSize
            textFormat: Text.RichText
            linkColor: Theme.palette.primaryColor1
            text: qsTr("Check your device <a href='accessibility-settings'>Settings &gt; Accessibility</a>.")
            onLinkActivated: (link) => SystemUtils.openAccessibilitySettings()
        }
    }

    footer: StatusDialogFooter {
        dropShadowEnabled: true
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        leftButtons: ObjectModel {
            StatusFlatButton {
                objectName: "btnA11yWarningCancel"
                text: qsTr("Cancel")
                onClicked: root.close()
            }
        }
        rightButtons: ObjectModel {
            StatusButton {
                objectName: "btnA11yWarningReveal"
                type: StatusBaseButton.Type.Danger
                text: qsTr("Reveal anyway")
                onClicked: {
                    root.revealAccepted()
                    root.close()
                }
            }
        }
    }
}
