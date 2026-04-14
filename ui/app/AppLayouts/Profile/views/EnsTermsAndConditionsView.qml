import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import utils
import shared.popups

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Profile.stores

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

    // TODO: Replace with StatusModal
    ModalPopup {
        id: popup
        title: qsTr("Terms of name registration")

        StatusScrollView {
            id: scroll
            anchors.fill: parent
            contentWidth: availableWidth

            Column {
                spacing: Theme.halfPadding
                width: scroll.availableWidth


                StatusBaseText {
                    text: qsTr("Funds are deposited for 1 year. Your SNT will be locked, but not spent.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("After 1 year, you can release the name and get your deposit back, or take no action to keep the name.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("If terms of the contract change — e.g. Status makes contract upgrades — user has the right to release the username regardless of time held.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("The contract controller cannot access your deposited funds. They can only be moved back to the address that sent them.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("Your address(es) will be publicly associated with your ENS name.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("Usernames are created as subdomain nodes of stateofus.eth and are subject to the ENS smart contract terms.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("You authorize the contract to transfer SNT on your behalf. This can only occur when you approve a transaction to authorize the transfer.")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("These terms are guaranteed by the smart contract logic at addresses:")
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    font.weight: Font.Bold
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("%1 (Status UsernameRegistrar).").arg(root.ensUsernamesStore.getEnsRegisteredAddress())
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    font.family: Fonts.monoFont.family
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("<a href='%1/%2'>Look up on Etherscan</a>")
                    .arg(root.ensUsernamesStore.getEtherscanAddressLink())
                    .arg(root.ensUsernamesStore.getEnsRegisteredAddress())
                    anchors.left: parent.left
                    anchors.right: parent.right
                    onLinkActivated: (link) => Global.requestOpenLink(link)
                    color: Theme.palette.directColor1
                    StatusMouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                StatusBaseText {
                    text: qsTr("%1 (ENS Registry).").arg(root.ensUsernamesStore.getEnsRegistry())
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    font.family: Fonts.monoFont.family
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    text: qsTr("<a href='%1/%2'>Look up on Etherscan</a>")
                    .arg(root.ensUsernamesStore.getEtherscanAddressLink())
                    .arg(root.ensUsernamesStore.getEnsRegistry())
                    anchors.left: parent.left
                    anchors.right: parent.right
                    onLinkActivated: (link) => Global.requestOpenLink(link)
                    color: Theme.palette.directColor1
                    StatusMouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

            }
        }
    }

    StatusScrollView {
        id: sview
        anchors.top: sectionTitle.bottom
        anchors.topMargin: Theme.padding
        anchors.bottom: startBtn.top
        anchors.bottomMargin: Theme.padding
        anchors.left: parent.left
        anchors.right: parent.right

        contentWidth: availableWidth

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

            StatusCheckBox {
                id: termsAndConditionsCheckbox
                objectName: "ensAgreeTerms"
                anchors.top: keyLbl.bottom
                anchors.topMargin: Theme.padding
                anchors.left: parent.left
                anchors.leftMargin: 24
            }

            StatusBaseText {
                text: qsTr("Agree to <a href=\"#\">Terms of name registration.</a> I understand that my wallet address will be publicly connected to my username.")
                anchors.left: termsAndConditionsCheckbox.right
                anchors.leftMargin: Theme.halfPadding
                anchors.right: parent.right
                wrapMode: Text.WordWrap
                anchors.verticalCenter: termsAndConditionsCheckbox.verticalCenter
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

    StatusButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padding
        anchors.left: parent.left
        anchors.leftMargin: Theme.padding
        text: qsTr("Back")
        onClicked: backBtnClicked()
    }

    Item {
        anchors.top: startBtn.top
        anchors.right: startBtn.left
        anchors.rightMargin: Theme.padding
        width: childrenRect.width

        Image {
            id: image1
            height: 50
            width: height
            source: Assets.png("tokens/SNT")
            sourceSize: Qt.size(width, height)
            cache: false
        }

        StatusBaseText {
            id: ensPriceLbl
            text: qsTr("10 SNT")
            anchors.left: image1.right
            anchors.leftMargin: 5
            anchors.top: image1.top
            color: Theme.palette.directColor1
            font.pixelSize: Theme.secondaryTextFontSize
        }

        StatusBaseText {
            text: qsTr("Deposit")
            anchors.left: image1.right
            anchors.leftMargin: 5
            anchors.topMargin: 5
            anchors.top: ensPriceLbl.bottom
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.secondaryTextFontSize
        }
    }

    StatusButton {
        id: startBtn
        objectName: "ensStartTransaction"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padding
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        text: d.sntBalance < 10 ?
          qsTr("Not enough SNT") :
          qsTr("Register")
        enabled: d.sntBalance >= 10 && termsAndConditionsCheckbox.checked
        onClicked: root.registerUsername()
    }

    ModelEntry {
        id: statusTokenEntry
        sourceModel: root.assetsModel
        key: "key"
        value: root.ensUsernamesStore.getStatusTokenGroupKey()
    }
}
