import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils
import shared
import shared.panels
import shared.status
import shared.popups.send
import shared.stores.send

import AppLayouts.Chat.stores as ChatStores

Item {
    id: root

    property ChatStores.RootStore store
    property var stickerPacks
    property string packId
    property bool marketVisible
    property bool isWalletEnabled

    signal backClicked
    signal uninstallClicked(string packId)
    signal installClicked(var stickers, string packId, int index)
    signal cancelClicked(string packId)
    signal updateClicked(string packId)
    signal buyClicked(string packId, int price)
    signal closeRequested()

    implicitHeight: childrenRect.height

    StatusGridView {
        id: availableStickerPacks
        objectName: "stickerMarketStatusGridView"
        width: parent.width
        height: 380
        anchors.left: parent.left
        anchors.leftMargin: Theme.padding
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.padding
        cellWidth: parent.width - (Theme.padding * 2)
        cellHeight: height - 72
        visible: root.marketVisible

        ScrollBar.vertical: StatusScrollBar {}

        focus: true
        model: DelegateModel {
            id: delegateModel

            function update() {
                if (items.count > 0) {
                    items.setGroups(0, items.count, "items");
                }

                var visible = [];
                for (var i = 0; i < items.count; ++i) {
                    var item = items.get(i);
                    if (delegateModel.walletEnabled ||
                        !delegateModel.walletEnabled && item.model.price == 0) {
                        visible.push(item);
                    }
                }

                for (i = 0; i < visible.length; ++i) {
                    item = visible[i];
                    item.inVisible = true;
                    if (item.visibleIndex !== i) {
                        visibleItems.move(item.visibleIndex, i, 1);
                    }
                }
            }

            readonly property bool walletEnabled: root.isWalletEnabled
            onWalletEnabledChanged: {
                update()
            }

            model: root.stickerPacks
            items.onChanged: update()
            filterOnGroup: "visible"
            groups: DelegateModelGroup {
                id: visibleItems

                name: "visible"
                includeByDefault: false
            }

            delegate: Item {
                objectName: "stickerMarketDelegateItem" + index
                readonly property string packId: model.packId // This property is necessary for the tests
                readonly property bool installed: model.installed // This property is necessary for the tests
                width: availableStickerPacks.cellWidth
                height: availableStickerPacks.cellHeight
                RoundedImage {
                    id: imgPreview
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 220
                    width: parent.width
                    radius: 12
                    source: model.preview
                    onClicked: {
                        stickerPackDetailsPopup.open()
                        root.closeRequested()
                    }
                }

                StatusDialog {
                    id: stickerPackDetailsPopup
                    implicitHeight: 540
                    width: 480
                    header: StatusStickerPackDetails {
                        packThumb: thumbnail
                        packName: name
                        packAuthor: author
                        packNameFontSize: Theme.secondaryAdditionalTextSize
                        spacing: Theme.padding / 2
                    }

                    contentItem: StatusStickerList {
                        model: stickers
                        packId: root.packId
                    }

                    footer: StatusDialogFooter {
                        rightButtons: ObjectModel {
                            StatusStickerButton {
                                objectName: "statusStickerMarketInstallButton"
                                style: StatusStickerButton.StyleType.LargeNoIcon
                                packPrice: price
                                isInstalled: installed
                                isBought: bought
                                isPending: pending
                                greyedOut: !root.store.networkConnectionStore.stickersNetworkAvailable
                                tooltip.text: root.store.networkConnectionStore.stickersNetworkUnavailableText
                                onInstallClicked: root.installClicked(stickers, packId, index)
                                onUninstallClicked: root.uninstallClicked(packId)
                                onCancelClicked: root.cancelClicked(packId)
                                onUpdateClicked: root.updateClicked(packId)
                                onBuyClicked: root.buyClicked(packId, price)
                            }
                        }
                    }
                }

                StatusStickerPackDetails {
                    id: stickerPackDetails
                    height: 64 - (Theme.smallPadding * 2)
                    width: parent.width - (Theme.padding * 2)
                    anchors.top: imgPreview.bottom
                    anchors.topMargin: Theme.smallPadding
                    anchors.bottomMargin: Theme.smallPadding
                    anchors.left: parent.left
                    anchors.right: parent.right
                    packThumb: thumbnail
                    packName: name
                    packAuthor: author

                    StatusStickerButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        packPrice: price
                        isInstalled: installed
                        isBought: bought
                        isPending: pending
                        greyedOut: !root.store.networkConnectionStore.stickersNetworkAvailable
                        tooltip.text: root.store.networkConnectionStore.stickersNetworkUnavailableText
                        onInstallClicked: root.installClicked(stickers, packId, index)
                        onUninstallClicked: root.uninstallClicked(packId)
                        onCancelClicked: root.cancelClicked(packId)
                        onUpdateClicked: root.updateClicked(packId)
                        onBuyClicked: root.buyClicked(packId, price)
                    }
                }
            }
        }
    }

    Item {
        id: footer
        height: 44
        anchors.top: availableStickerPacks.bottom

        StatusBackButton {
            id: btnBack
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.padding / 2
            width: 24
            height: 24
            icon.width: 16
            icon.height: 16
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
                root.backClicked()
            }
        }
    }
}
