import QtQuick
import QtQuick.Layouts

import shared.controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

import utils
import "./common"

StatusDialog {
    id: root

    // Property used in to simulate permission statuses
    property alias cameraPermissionDenied: qrCodeScanner.cameraPermissionDenied

    width: 360
    fillHeightOnBottomSheet: true
    leftPadding: Theme.smallPadding
    rightPadding: Theme.smallPadding
    topPadding: 0
    bottomPadding: Theme.bigPadding

    title: qsTr("QR Scanner")
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

    contentItem: ColumnLayout {
        width: parent.width
        spacing: Theme.padding

        QRCodeScanner {
            id: qrCodeScanner
            Layout.preferredWidth: parent.width
            Layout.fillHeight: root.bottomSheet
            Layout.maximumHeight: root.bottomSheet ? -1 : 420
            Layout.minimumHeight: 420

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

        IconRow {
            width: parent.width
            text: qsTr("Contact request")
            icon: "contact"
        }

        IconRow {
            width: parent.width
            text: qsTr("Join communities")
            icon: "communities"
        }

        IconRow {
            width: parent.width
            text: qsTr("Send tokens")
            icon: "send"
        }

        IconRow {
            width: parent.width
            text: qsTr("Open WEB links")
            icon: "browser"
        }

        IconRow {
            width: parent.width
            text: qsTr("WalletConnect to connect dApps")
            icon: "wallet"
        }
    }

    footer: null
}
