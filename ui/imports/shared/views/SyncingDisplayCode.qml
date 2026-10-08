import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import shared.controls
import shared.panels
import utils

ColumnLayout {
    id: root

    property int secondsTimeout: 5 * 60
    property string connectionStringLabel: ""
    property string connectionString: ""
    property string importCodeInstructions : ""
    property string codeExpiredMessage: ""

    signal requestConnectionString()

    function start() {
        d.qrBlurred = true
        d.codeExpired = false
        d.secondsLeft = root.secondsTimeout
        expireTimer.start()
    }

    spacing: 0

    QtObject {
        id: d

        property int secondsLeft: root.secondsTimeout
        property int secondsRatio: 1 // This property can be used to speed up testing of syncCode expiration
        property bool qrBlurred: true
        property bool codeExpired: false

        onCodeExpiredChanged: {
            if (codeExpired)
                syncCodeInput.showPassword = false
        }
    }

    Timer {
        id: expireTimer
        interval: root.secondsTimeout * 1000 / d.secondsRatio
        onTriggered: {
            d.codeExpired = true
        }
    }

    Timer {
        id: timeLeftUpdateTimer
        interval: 1000 / d.secondsRatio
        repeat: true
        running: expireTimer.running
        onTriggered: {
            d.secondsLeft = Math.max(0, --d.secondsLeft)
        }
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 254
        implicitHeight: 254

        Image {
            id: qrCode
            anchors.fill: parent
            visible: false
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            mipmap: true
            smooth: false
            source: globalUtils.qrCode(root.connectionString)
            cache: false
        }

        MultiEffect {
            blurEnabled: true
            blurMax: 40
            blur: d.codeExpired || d.qrBlurred ? 1.0 : 0.0
            anchors.fill: qrCode
            source: qrCode

            Behavior on blur {
                NumberAnimation { duration: 500 }
            }
        }

        StatusButton {
            id: revealButton
            anchors.centerIn: parent
            visible: !d.codeExpired && d.qrBlurred
            normalColor: Theme.palette.primaryColor1
            hoverColor: Theme.palette.miscColor1;
            textColor: Theme.palette.indirectColor1
            font.weight: Font.Medium
            icon.name: "show"
            text: qsTr("Reveal QR")
            onClicked: {
                d.qrBlurred = !d.qrBlurred
            }
        }

        StatusButton {
            id: regenerateButton
            anchors.centerIn: parent
            visible: d.codeExpired
            normalColor: Theme.palette.primaryColor1
            hoverColor: Theme.palette.miscColor1;
            textColor: Theme.palette.indirectColor1
            font.weight: Font.Medium
            icon.name: "refresh"
            text: qsTr("Regenerate")
            onClicked: {
                root.requestConnectionString()
            }
        }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 16

        StatusBaseText {
            font.pixelSize: Theme.secondaryAdditionalTextSize
            text: qsTr("Code valid for: ")
        }

        StatusBaseText {
            id: timeoutText
            width: fontMetrics.advanceWidth("10:00")
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: Theme.secondaryAdditionalTextSize
            color: d.secondsLeft < 60 ? Theme.palette.dangerColor1 : Theme.palette.directColor1

            text: {
                const minutes = Math.floor(d.secondsLeft / 60);
                const seconds = d.secondsLeft % 60;
                return `${minutes}:${String(seconds).padStart(2,'0')}`;
            }

            FontMetrics {
                id: fontMetrics
                font: timeoutText.font
            }
        }
    }

    // TODO: Extract this to a component.
    //       Also used in `PasswordView` and several other files.
    //       https://github.com/status-im/status-app/issues/6136

    StyledText {
        id: inputLabel
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 7
        text: root.connectionStringLabel
        font.weight: Font.Medium
        color: Theme.palette.directColor1
        font.pixelSize: Theme.additionalTextSize
    }

    StatusPasswordInput {
        id: syncCodeInput

        property bool showPassword
        readonly property bool effectiveShowPassword: showPassword && !d.codeExpired

        Layout.fillWidth: true
        Layout.preferredHeight: 88
        Layout.bottomMargin: 24
        readOnly: true
        selectByMouse: !d.codeExpired
        text: root.connectionString
        rightPadding: syncCodeButtons.width + Theme.padding / 2
        wrapMode: TextEdit.Wrap
        echoMode: effectiveShowPassword ? TextInput.Normal : TextInput.Password

        Row {
            id: syncCodeButtons
            anchors.verticalCenter: syncCodeInput.verticalCenter
            anchors.right: parent.right
            spacing: 8
            rightPadding: 8
            leftPadding: 8

            StatusFlatRoundButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                icon.name: syncCodeInput.effectiveShowPassword ? "hide" : "show"
                icon.color: Theme.palette.baseColor1
                enabled: !d.codeExpired
                onClicked: {
                    syncCodeInput.showPassword = !syncCodeInput.showPassword
                }
            }

            StatusButton {

                objectName: "syncCodeCopyButton"

                anchors.verticalCenter: parent.verticalCenter
                size: StatusBaseButton.Size.Tiny
                enabled: !d.codeExpired
                text: qsTr("Copy")
                onClicked: {
                    const showPassword = syncCodeInput.showPassword
                    syncCodeInput.showPassword = true
                    syncCodeInput.selectAll()
                    syncCodeInput.copy()
                    syncCodeInput.deselect()
                    syncCodeInput.showPassword = showPassword
                }
            }
        }
    }

    StatusBaseText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        visible: !d.codeExpired
        font.pixelSize: Theme.primaryTextFontSize
        color: Theme.palette.baseColor1
        text: root.importCodeInstructions
    }

    StatusBaseText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        visible: d.codeExpired
        font.pixelSize: Theme.primaryTextFontSize
        color: Theme.palette.baseColor1
        text: root.codeExpiredMessage
    }
}
