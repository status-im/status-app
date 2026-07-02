import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

StatusAdaptiveDialog {
    id: root

    property var executeConfirm
    property string confirmButtonObjectName: ""
    property string btnType: "warn"
    property string cancelBtnType: "warn"
    property string confirmButtonLabel: qsTr("Confirm")
    property string cancelButtonLabel: qsTr("Cancel")
    property string confirmationText: qsTr("Are you sure you want to do this?")
    property bool showCancelButton: false
    property bool doNotShowAgainOptionVisible: false
    property bool doNotShowAgainChecked: false

    property StatusModalHeaderSettings headerSettings: StatusModalHeaderSettings {
        title: qsTr("Confirm your action")
    }

    title: headerSettings.title
    focus: visible

    signal confirmButtonClicked()
    signal cancelButtonClicked()

    contentComponent: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            Layout.bottomMargin: root.doNotShowAgainOptionVisible ? 0 : Theme.padding

            text: root.confirmationText
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
            color: Theme.palette.directColor1
        }

        StatusCheckBox {
            id: doNotShowAgainCheckBox

            objectName: "confirmationDialogDoNotShowAgainCheckBox"

            Layout.fillWidth: true
            Layout.bottomMargin: Theme.padding
            visible: root.doNotShowAgainOptionVisible
            checked: root.doNotShowAgainChecked
            text: qsTr("Do not show this again")
            onToggled: root.doNotShowAgainChecked = checked
        }
    }

    footerRightButtons: ObjectModel {
        StatusFlatButton {
            id: cancelButton

            objectName: "confirmationDialogCancelButton"
            visible: root.showCancelButton
            text: root.cancelButtonLabel
            type: root.cancelBtnType === "warn" ? StatusBaseButton.Type.Danger : StatusBaseButton.Type.Normal
            onClicked: root.cancelButtonClicked()
        }
        StatusButton {
            id: confirmButton
            objectName: root.confirmButtonObjectName
            Layout.maximumWidth: root.width / 2
            type: root.btnType === "warn" ? StatusBaseButton.Type.Danger : StatusBaseButton.Type.Normal
            text: root.confirmButtonLabel
            focus: true
            Keys.onReturnPressed: confirmButton.clicked()
            onClicked: {
                if (root.executeConfirm && typeof root.executeConfirm === "function")
                    root.executeConfirm()
                root.confirmButtonClicked()
            }
        }
    }
}
