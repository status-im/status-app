import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Flickable {
    id: root

    signal moreUpRequested
    signal moreDownRequested

    property bool moreUpAvailable: false
    property bool moreDownAvailable: false

    property Component fakeConversationPlaceholder

    property alias model: messagesRepeater.model

    contentY: contentHeight - height
    contentWidth: root.width
    contentHeight: content.height

    function moveDown() {
        // save "regular" values of max flick velocity and deceleration
        const maxVelocity = root.maximumFlickVelocity
        const deceleration = root.flickDeceleration

        root.contentY = root.contentY

        // set custom values for fast move
        root.maximumFlickVelocity = 2500 * 20
        root.flickDeceleration = 1500

        root.flick(0, -2500 * 20)

        // restore "regular" values
        root.maximumFlickVelocity = maxVelocity
        root.flickDeceleration = deceleration
    }

    Connections {
        target: root.ScrollBar.vertical


        function onPressedChanged() {
            if (root.ScrollBar.vertical.pressed)
                return

            const isTopPlaceholderVisible = root.contentY < topPlaceholder.height

            if (isTopPlaceholderVisible) {
                const first = messagesRepeater.itemAt(0)
                const offset = first.y - root.contentY

                root.contentY = Qt.binding(() => {
                    return first.y - offset
                })

                root.moreUpRequested()
            }

            const isBottomPlaceholderVisible = bottomPlaceholder.visible &&
                                             !isTopPlaceholderVisible &&
                                             root.contentY + root.height >= bottomPlaceholder.y

            if (isBottomPlaceholderVisible) {
                const last = messagesRepeater.itemAt(messagesRepeater.count - 1)

                const offset = root.contentY - last.y

                root.contentY = Qt.binding(() => {
                    return last.y + offset
                })

                root.moreDownRequested()
            }
        }
    }

    ColumnLayout {
        id: content

        width: root.width

        Loader {
            id: topPlaceholder

            Layout.fillWidth: true

            sourceComponent: fakeConversationPlaceholder
            active: root.moreUpAvailable
            visible: active
        }

        Repeater {
            id: messagesRepeater

            delegate: MessageDelegate {
                Layout.fillWidth: true
            }
        }

        Loader {
            id: bottomPlaceholder

            Layout.fillWidth: true

            sourceComponent: fakeConversationPlaceholder
            active: root.moreDownAvailable
            visible: active
        }
    }
}
