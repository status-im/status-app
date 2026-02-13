import QtQuick
import QtQuick.Layouts

import shared.controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.services.dapps

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
        Address,
        WCUri
    }

    QtObject {
        id: d

        property string validTag: ""
        property int validTagType
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
                    root.tagFound(d.validTagType, d.validTag)
                    root.close()
                }
            }

            validators: [
                StatusValidator {
                    name: "isValidQR"
                    errorMessage: qsTr("We cannot read that QR code.")
                    validate: function (tag) {
                        // We accept URLs, addresses and WalletConnect URIs
                        if (Utils.isURL(tag)) {
                            d.validTagType = QRCodeScannerDialog.TagType.Link
                            return true
                        }
                        if (Utils.isValidAddress(tag)) {
                            d.validTagType = QRCodeScannerDialog.TagType.Address
                            return true
                        }
                        if (DAppsHelpers.validURI(tag)) {
                            d.validTagType = QRCodeScannerDialog.TagType.WCUri
                            return true
                        }
                        return false
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
            text: qsTr("WalletConnect to connect to dApps")
            icon: "wallet"
        }
    }

    footer: null
}
