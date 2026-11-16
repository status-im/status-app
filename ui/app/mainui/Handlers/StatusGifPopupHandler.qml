import QtQuick
import QtQuick.Controls

import shared.stores

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

QtObject {
    id: root

    required property GifStore gifStore
    required property bool gifUnfurlingEnabled
    required property bool thirdpartyServicesEnabled

    signal enableThirdpartyServicesRequested

    property QtObject _d: QtObject {
        id: _d
        property var cbOnGifSelected: function () {} // It stores callback for gifSelected
        property var cbOnClose: function () {} // It stores callback for popup closed
        property var popupParent: null // Gifs button object type
        property bool closeAfterSelection: true
        property var relativeX: undefined
    }

    function openGifs(params, cbOnGifSelected, cbOnClose)
    {
        _d.cbOnGifSelected = cbOnGifSelected
        _d.cbOnClose = cbOnClose
        _d.popupParent = params.popupParent
        _d.closeAfterSelection = params.closeAfterSelection
        _d.relativeX = params.relativeX

        let gifPopupInst = gifPopupComponent.createObject(_d.popupParent)
        gifPopupInst.open()
    }

    readonly property SQUtils.DeferredComponent gifPopupComponent: SQUtils.DeferredComponent {
        module: "shared.status"
        typeName: "StatusGifPopup"
        properties: ({
            width: 360,
            height: 440,
            directParent: Qt.binding(() => _d.popupParent),
            gifUnfurlingEnabled: Qt.binding(() => root.gifUnfurlingEnabled),
            thirdpartyServicesEnabled: Qt.binding(() => root.thirdpartyServicesEnabled),
            loading: Qt.binding(() => root.gifStore.gifLoading),
            gifColumnA: Qt.binding(() => root.gifStore.gifColumnA),
            gifColumnB: Qt.binding(() => root.gifStore.gifColumnB),
            gifColumnC: Qt.binding(() => root.gifStore.gifColumnC),
            isFavorite: root.gifStore.isFavorite,
            addToRecentsGif: root.gifStore.addToRecentsGif,
            searchGifsRequest: root.gifStore.searchGifs,
            getTrendingsGifs: root.gifStore.getTrendingsGifs,
            getFavoritesGifs: root.gifStore.getFavoritesGifs,
            getRecentsGifs: root.gifStore.getRecentsGifs,
            toggleFavoriteGif: root.gifStore.toggleFavoriteGif,
            setGifUnfurlingEnabled: root.gifStore.setGifUnfurlingEnabled
        })
        onCreated: popup => {
            popup.relativeX = Qt.binding(() => _d.relativeX !== undefined ? _d.relativeX
                                                                          : popup.directParent.width - popup.width - Theme.halfPadding)
            popup.relativeY = Qt.binding(() => -popup.height - Theme.halfPadding)
            popup.gifSelected.connect(url => {
                _d.cbOnGifSelected(url)

                if (_d.closeAfterSelection) {
                    popup.close()
                }
            })
            popup.enableThirdpartyServicesRequested.connect(() => root.enableThirdpartyServicesRequested())
            popup.closed.connect(() => {
                _d.cbOnClose()
                popup.destroy()
            })
        }
    }
}
