import QtQuick 2.15
import QtQuick.Layouts 1.15

GridLayout {
    id: root

    property alias model: repeater.model

    columns: {
        switch (repeater.count) {
        case 1:
            return 1
        case 2:
        case 3:
        case 4:
        case 5:
            return 2
        default:
            return 3
        }
    }

    Repeater {
        id: repeater

        delegate: Image {
            source: model.url
            asynchronous: true

            // This property is important regarding memory consumption because
            // it sets the maximum number of pixels stored for the loaded image
            sourceSize: Qt.size(300, 300)

            Layout.columnSpan: {
                if (model.index !== 0)
                    return 1

                switch (repeater.count) {
                case 3:
                case 5:
                case 8:
                    return 2
                case 7:
                case 10:
                    return 3
                default:
                    return 1
                }
            }

            Layout.preferredWidth: 300 * Layout.columnSpan + root.columnSpacing * (Layout.columnSpan - 1)
            Layout.preferredHeight: 300

            fillMode: Image.PreserveAspectCrop

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
            }
        }
    }
}
