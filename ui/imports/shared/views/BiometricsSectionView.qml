import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

Control {
    id: root

    required property bool biometricsAvailable
    required property bool biometricsEnabled

    signal toggleBiometrics(bool checked)

    padding: 0

    contentItem: ColumnLayout {
        spacing: Theme.bigPadding
        RowLayout {
            spacing: Theme.halfPadding
            StatusRoundIcon {
                asset.name: "touch-id"
                asset.color: Theme.palette.baseColor1
                asset.bgColor: root.biometricsAvailable ?
                                   Theme.palette.baseColor2:
                                   StatusColors.transparent
                asset.bgBorderColor: root.biometricsAvailable ?
                                         StatusColors.transparent:
                                         Theme.palette.baseColor2
                asset.bgBorderWidth: 1
            }
            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Enable biometrics to fill in your password")
                color: root.biometricsAvailable ? Theme.palette.directColor4: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
            }
            StatusSwitch {
                id: biometricsSwitch

                objectName: "biometricsSwitch"
                Layout.alignment: Qt.AlignRight

                opacity: root.biometricsAvailable ? 1 : ThemeUtils.disabledOpacity
                checkable: false
                checked: root.biometricsAvailable && root.biometricsEnabled
                onClicked: root.toggleBiometrics(biometricsSwitch.checked)
            }
        }
        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("Biometrics unavailable — it may not be supported, set up, or allowed by your OS settings or app permissions.")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.WordWrap
            // only show if biometrics are available
            visible: !root.biometricsAvailable
        }
    }
}
