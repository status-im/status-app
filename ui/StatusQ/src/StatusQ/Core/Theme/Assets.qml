pragma Singleton

import QtQml

QtObject {
    readonly property string assetPath: Qt.resolvedUrl("../../../assets/")

    function png(name) {
        return assetPath + "png/" + name + ".png"
    }
    function svg(name) {
        return assetPath + "img/icons/" + name + ".svg"
    }
    function emoji(name) {
        return assetPath + "twemoji/svg/" + name + ".svg"
    }
    function svgImg(name) {
        return assetPath + "img/" + name + ".svg"
    }
}
