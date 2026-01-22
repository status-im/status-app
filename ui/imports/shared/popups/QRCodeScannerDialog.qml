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

    // This property is used in Storybook to simulate permission statuses
    property alias cameraPermissionDenied: qrCodeScanner.cameraPermissionDenied

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

    contentItem: QRCodeScanner {
        id: qrCodeScanner

        Timer {
            interval: 300
            running: !!d.validTag
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

    footer: null
}
