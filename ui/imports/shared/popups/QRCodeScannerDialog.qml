import QtQuick
import QtQuick.Layouts

import shared.controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

import utils

StatusDialog {
    id: root

    width: 438

    title: qsTr("Scan QR")

    signal addressScanned(string address)
    signal urlScanned(string url)

    QtObject {
        id: d

        property string validTag: ""
        property bool validTagFound: false
    }

    contentItem: Loader {
        Layout.fillWidth: true
        Layout.margins: Theme.padding
        sourceComponent: d.validTagFound ? validTagFound : cameraComponent
    }

    Component {
        id: cameraComponent

        StatusQRCodeScanner {
            id: syncQr
            
            Layout.fillWidth: true
            leftPadding: Theme.padding
            rightPadding: Theme.padding
            cameraWidth: parent.width
            cameraHeight: 276
            validators: [
                StatusValidator {
                    name: "isSyncQrCode"
                    errorMessage: qsTr("Status doesn't understand the QR code.")
                    validate: function (tag) {
                        // We accept URLs and addresses
                        return Utils.isURL(tag) || Utils.isValidAddress(tag)
                    }
                }
            ]
            onValidTagFound: tag => {
                d.validTag = tag
                d.validTagFound = true
            }
        }
    }

    Component {
        id: validTagFound

        ColumnLayout {
            height: contentHeight
            spacing: Theme.padding
            Layout.fillWidth: true

            Timer {
                interval: 1000
                running: true
                repeat: false
                onTriggered: {
                    if (Utils.isURL(d.validTag)) {
                        root.urlScanned(d.validTag)
                    } else if (Utils.isValidAddress(d.validTag)) {
                        root.addressScanned(d.validTag)
                    }
                    root.close()
                }
            }

            StatusImage {
                visible: d.validTagFound
                source: Assets.png("qr-scan-success")
                Layout.fillWidth: true
                Layout.preferredHeight: 272
            }

            StatusBaseText {
                visible: d.validTagFound
                text: qsTr("Scanned successfully")
                color: Theme.palette.primaryColor1
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    footer: Item {
        visible: false
    }
}
