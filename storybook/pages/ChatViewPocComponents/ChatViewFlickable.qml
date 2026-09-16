import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    signal moreUpRequested
    signal moreDownRequested

    property bool moreUpAvailable: false
    property bool moreDownAvailable: false

    property Component fakeConversationPlaceholder

    property alias model: messagesRepeater.model

    // Distance scrolled per "click" (120 units) of the mouse wheel. Flickable's
    // built-in wheel handling is hardcoded to wheelScrollLines * 24 (~72px) and
    // is driven by a private wheelDeceleration, so neither flickDeceleration nor
    // maximumFlickVelocity below have any effect on it - those apply to drag
    // flicks only. See the WheelHandler at the bottom of this file.
    property real wheelScrollPixels: 160

    // Kept short so the view tracks the wheel closely instead of coasting.
    property int wheelScrollDuration: 200

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

    // Replaces Flickable's built-in wheel handling, which moves a fixed ~72px
    // per notch over a 300ms OutExpo curve and restarts that curve on every
    // notch, so spinning the wheel quickly barely scrolls further than spinning
    // it slowly. Pointer handlers are offered the event before the item itself
    // and WheelHandler is blocking by default, so the built-in path is bypassed.
    WheelHandler {
        // acceptedDevices is left at its default (Mouse) on purpose: trackpads
        // deliver pixel deltas in scroll phases and are better served by
        // Flickable's own handling, which gives them momentum.
        onWheel: (event) => {
            // High resolution wheels report deltas smaller than one full notch,
            // hence the proportional scaling rather than a per-event step.
            const notches = event.angleDelta.y / 120

            if (notches === 0)
                return

            root.cancelFlick()

            // Accumulate onto the pending target instead of the current position
            // so consecutive notches add up while the animation is still running.
            const origin = wheelScrollAnimation.running ? wheelScrollAnimation.to
                                                        : root.contentY

            const maxContentY = Math.max(0, root.contentHeight - root.height)
            const target = Math.max(0, Math.min(maxContentY,
                                                origin - notches * root.wheelScrollPixels))

            if (target === root.contentY)
                return

            wheelScrollAnimation.stop()
            wheelScrollAnimation.from = root.contentY
            wheelScrollAnimation.to = target
            wheelScrollAnimation.start()
        }
    }

    NumberAnimation {
        id: wheelScrollAnimation

        target: root
        property: "contentY"
        duration: root.wheelScrollDuration
        easing.type: Easing.OutQuad
    }
}
