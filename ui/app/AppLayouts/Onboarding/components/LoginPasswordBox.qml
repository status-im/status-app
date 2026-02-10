import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Core.Backpressure

import AppLayouts.Onboarding.controls

import utils // for Constants

Control {
    id: root

    required property bool isBiometricsLogin
    required property bool biometricsSuccessful
    required property bool biometricsFailed

    property string validationError
    property string detailedError
    onValidationErrorChanged: if (!validationError) detailedError = ""

    property alias password: txtPassword.text
    signal passwordEditedManually()

    signal detailedErrorPopupRequested()

    signal biometricsRequested()
    signal loginRequested(string password)

    function clear() {
        txtPassword.clear()
    }

    function forceActiveFocus() {
        txtPassword.forceActiveFocus()
    }

    function clearInputFocus() {
        if (!txtPassword.activeFocus) {
            return
        }

        txtPassword.focus = false
        Qt.inputMethod.hide()
    }

    padding: 0
    background: null
    spacing: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.bigPadding
        LoginPasswordInput {
            Layout.fillWidth: true
            id: txtPassword
            objectName: "loginPasswordInput"
            isBiometricsLogin: root.isBiometricsLogin
            biometricsSuccessful: root.biometricsSuccessful
            biometricsFailed: root.biometricsFailed
            hasError: !!root.validationError
            onTextEdited: root.passwordEditedManually()
            onBiometricsRequested: root.biometricsRequested()
            onAccepted: root.loginRequested(text)
        }
        StatusBaseText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.validationError
            color: Theme.palette.dangerColor1
            horizontalAlignment: Qt.AlignRight
            font.pixelSize: Theme.tertiaryTextFontSize
            linkColor: hoveredLink ? Theme.palette.hoverColor(color) : color
            HoverHandler {
                cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
            }
            onLinkActivated: function(link) {
                if (link.startsWith("#password"))
                    forgottenPassInstructionsPopupComp.createObject(root).open()
                else
                    root.detailedErrorPopupRequested()
            }
        }
        StatusButton {
            Layout.topMargin: 20
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 44
            objectName: "loginButton"
            text: qsTr("Log In")
            enabled: {
                if (root.isBiometricsLogin && root.biometricsSuccessful)
                    return false
                return txtPassword.text !== ""
            }

            onClicked: root.loginRequested(txtPassword.text)
        }
    }

    onVisibleChanged: {
        if (!visible) {
            clearInputFocus()
        }
    }

    onEnabledChanged: {
        if (!enabled) {
            clearInputFocus()
        }
    }

    Component {
        id: forgottenPassInstructionsPopupComp
        StatusDialog {
            id: forgottenPassInstructionsPopup
            width: 480
            padding: 20
            title: qsTr("Forgot your password?")
            destroyOnClose: true

            footer: StatusDialogFooter {
                rightButtons: ObjectModel {
                    StatusButton {
                        text: qsTr("Copy instructions")
                        icon.name: "copy"
                        onClicked: {
                            let textToCopy = ""
                            for (let i = 0; i < instructionsColumn.children.length; i++) {
                                if (instructionsColumn.children[i].text)
                                    textToCopy += StringUtils.plainText(instructionsColumn.children[i].text) + "\n"
                            }

                            ClipboardUtils.setText(textToCopy)
                            icon.name = "tiny/checkmark"
                            icon.color = Theme.palette.successColor1

                            Backpressure.debounce(forgottenPassInstructionsPopup, 1500, () => forgottenPassInstructionsPopup.close())()
                        }
                    }
                }
            }

            contentItem: ColumnLayout {
                spacing: 20
                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("To recover your profile and data follow these steps:")
                }
                OnboardingFrame {
                    Layout.fillWidth: true
                    cornerRadius: Theme.radius
                    padding: Theme.padding
                    dropShadow: false
                    contentItem: ColumnLayout {
                        id: instructionsColumn
                        spacing: 4
                        StatusBaseText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: qsTr("1. Copy backup file")
                            font.weight: Font.DemiBold
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.padding
                            wrapMode: Text.Wrap
                            text: qsTr("Save your Status profile backup file to a different folder, as it will be erased when you reinstall Status. " +
                                       "If you have multiple profiles, save all their backup files.")
                            linkColor: !!hoveredLink ? Theme.palette.primaryColor1 : color
                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                            HoverHandler {
                                cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
                            }
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            Layout.topMargin: 20
                            wrapMode: Text.Wrap
                            text: qsTr("2. Reinstall the Status app")
                            font.weight: Font.DemiBold
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.padding
                            wrapMode: Text.Wrap
                            text: qsTr("Re-download the app from %1 %2").arg("<a href='#'>status.app</a>").arg("🔗")
                            linkColor: !!hoveredLink ? Theme.palette.primaryColor1 : color
                            onLinkActivated: Qt.openUrlExternally(Constants.externalStatusLinkWithHttps)
                            HoverHandler {
                                cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
                            }
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            Layout.topMargin: 20
                            wrapMode: Text.Wrap
                            text: qsTr("3. Restore your Status profile(s)")
                            font.weight: Font.DemiBold
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.padding
                            wrapMode: Text.Wrap
                            text: qsTr("If you have multiple profiles, repeat for each one:" +
                                       "<ul>" +
                                       "<li>On the Welcome screen, open the profile menu → Log in." +
                                       "<li>Select Log in with Recovery Phrase." +
                                       "<li>Enter your recovery phrase." +
                                       "<li>Create a new password." +
                                       "<li>Import the backup file from Step 1, or skip and import later from <i>Settings > On-device backup</i>.")
                        }
                    }
                }
            }
        }
    }
}
