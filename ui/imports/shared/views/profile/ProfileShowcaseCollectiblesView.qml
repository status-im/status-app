import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Popups

import shared.controls
import shared.stores as SharedStores
import utils

import AppLayouts.Wallet.stores as WalletStores

Item {
    id: root

    required property string mainDisplayName
    required property var collectiblesModel
    required property WalletStores.RootStore walletStore
    required property SharedStores.NetworksStore networksStore

    property alias cellWidth: collectiblesView.cellWidth
    property alias cellHeight: collectiblesView.cellHeight

    signal closeRequested()
    signal visitCommunity(var model)

    StatusBaseText {
        anchors.centerIn: parent
        visible: (collectiblesView.count === 0)
        width: parent.width - (2 * Theme.bigPadding * 2)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: Theme.palette.directColor1
        text: qsTr("%1 has not shared any collectibles").arg(root.mainDisplayName)
    }

    StatusGridView {
        id: collectiblesView

        anchors.fill: parent
        topMargin: Theme.bigPadding
        bottomMargin: Theme.bigPadding
        leftMargin: Theme.bigPadding

        visible: count

        model: root.collectiblesModel
        ScrollBar.vertical: StatusScrollBar { anchors.right: parent.right; anchors.rightMargin: width / 2 }
        delegate: Item {
            id: delegateItem
            function getCollectibleURL() {
                const networkShortName = StatusQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "chainId", model.chainId, "shortName")
                return root.walletStore.getOpenSeaCollectibleUrl(networkShortName, model.contractAddress, model.tokenId)
            }
            function openCollectibleURL() {
                const link = getCollectibleURL();
                Global.requestOpenLink(link)
            }

            function openCollectionURL() {
                const networkShortName = StatusQUtils.ModelUtils.getByKey(root.networksStore.activeNetworks, "chainId", model.chainId, "shortName")
                let link = root.walletStore.getOpenSeaCollectionUrl(networkShortName, model.contractAddress)
                Global.requestOpenLink(link)
            }

            function openContextMenu(x, y) {
                delegatesActionsMenu.createObject(delegateItem, {communityId: model.communityId, url: getCollectibleURL()}).popup(x, y)
            }

            width: GridView.view.cellWidth - Theme.padding
            height: GridView.view.cellHeight - Theme.padding

            HoverHandler {
                id: hoverHandler
                cursorShape: hovered ? Qt.PointingHandCursor : undefined
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onSingleTapped: function (eventPoint, button) {
                    if (!!model.communityId)
                        root.visitCommunity(model)
                    else
                        delegateItem.openCollectibleURL()
                }
                onLongPressed: delegateItem.openContextMenu(point.pressPosition.x, point.pressPosition.y)
            }

            ContextMenu.onRequested: pos => delegateItem.openContextMenu(pos.x, pos.y)

            StatusRoundedImage {
                id: collectibleImage
                anchors.fill: parent
                color: !!model.backgroundColor ? model.backgroundColor : "transparent"
                radius: Theme.radius
                showLoadingIndicator: true
                isLoading: image.isLoading || !model.imageUrl
                image.fillMode: Image.PreserveAspectCrop
                image.source: model.imageUrl ?? ""
            }

            Image {
                id: gradient
                anchors.fill: collectibleImage
                visible: hoverHandler.hovered
                source: Assets.png("profile/gradient")
            }

            //TODO Add drop shadow

            Control {
                id: amountControl
                width: (amountText.contentWidth + Theme.padding)
                height: 24
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 12
                //TODO TBD, https://github.com/status-im/status-app/issues/13782
                visible: (model.userHas > 1)

                background: Rectangle {
                    radius: 30
                    color: amountControl.hovered ? Theme.palette.indirectColor1 : Theme.palette.indirectColor2
                }

                contentItem: StatusBaseText {
                    id: amountText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.asideTextFontSize
                    text: "x"+model.userHas
                }
            }

            StatusRoundButton {
                implicitWidth: 24
                implicitHeight: 24
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 12
                visible: (hoverHandler.hovered && model.communityId === "")
                type: StatusFlatRoundButton.Type.Secondary
                icon.name: "external"
                icon.width: 16
                icon.height: 16
                radius: width/2
                icon.color: Theme.palette.directColor1
                icon.hoverColor: icon.color
                color: hovered ? Theme.palette.indirectColor1 : Theme.palette.indirectColor2
                onClicked: {
                    delegateItem.openCollectibleURL()
                }
            }

            ExpandableTag {
                id: expandableTag

                readonly property bool isCommunity: model.communityId != ""
                readonly property bool isCollection: model.collectionUid != ""

                visible: isCommunity || (isCollection && hoverHandler.hovered)
                tagHeaderText: model.name ?? ""
                tagName: isCommunity ? (model.communityName ?? "") 
                                    : (model.collectionName ?? "")
                tagImage: isCommunity ? (model.communityImage ?? "")
                                    : (hovered ? "external" : "gallery")
                isIcon: !isCommunity
                backgroundColor: hovered ? Theme.palette.background : Theme.palette.indirectColor2
                expanded: hoverHandler.hovered || hovered
                onTagClicked: {
                    if (isCommunity) {
                        Global.switchToCommunity(model.communityId);
                        root.closeRequested();
                    } else {
                        delegateItem.openCollectionURL()
                    }
                }
            }
        }
    }

    Component {
        id: delegatesActionsMenu
        StatusMenu {
            id: contextMenu

            property string url
            property string communityId

            onClosed: destroy()

            StatusAction {
                text: qsTr("Visit community")
                enabled: !!contextMenu.communityId
                icon.name: "communities"
                onTriggered: {
                    Global.switchToCommunity(contextMenu.communityId);
                    root.closeRequested();
                }
            }

            StatusAction {
                text:  qsTr("View on Opensea")
                enabled: contextMenu.communityId === ""
                icon.name: "link"
                onTriggered: {
                    Global.requestOpenLink(contextMenu.url)
                }
            }
        }
    }
}
