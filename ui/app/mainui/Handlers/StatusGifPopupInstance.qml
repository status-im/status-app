import StatusQ.Core.Theme

import shared.status
import shared.stores

StatusGifPopup {
    id: popup

    required property GifStore gifStore
    // undefined: aligned to the right edge of directParent
    property var preferredRelativeX

    width: 360
    height: 440

    relativeX: popup.preferredRelativeX !== undefined ? popup.preferredRelativeX
                                                      : popup.directParent.width - popup.width - Theme.halfPadding
    relativeY: -popup.height - Theme.halfPadding

    loading: popup.gifStore.gifLoading
    gifColumnA: popup.gifStore.gifColumnA
    gifColumnB: popup.gifStore.gifColumnB
    gifColumnC: popup.gifStore.gifColumnC

    isFavorite: popup.gifStore.isFavorite
    addToRecentsGif: popup.gifStore.addToRecentsGif
    searchGifsRequest: popup.gifStore.searchGifs
    getTrendingsGifs: popup.gifStore.getTrendingsGifs
    getFavoritesGifs: popup.gifStore.getFavoritesGifs
    getRecentsGifs: popup.gifStore.getRecentsGifs
    toggleFavoriteGif: popup.gifStore.toggleFavoriteGif
    setGifUnfurlingEnabled: popup.gifStore.setGifUnfurlingEnabled
}
