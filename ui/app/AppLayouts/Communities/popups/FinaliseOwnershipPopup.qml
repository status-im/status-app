import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import AppLayouts.Communities.panels

import utils

StatusDialog {
    id: root
    objectName: "finaliseOwnershipPopup"

    // Community related props:
    required property string communityName
    required property string communityLogo
    required property string communityColor

    // Owner token related props:
    required property string tokenSymbol
    required property string tokenChainName

    // Fees calculation props:
    property string feeText
    property string feeErrorText
    property bool isFeeLoading
    property string feeLabel: qsTr("Update %1 Community smart contract on %2").arg(root.communityName).arg(root.tokenChainName)

    // Account expected roles: address, name, color, emoji, walletType
    property var accounts

    readonly property alias selectedAccountAddress: d.accountAddress

    signal finaliseOwnershipClicked
    signal rejectClicked
    signal visitCommunityClicked
    signal openControlNodeDocClicked(string link)
    signal calculateFees()
    signal stopUpdatingFees()

    QtObject {
        id: d

        readonly property string controlNodeLink: Constants.statusHelpLinkPrefix + "status-communities/about-the-control-node-in-status-communities/"
        readonly property int init: 0
        readonly property int finalise: 1

        property bool feesActive: false
        property bool ackCheck: false

        // Fees related props:
        // TODO: These properties are not used in the current implementation!
        // Check if the current fees box in this popup is needed!!
        property string accountAddress: ""
        property string accountName: ""
    }

    width: 640 // by design
    padding: 0

    component CustomText : StatusBaseText {
        Layout.fillWidth: true

        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        lineHeight: 1.2
    }

    contentItem: StatusScrollView {
        id: scrollView

        contentWidth: availableWidth
        contentHeight: loader.item.height

        padding: Theme.padding

        Loader {
            id: loader

            width: scrollView.availableWidth
            sourceComponent: initialPanel
            state: d.init
            states: [
                State {
                    name: d.init

                    PropertyChanges { target: loader; sourceComponent: initialPanel }
                    PropertyChanges {
                        target: acceptBtn
                        text: qsTr("Finalise %1 ownership").arg(root.communityName)
                        enabled: true

                        onClicked: loader.state = d.finalise
                    }
                    PropertyChanges {
                        target: rejectBtn
                        visible: true

                        onClicked: root.rejectClicked()
                    }
                    PropertyChanges { target: backButton; visible: false }
                },
                State {
                    name: d.finalise

                    PropertyChanges { target: loader; sourceComponent: finalisePanel }
                    PropertyChanges {
                        target: acceptBtn
                        text: qsTr("Make this device the control node and update smart contract")
                        enabled: d.feesActive && !root.isFeeLoading && root.feeErrorText === ""

                        onClicked: root.finaliseOwnershipClicked()
                    }
                    PropertyChanges { target: rejectBtn; visible: false }
                    PropertyChanges {
                        target: backButton
                        visible: true

                        onClicked: loader.state = d.init
                    }
                }
            ]
        }
    }

    header: StatusDialogHeader {
        headline.title: qsTr("Finalise %1 ownership").arg(root.communityName)
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusSmartIdenticon {
            asset.name: root.communityLogo
            asset.isImage: !!asset.name
        }
    }

    footer: StatusDialogFooter {
        spacing: Theme.padding

        rightButtons: ObjectModel {
            StatusFlatButton {
                id: rejectBtn

                text: qsTr("I don't want to be the owner")

                onClicked: {
                    root.stopUpdatingFees()
                    root.rejectClicked()
                    close()
                }
            }

            StatusButton {
                id: acceptBtn
                objectName: "finaliseOwnershipAcceptButton"
            }
        }
        leftButtons: ObjectModel {
            StatusBackButton {
                id: backButton

                Layout.minimumWidth: implicitWidth
            }
        }
    }

    Component {
        id: initialPanel

        ColumnLayout {
            spacing: Theme.padding

            CustomText {
                text: qsTr("Congratulations! You have been sent the %1 Community Owner token.").arg(root.communityName)
                font.bold: true
            }

            CustomText {
                textFormat: Text.RichText
                text: qsTr("To finalise your ownership and assume ultimate admin rights for the %1 Community, you need to make your device the Community's <a style=\"color:%3;\" href=\"%2\">control node</a><a style=\"color:%3;text-decoration: none\" href=\"%2\">↗</a>. You will also need to sign a small transaction to update the %1 Community smart contract to make you the official signatory for all Community changes.").arg(root.communityName).arg(d.controlNodeLink).arg(color)

                onLinkActivated: root.openControlNodeDocClicked(link)
            }

            PrivilegedTokenArtworkPanel {
                id: tokenPanel

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.padding

                isOwner: true
                artwork: root.communityLogo
                color: root.communityColor
                size: PrivilegedTokenArtworkPanel.Size.Large
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: tokenPanel.width
                Layout.preferredHeight: boxContent.implicitHeight + Theme.padding
                Layout.bottomMargin: Theme.padding

                radius: 8
                border.color: Theme.palette.baseColor2
                color: "transparent"

                ColumnLayout {
                    id: boxContent

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StatusBaseText {
                        Layout.leftMargin: Theme.padding

                        text: qsTr("Symbol")
                        elide: Text.ElideRight
                        font.pixelSize: Theme.additionalTextSize
                        color: Theme.palette.baseColor1
                    }

                    StatusBaseText {
                        Layout.leftMargin: Theme.padding

                        text: root.tokenSymbol
                        elide: Text.ElideRight
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.directColor1
                    }
                }
            }

            StatusListItem {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.padding

                title: root.communityName
                border.color: Theme.palette.baseColor2
                asset.name: root.communityLogo
                asset.isImage: true
                asset.isLetterIdenticon: !asset.name
                components: [
                    RowLayout {
                        StatusIcon {
                            icon: "arrow-right"
                            color: Theme.palette.primaryColor1
                        }

                        StatusBaseText {
                            Layout.rightMargin: Theme.padding

                            text: qsTr("Visit Community")
                            font.pixelSize: Theme.additionalTextSize
                            color: Theme.palette.primaryColor1
                        }
                    }
                ]

                onClicked: {
                    close()
                    root.visitCommunityClicked()
                }
            }
        }
    }

    Component {
        id: finalisePanel

        ColumnLayout {
            spacing: Theme.padding

            CustomText {
                text: qsTr("Finalising your ownership of the %1 Community requires you to:").arg(root.communityName)
            }

            CustomText {
                text: qsTr("1. Make this device the control node for the Community")
                font.bold: true
            }

            CustomText {
                Layout.topMargin: -Theme.halfPadding

                text: qsTr("It is vital to keep your device online and running Status in order for the Community to operate effectively. Login with this account via another synced desktop device if you think it might be better suited for this purpose.")
            }

            CustomText {
                text: qsTr("2. Update the %1 Community smart contract").arg(root.communityName)
                font.bold: true
            }

            CustomText {
                Layout.topMargin: -Theme.halfPadding

                text: qsTr("This transaction updates the %1 Community smart contract, making you the %1 Community owner.").arg(root.communityName)
            }

            StatusSwitch {
                id: showFees
                objectName: "finaliseOwnershipShowFeesSwitch"
                enabled: d.ackCheck
                text: qsTr("Show fees (will be enabled once acknowledge confirmed)")

                onCheckedChanged: {
                    d.feesActive = checked
                    if(checked) {
                        root.calculateFees()
                        return
                    }
                    root.stopUpdatingFees()
                }
            }

            FeesBox {
                id: feesBox
                visible: showFees.checked
                Layout.fillWidth: true

                implicitWidth: 0

                accountsSelector.model: root.accounts
                accountErrorText: root.feeErrorText
                accountSelectorText: qsTr("Gas fees will be paid from")

                model: QtObject {
                    id: singleFeeModel

                    readonly property string title: root.feeLabel
                    readonly property string feeText: root.isFeeLoading ? "" : root.feeText
                    readonly property bool error: root.feeErrorText !== ""
                }

                Binding {
                    target: d
                    property: "accountAddress"
                    value: feesBox.accountsSelector.currentAccountAddress
                }

                Binding {
                    target: d
                    property: "accountName"
                    value: feesBox.accountsSelector.currentAccount.name
                }
            }

            StatusCheckBox {
                objectName: "finaliseOwnershipAckCheckBox"
                enabled: !showFees.checked
                Layout.topMargin: -Theme.halfPadding
                Layout.fillWidth: true

                checked: d.ackCheck
                font.pixelSize: Theme.primaryTextFontSize
                text: qsTr("I acknowledge that I must keep this device online and running Status as much of the time as possible for the %1 Community to operate effectively").arg(root.communityName)

                onCheckStateChanged: d.ackCheck = checked
            }
        }
    }
}
