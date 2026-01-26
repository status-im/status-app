import QtQuick

import shared.status

import StatusQ.Core.Utils

StatusInputListPopup {
    id: root

    property string shortname
    property string unicode: {
        if(listView.currentIndex < 0 || listView.currentIndex >= root.modelList.length)
            return ""

        return root.modelList[listView.currentIndex].unicode
    }

    getImageSource: function (modelData) {
        return Emoji.svgImage(modelData.unicode)
    }
    getText: function (modelData) {
        return modelData.shortname
    }
    getId: function (modelData) {
        return modelData.unicode
    }

    function openPopup(emojisParam, shortnameParam) {
        modelList = emojisParam
        shortname = shortnameParam
        root.open()
    }
}
