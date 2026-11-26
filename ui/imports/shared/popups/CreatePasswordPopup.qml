import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Popups.Dialog

import shared.views

// First password of a profile created without one
StatusDialog {
    id: root

    property var passwordStrengthScoreFunction: (password) => { console.error("passwordStrengthScoreFunction: IMPLEMENT ME") }
    property bool stayLoggedInAvailable: false
    property bool biometricsAvailable: false
    property bool loading: false
    property string errorText

    signal submitted(string password, bool stayLoggedIn, bool enableBiometrics)

    implicitWidth: 480
    title: qsTr("Create profile password")
    closePolicy: root.loading ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
    closeHandler: () => {
        if (!root.loading)
            root.close()
    }

    QtObject {
        id: d

        function submit() : void {
            if (!form.ready || root.loading)
                return
            root.submitted(form.password, form.stayLoggedIn, form.enableBiometrics)
        }
    }

    onOpened: form.forceInputFocus()

    contentItem: StatusScrollView {
        id: scrollView

        contentWidth: availableWidth

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Theme.padding

            CreatePasswordForm {
                id: form
                Layout.fillWidth: true
                titleVisible: false
                introText: qsTr("Can’t be recovered")
                introInfoText: qsTr("The password used for this profile can't be recovered,<br/>to adopt this profile you need to set a new password.")
                passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
                stayLoggedInAvailable: root.stayLoggedInAvailable
                biometricsAvailable: root.biometricsAvailable
                busy: root.loading
                onSubmitRequested: d.submit()
            }
            StatusBaseText {
                objectName: "createPasswordErrorText"
                Layout.fillWidth: true
                visible: !!root.errorText
                text: root.errorText
                color: Theme.palette.dangerColor1
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                objectName: "createPasswordCancelButton"
                text: qsTr("Cancel")
                enabled: !root.loading
                onClicked: root.close()
            }
            StatusButton {
                objectName: "createPasswordConfirmButton"
                text: qsTr("Set password")
                enabled: form.ready
                interactive: !root.loading
                loading: root.loading
                onClicked: d.submit()
            }
        }
    }
}
