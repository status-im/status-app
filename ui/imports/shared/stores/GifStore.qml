import QtQuick

QtObject {
    readonly property QtObject _d: QtObject {
        id: d

        readonly property var gifsModuleInst: typeof gifsModule !== "undefined"
                                              ? gifsModule : null
    }

    property var gifColumnA: d.gifsModuleInst ? d.gifsModuleInst.gifColumnA : null
    property var gifColumnB: d.gifsModuleInst ? d.gifsModuleInst.gifColumnB : null
    property var gifColumnC: d.gifsModuleInst ? d.gifsModuleInst.gifColumnC : null
    property bool gifLoading: d.gifsModuleInst ? d.gifsModuleInst.gifLoading : false

    function setGifUnfurlingEnabled(value) {
        localAccountSettings.gifUnfurlingEnabled = value
    }

    function searchGifs(query) {
        if (d.gifsModuleInst)
            d.gifsModuleInst.searchGifs(query)
    }

    function getTrendingsGifs() {
        if (d.gifsModuleInst)
            d.gifsModuleInst.getTrendingsGifs()
    }

    function getRecentsGifs() {
        if (d.gifsModuleInst)
            d.gifsModuleInst.getRecentsGifs()
    }

    function getFavoritesGifs() {
        return d.gifsModuleInst ? d.gifsModuleInst.getFavoritesGifs() : null
    }

    function isFavorite(id) {
        return d.gifsModuleInst ? d.gifsModuleInst.isFavorite(id) : null
    }

    function toggleFavoriteGif(id, reload) {
        if (d.gifsModuleInst)
            d.gifsModuleInst.toggleFavoriteGif(id, reload)
    }

    function addToRecentsGif(id) {
        if (d.gifsModuleInst)
            d.gifsModuleInst.addToRecentsGif(id)
    }
}
