import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import utils

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Profile.stores
import AppLayouts.Profile.popups

import QtModelsToolkit

Item {
    id: root

    property EnsUsernamesStore ensUsernamesStore
    property string username: ""

    required property var assetsModel

    signal backBtnClicked()
    signal registerUsername()

    QtObject {
        id: d

        readonly property var sntToken: statusTokenEntry.item
        readonly property SumAggregator aggregator: SumAggregator {
            model: !!d.sntToken && !!d.sntToken.balances ? d.sntToken.balances: null
            roleName: "balance"
        }
        readonly property real sntBalance: !!sntToken && !!sntToken.decimals ? aggregator.value/(10 ** sntToken.decimals): 0
    }

    StatusBaseText {
        id: sectionTitle
        text: qsTr("ENS usernames")
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 24
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSize(20)
        color: Theme.palette.directColor1
    }

    EnsTermsAndConditionsPopup {
        id: popup

        registrarAddress: root.ensUsernamesStore.ensRegisteredAddress
        ensRegistryAddress: root.ensUsernamesStore.getEnsRegistry()
        etherscanAddressLink: root.ensUsernamesStore.getEtherscanAddressLink()
    }

    StatusScrollView {
        id: sview
        anchors.top: sectionTitle.bottom
        anchors.topMargin: Theme.padding
        anchors.bottom: bottomLayout.top
        anchors.bottomMargin: Theme.padding
        anchors.left: parent.left
        anchors.right: parent.right

        contentWidth: availableWidth
        contentHeight: contentItem.childrenRect.y + contentItem.childrenRect.height

        Item {
            id: contentItem
            width: sview.availableWidth

            Rectangle {
                id: circleAt
                anchors.top: parent.top
                anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                width: 60
                height: 60
                radius: 120
                color: Theme.palette.primaryColor1

                StatusBaseText {
                    text: "@"
                    opacity: 0.7
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSize(18)
                    color: StatusColors.white
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StatusBaseText {
                id: ensUsername
                text: username + ".stateofus.eth"
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSize(18)
                anchors.top: circleAt.bottom
                anchors.topMargin: 24
                anchors.left: parent.left
                anchors.right: parent.right
                horizontalAlignment: Text.AlignHCenter
                color: Theme.palette.directColor1
            }

            StatusDescriptionListItem {
                id: walletAddressLbl

                anchors.left: parent.left
                anchors.right: parent.right

                title: qsTr("Wallet address")
                subTitle: root.ensUsernamesStore.getWalletDefaultAddress()
                tooltip.text: qsTr("Copied to clipboard!")
                asset.name: "copy"
                iconButton.onClicked: {
                    ClipboardUtils.setText(subTitle)
                    tooltip.visible = !tooltip.visible
                }
                anchors.top: ensUsername.bottom
                anchors.topMargin: 24
            }

            StatusDescriptionListItem {
                id: keyLbl

                anchors.left: parent.left
                anchors.right: parent.right

                title: qsTr("Key")
                subTitle: {
                    let pubKey = root.ensUsernamesStore.pubkey;
                    return pubKey.substring(0, 20) + "..." + pubKey.substring(pubKey.length - 20);
                }
                tooltip.text: qsTr("Copied to clipboard!")
                asset.name: "copy"
                iconButton.onClicked: {
                    ClipboardUtils.setText(subTitle)
                    tooltip.visible = !tooltip.visible
                }
                anchors.top: walletAddressLbl.bottom
                anchors.topMargin: 24
            }

            RowLayout {
                anchors.top: keyLbl.bottom
                anchors.topMargin: Theme.padding
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24

                spacing: Theme.halfPadding

                StatusCheckBox {
                    id: termsAndConditionsCheckbox
                    objectName: "ensAgreeTerms"

                    Layout.alignment: Qt.AlignVCenter
                }

                StatusBaseText {
                    text: qsTr("Agree to <a href=\"#\">Terms of name registration.</a> I understand that my wallet address will be publicly connected to my username.")

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true

                    wrapMode: Text.WordWrap
                    onLinkActivated: popup.open()
                    color: Theme.palette.directColor1

                    TapHandler {
                        enabled: !parent.hoveredLink
                        onSingleTapped: termsAndConditionsCheckbox.toggle()
                    }
                    StatusMouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: bottomLayout
        spacing: Theme.padding

        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padding
        anchors.left: parent.left
        anchors.leftMargin: Theme.padding
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.padding

            Image {
                id: image1

                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                Layout.alignment: Qt.AlignVCenter

                source: Assets.png("tokens/SNT")
                sourceSize: Qt.size(width, height)
                cache: false
            }

            ColumnLayout {
                spacing: 5

                Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter

                StatusBaseText {
                    text: qsTr("10 SNT")
                    color: Theme.palette.directColor1
                    font.pixelSize: Theme.secondaryTextFontSize
                }

                StatusBaseText {
                    text: qsTr("Deposit")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.secondaryTextFontSize
                }
            }

            StatusButton {
                objectName: "ensStartTransaction"

                Layout.alignment: Qt.AlignVCenter

                text: d.sntBalance < 10 ?
                  qsTr("Not enough SNT") :
                  qsTr("Register")
                enabled: d.sntBalance >= 10 && termsAndConditionsCheckbox.checked
                onClicked: root.registerUsername()
            }
        }

        StatusButton {
            Layout.alignment: Qt.AlignHCenter

            text: qsTr("Back")
            onClicked: backBtnClicked()
        }
    }



    ModelEntry {
        id: statusTokenEntry
        sourceModel: root.assetsModel
        key: "key"
        value: root.ensUsernamesStore.getStatusTokenGroupKey()
    }
}
