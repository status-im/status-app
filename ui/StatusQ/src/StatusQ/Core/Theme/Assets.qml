pragma ComponentBehavior: Bound

pragma Singleton

import QtQml

QtObject {
    readonly property string assetPath: Qt.resolvedUrl("../../../assets/")

    function png(name: string): string {
        return assetPath + "png/" + name + ".png"
    }
    function svg(name: string): string {
        return assetPath + "img/icons/" + name + ".svg"
    }
    function emoji(name: string): string {
        return assetPath + "twemoji/svg/" + name + ".svg"
    }
    function svgImg(name: string): string {
        return assetPath + "img/" + name + ".svg"
    }
}
