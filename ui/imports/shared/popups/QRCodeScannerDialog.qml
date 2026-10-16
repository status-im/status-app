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

    // Each opening is a fresh session (the dialog may be reused, not destroyed).
    onAboutToShow: {
        d.validTag = ""
        qrCodeScanner.reset()
    }

    enum TagType {
        Link,
        Address,
        WCUri
    }

    QtObject {
        id: d

        property string validTag: ""
        property int validTagType

        readonly property int scannerPreferredHeight: 420
        readonly property int scannerMinHeight: 200
    }

    contentItem: StatusScrollView {
        id: scrollView

        padding: 0
        contentWidth: availableWidth
        contentHeight: content.height
        implicitHeight: content.implicitHeight

        // Fills the view: the scanner takes what the info rows leave, down to
        // its minimum; below that the content scrolls instead of spilling out
        // of the dialog (a short window).
        ColumnLayout {
            id: content

            width: scrollView.availableWidth
            height: Math.max(scrollView.availableHeight,
                             d.scannerMinHeight + spacing + infoRows.implicitHeight)
            spacing: Theme.padding

            QRCodeScanner {
                id: qrCodeScanner

                objectName: "qrCodeScanner"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: d.scannerPreferredHeight
                Layout.minimumHeight: d.scannerMinHeight
                Layout.maximumHeight: root.bottomSheet ? Number.POSITIVE_INFINITY
                                                       : d.scannerPreferredHeight

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

            ColumnLayout {
                id: infoRows

                objectName: "qrScannerInfoRows"
                Layout.fillWidth: true
                spacing: Theme.padding

                IconRow {
                    Layout.fillWidth: true

                    text: qsTr("Contact request")
                    icon: "contact"
                }

                IconRow {
                    Layout.fillWidth: true

                    text: qsTr("Join communities")
                    icon: "communities"
                }

                IconRow {
                    Layout.fillWidth: true

                    text: qsTr("Send tokens")
                    icon: "send"
                }

                IconRow {
                    Layout.fillWidth: true

                    text: qsTr("Open WEB links")
                    icon: "browser"
                }

                IconRow {
                    Layout.fillWidth: true

                    text: qsTr("WalletConnect to connect to dApps")
                    icon: "wallet"
                }
            }
        }
    }

    footer: null
}
