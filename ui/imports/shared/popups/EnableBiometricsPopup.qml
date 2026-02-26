import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Components

StatusDialog {
    id: root

    property string errorText
    property bool loading

    signal enableBiometricsRequested()

    implicitWidth: 480
    title: qsTr("Enable biometrics")

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.bigPadding

        StatusImage {
            Layout.preferredWidth: 270
            Layout.preferredHeight: 260
            Layout.alignment: Qt.AlignHCenter
            mipmap: true
            smooth: false
            source: Assets.png("onboarding/enable_biometrics")
        }
        StatusBaseText {
            Layout.fillWidth: true
            text: root.errorText
            color: Theme.palette.dangerColor1
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("Use biometrics to fill in your password")
            color: Theme.palette.baseColor1
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    footer: StatusDialogFooter {
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        dropShadowEnabled: true
        rightButtons: ObjectModel {
            StatusButton {
                objectName: "btnDontEnableBiometrics"
                borderColor: Theme.palette.baseColor2
                normalColor: "transparent"
                text: qsTr("Maybe later")
                onClicked: root.close()
            }
            StatusButton {
                objectName: "btnEnableBiometrics"
                text: qsTr("Enable")
                loading: root.loading
                onClicked: root.enableBiometricsRequested()
            }
        }
    }
}
