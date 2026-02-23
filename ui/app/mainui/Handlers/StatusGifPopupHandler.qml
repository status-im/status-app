import QtQuick
import QtQuick.Controls

import shared.status
import shared.stores

import StatusQ.Core.Theme

QtObject {
    id: root

    required property GifStore gifStore
    required property bool gifUnfurlingEnabled
    required property bool thirdpartyServicesEnabled

    signal enableThirdpartyServicesRequested

    property QtObject _d: QtObject {
        property var cbOnGifSelected: function () {} // It stores callback for gifSelected
        property var cbOnClose: function () {} // It stores callback for popup closed
        property var popupParent: null // Gifs button object type
        property bool closeAfterSelection: true
    }

    function openGifs(params, cbOnGifSelected, cbOnClose)
    {
        _d.cbOnGifSelected = cbOnGifSelected
        _d.cbOnClose = cbOnClose
        _d.popupParent = params.popupParent
        _d.closeAfterSelection = params.closeAfterSelection

        let gifPopupInst = gifPopupComponent.createObject(_d.popupParent)
        gifPopupInst.open()
    }

    readonly property Component gifPopupComponent: Component {
        StatusGifPopup {
            id: popup

            width: 360
            height: 440
            directParent: _d.popupParent
            relativeX: directParent.width - popup.width - Theme.halfPadding
            relativeY: -popup.height

            gifUnfurlingEnabled: root.gifUnfurlingEnabled
            thirdpartyServicesEnabled: root.thirdpartyServicesEnabled

            loading: root.gifStore.gifLoading
            gifColumnA: root.gifStore.gifColumnA
            gifColumnB: root.gifStore.gifColumnB
            gifColumnC: root.gifStore.gifColumnC

            isFavorite: root.gifStore.isFavorite
            addToRecentsGif: root.gifStore.addToRecentsGif
            searchGifsRequest: root.gifStore.searchGifs
            getTrendingsGifs: root.gifStore.getTrendingsGifs
            getFavoritesGifs: root.gifStore.getFavoritesGifs
            getRecentsGifs: root.gifStore.getRecentsGifs
            toggleFavoriteGif: root.gifStore.toggleFavoriteGif
            setGifUnfurlingEnabled: root.gifStore.setGifUnfurlingEnabled

            onGifSelected: {
                _d.cbOnGifSelected(event, url)

                if (_d.closeAfterSelection) {
                    close()
                }
            }
            onEnableThirdpartyServicesRequested: root.enableThirdpartyServicesRequested()
            onClosed: {
                _d.cbOnClose()
                destroy()
            }
        }
    }
}
