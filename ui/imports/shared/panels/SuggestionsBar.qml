import QtQuick
import QtQuick.Controls
import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property alias model: content.model

    signal wordSelected(word: string)

    padding: Theme.halfPadding

    background: Rectangle {
        color: Theme.palette.baseColor4

        radius: 6
    }

    contentItem: ListView {
        id: content

        orientation: Qt.Horizontal
        clip: true

        spacing: 10
        implicitHeight: 30

        delegate: Rectangle {
            objectName: `seedWordSuggestion${index}`

            required property int index
            required property string seedWord

            color: Theme.palette.background
            width: text.implicitWidth
            height: content.height

            radius: 4

            StatusBaseText {
                id: text

                height: parent.height
                rightPadding: Theme.smallPadding
                leftPadding: Theme.smallPadding

                text: seedWord

                color: Theme.palette.primaryColor1

                verticalAlignment: Text.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: containsMouse ? Qt.PointingHandCursor : undefined
                    onClicked: root.wordSelected(seedWord)
                }
            }
        }
    }
}
