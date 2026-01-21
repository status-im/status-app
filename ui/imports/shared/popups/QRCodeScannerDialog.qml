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

    width: 360
    height: 500
    fillHeightOnBottomSheet: true
    leftPadding: Theme.smallPadding
    rightPadding: Theme.smallPadding
    topPadding: 0
    bottomPadding: Theme.bigPadding

    title: qsTr("QR Code Scanner")
    showHeaderDivider: false

    signal tagFound(int tagType, string tag)

    enum TagType {
        Link,
        Address
    }

    QtObject {
        id: d

        property string validTag: ""
    }

    contentItem: Loader {
        Layout.fillWidth: true
        // Layout.margins: Theme.smallPadding
        sourceComponent: !!d.validTag ? validTagFoundComponent : cameraComponent
    }

    Component {
        id: cameraComponent

        QRCodeScanner {
            id: qrCodeScanner
            validators: [
                StatusValidator {
                    name: "isValidQR"
                    errorMessage: qsTr("We cannot read that QR code.")
                    validate: function (tag) {
                        // We accept URLs and addresses
                        return Utils.isURL(tag) || Utils.isValidAddress(tag)
                    }
                }
            ]
            onValidTagFound: tag => {
                d.validTag = tag
            }
        }
    }

    Component {
        id: validTagFoundComponent

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
                        root.tagFound(QRCodeScannerDialog.TagType.Link, d.validTag)
                    } else if (Utils.isValidAddress(d.validTag)) {
                        root.tagFound(QRCodeScannerDialog.TagType.Address, d.validTag)
                    }
                    root.close()
                }
            }

            StatusImage {
                source: Assets.png("qr-scan-success")
                Layout.fillWidth: true
                Layout.preferredHeight: 272
            }

            StatusBaseText {
                text: qsTr("Scanned successfully")
                color: Theme.palette.primaryColor1
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    footer: null
}
