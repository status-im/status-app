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

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.nodeUrl))
        loadSection()
    }

    onActiveChanged: loadSection()
    onLoaded: item.anchors.fill = root
}
