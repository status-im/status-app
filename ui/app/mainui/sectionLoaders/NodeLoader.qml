import QtQml
import QtQuick

Loader {
    id: root

    property real leftPanelWidthOverride: 0

    asynchronous: false

    function loadSection() {
        if (!active)
            return
        if (!!item)
            return
        if (source === QmlCompiler.nodeUrl)
            return
        setSource(QmlCompiler.nodeUrl, {
            leftPanelWidthOverride: Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onActiveChanged: loadSection()
    onLoaded: item.anchors.fill = root
}
