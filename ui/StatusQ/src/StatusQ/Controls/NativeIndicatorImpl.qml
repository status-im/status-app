import QtQuick 2.15

Item {
    id: root

    property url source: ""

    Image {
        anchors.fill: parent
        source: root.source
        smooth: true
        fillMode: Image.PreserveAspectFit
    }
}


