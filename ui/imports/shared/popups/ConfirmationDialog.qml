import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    property var executeConfirm
    property string confirmButtonObjectName: ""
    property string btnType: "warn"
    property string cancelBtnType: "warn"
    property string confirmButtonLabel: qsTr("Confirm")
    property string cancelButtonLabel: qsTr("Cancel")
    property string confirmationText: qsTr("Are you sure you want to do this?")
    property bool showCancelButton: false
    property alias checkbox: checkbox

    property StatusModalHeaderSettings headerSettings: StatusModalHeaderSettings {
        title: qsTr("Confirm your action")
    }

    width: 480
    margins: contentItem.Theme.padding

    title: headerSettings.title
    focus: visible
    standardButtons: Dialog.NoButton

    signal confirmButtonClicked()
    signal cancelButtonClicked()

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            Layout.bottomMargin: checkbox.visible ? 0: Theme.padding

            text: root.confirmationText
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
            color: Theme.palette.directColor1
        }

        StatusCheckBox {
            id: checkbox
            visible: false

            Layout.fillWidth: true
            Layout.bottomMargin: Theme.padding

            text: qsTr("Do not show this again")
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                id: cancelButton
                visible: root.showCancelButton
                text: root.cancelButtonLabel
                type: root.cancelBtnType === "warn"
                      ? StatusBaseButton.Type.Danger
                      : StatusBaseButton.Type.Normal
                onClicked: root.cancelButtonClicked()
            }
            StatusButton {
                id: confirmButton
                objectName: root.confirmButtonObjectName
                Layout.maximumWidth: root.availableWidth / 2
                type: root.btnType === "warn"
                      ? StatusBaseButton.Type.Danger
                      : StatusBaseButton.Type.Normal
                text: root.confirmButtonLabel
                focus: true
                Keys.onReturnPressed: confirmButton.clicked()
                onClicked: {
                    if (root.executeConfirm
                            && typeof root.executeConfirm === "function")
                        root.executeConfirm()
                    root.confirmButtonClicked()
                }
            }
        }
    }
}
