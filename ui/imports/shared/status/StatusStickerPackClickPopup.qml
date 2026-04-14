import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import utils
import shared
import shared.popups
import shared.status
import shared.stores as SharedStores
import shared.popups.send
import shared.stores.send

import AppLayouts.Chat.stores as ChatStores

StatusDialog {
    id: root

    property string packId

    property ChatStores.RootStore store
    property string thumbnail: ""
    property string name: ""
    property string author: ""
    property string price
    property bool installed: false
    property bool bought: false
    property bool pending: false
    property var stickers

    signal buyClicked()

    width: 480
    implicitHeight: 472

    onAboutToShow: {
        stickersModule.getInstalledStickerPacks()

        const idx = stickersModule.stickerPacks.findIndexById(packId, false)
        if(idx === -1) close()
        const item = SQUtils.ModelUtils.get(stickersModule.stickerPacks, idx)
        name = item.name
        author = item.author
        thumbnail = item.thumbnail
        price = item.price
        stickers = item.stickers
        installed = item.installed
        bought = item.bought
        pending = item.pending
    }

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
                style: StatusStickerButton.StyleType.LargeNoIcon
                packPrice: parseInt(price)
                isInstalled: installed
                isBought: bought
                isPending: pending
                greyedOut: !store.networkConnectionStore.stickersNetworkAvailable
                tooltip.text: store.networkConnectionStore.stickersNetworkUnavailableText
                onInstallClicked: {
                    stickersModule.install(packId)
                    root.close()
                }
                onUninstallClicked: {
                    stickersModule.uninstall(packId);
                    root.close();
                }
                onBuyClicked: root.buyClicked()
            }
        }
    }
}