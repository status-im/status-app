import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit
import SortFilterProxyModel

Flickable {
    id: root

    signal moreUpRequested
    signal moreDownRequested

    property bool moreUpAvailable: false
    property bool moreDownAvailable: false

    property Component fakeConversationPlaceholder

    property var model

    // True while a batch is still being built off-view.
    readonly property bool batchPending: proxyModel.loadCounter !== 0
    //property alias model: messagesView.model

    // Simulated device load, forwarded to every delegate. See MessageDelegate
    // for what each one buys.
    property int delegateBuildComplexity: 0
    property int delegatePaintComplexity: 0

    // Distance scrolled per "click" (120 units) of the mouse wheel. Flickable's
    // built-in wheel handling is hardcoded to wheelScrollLines * 24 (~72px) and
    // is driven by a private wheelDeceleration, so neither flickDeceleration nor
    // maximumFlickVelocity below have any effect on it - those apply to drag
    // flicks only. See the WheelHandler at the bottom of this file.
    property real wheelScrollPixels: 160

    // Kept short so the view tracks the wheel closely instead of coasting.
    property int wheelScrollDuration: 200

    contentWidth: root.width
    contentHeight: contentLayout.height

    QtObject {
        id: d

        // Cleared once the view has been put on the newest message for the first
        // time. See onContentHeightChanged.
        property bool initialPositionPending: true

        // The row the view is currently pinned to, if any, and the y it had when
        // it was last seen - so a move can be measured, not just observed.
        property Item anchorItem: null
        property real lastAnchorY: 0

        // Armed once the structural change is through, so the anchor can be let
        // go as soon as it has done its job.
        property bool releasePending: false
    }

    // `contentY: contentHeight - height` used to live here. As a declared binding
    // it re-asserted itself on *every* contentHeight change - so the moment a
    // batch landed, or rows left the window, the view was slammed back to the
    // bottom. It only appeared to work because installing an anchor binding from
    // JS replaced it. Position the view once, explicitly, and never again.
    onContentHeightChanged: {
        if (!d.initialPositionPending || messagesView.count === 0)
            return

        // Re-asserted on every change rather than done once: a content-sized
        // ListView reaches its real height over several passes, so the first
        // value is an estimate built from averageSize and lands short. Held
        // until the view is actually used - see releaseInitialPosition.
        root.contentY = root.contentHeight - root.height
    }

    // Stops holding the newest message in view. Called the moment the view is
    // put to use - a deliberate scroll, or a batch arriving - after which
    // position is whatever the user and the anchoring make it.
    function releaseInitialPosition() {
        d.initialPositionPending = false
    }

    // Pins the view to a row, so that whatever the layout does next the content
    // under the viewport stays where it is.
    //
    // Installed from the model's own signals rather than when more rows are
    // requested: the batch does not arrive for hundreds of milliseconds, and an
    // offset captured that long ago describes where the view was, not where it
    // is. Anything the user scrolled in between would be thrown away when the
    // binding finally fired.
    function anchorTo(item) {
        root.releaseInitialPosition()

        d.anchorItem = item

        if (!item)
            return

        d.lastAnchorY = root.anchorPosition()

        const offset = d.lastAnchorY - root.contentY

        root.contentY = Qt.binding(() => messagesView.y + item.y - offset)
    }

    // Where the anchored row sits in the coordinates the outer Flickable
    // scrolls. A ListView delegate's y is relative to the *ListView's* content
    // item, so on its own it does not say where the row is in the column - it is
    // short by the view's own y, which itself moves whenever the placeholder
    // above it resizes. Both terms have to be in the binding, which is why this
    // cannot be mapToItem(): a function call in a binding does not re-evaluate
    // when the positions it read change.
    function anchorPosition() {
        // `y` reads back undefined on a destroyed object whose JS wrapper is
        // still around, and that would poison contentY with NaN.
        if (!d.anchorItem || d.anchorItem.y === undefined)
            return 0

        return messagesView.y + d.anchorItem.y
    }

    // Fires once the anchored row has stopped moving, which is the only reliable
    // signal that the layout has finished reacting to the change.
    Timer {
        id: anchorReleaseDebounce

        interval: 50
        repeat: false

        onTriggered: {
            d.releasePending = false
            root.releaseAnchor()
        }
    }

    // Converts the anchor back into a plain value. Left installed, the binding
    // outlives the change it was for, and any later move of that row - an image
    // loading above it - would drag the view to an offset captured long ago.
    //
    // Deliberately not called when the user scrolls: a wheel scroll during the
    // wait for a batch is exactly the case the anchor exists to survive.
    function releaseAnchor() {
        if (!d.anchorItem)
            return

        root.contentY = root.contentY
        d.anchorItem = null
    }

    // A wheel scroll in flight is the one thing that can undo the anchor. It
    // drives contentY from a destination captured before the rows arrived, and
    // animations write with DontRemoveBinding - so the binding survives, fires,
    // and is then overwritten on the animation's very next tick. Move its
    // destination by however far the anchor moved and let it carry on from where
    // the view now is.
    Connections {
        target: d.anchorItem

        function onYChanged() {
            const position = root.anchorPosition()
            const delta = position - d.lastAnchorY
            d.lastAnchorY = position

            if (delta !== 0 && wheelScrollAnimation.running) {
                const retargeted = Math.max(0, wheelScrollAnimation.to + delta)

                wheelScrollAnimation.stop()
                wheelScrollAnimation.from = root.contentY
                wheelScrollAnimation.to = retargeted
                wheelScrollAnimation.start()
            }

            // Not released on the first move: a content-sized ListView settles
            // its height over several passes, so the first is rarely the last.
            // Wait for them to stop instead.
            if (delta !== 0 && d.releasePending)
                anchorReleaseDebounce.restart()
        }
    }

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

    // Flickable only reports itself as moving while being dragged or flicked, so
    // animating contentY directly leaves the attached ScrollBar inactive, and
    // therefore faded out. Drive its active state for the duration of a wheel
    // scroll instead; the style still owns the fade out delay.
    function setScrollBarActive(active) {
        const scrollBar = root.ScrollBar.vertical

        if (!scrollBar)
            return

        // leave the state alone when something else already owns it, otherwise
        // the bar would be hidden mid drag or while the pointer rests on it
        if (!active && (scrollBar.pressed || scrollBar.hovered || root.movingVertically))
            return

        scrollBar.active = active
    }

    // Asks for the next slice of the model when the viewport has reached one of
    // the placeholders. contentY is anchored to a delegate that survives the
    // shift, so the viewport stays on the same content once the new items are
    // inserted above or below it.
    function requestMoreIfPlaceholderReached() {
        if (messagesView.count === 0)
            return

        // One shift at a time. This runs every time a wheel scroll settles, and
        // scrolling keeps the placeholder in reach for as long as the batch takes
        // to build - so without this a steady scroll fires a request per notch.
        // Each one moves the window another 40 rows, and two of them overshoot a
        // 60 row window completely: every row the view was holding onto is
        // unloaded, there is nothing left to anchor to, and the message the user
        // was reading is no longer in the model at all. The placeholder stays put
        // meanwhile, so the next request simply happens once the batch has landed.
        if (root.batchPending)
            return

        // topPlaceholder collapses to zero height when there is nothing more to
        // load, which makes this false at contentY === 0
        const isTopPlaceholderVisible = root.contentY < topPlaceholder.height

        if (isTopPlaceholderVisible) {
            root.moreUpRequested()
            return
        }

        const isBottomPlaceholderVisible = bottomPlaceholder.visible &&
                                         root.contentY + root.height >= bottomPlaceholder.y

        if (isBottomPlaceholderVisible)
            root.moreDownRequested()
    }

    Connections {
        target: root.ScrollBar.vertical

        function onPressedChanged() {
            if (root.ScrollBar.vertical.pressed)
                return

            root.requestMoreIfPlaceholderReached()
        }
    }

    ColumnLayout {
        id: contentLayout

        width: root.width

        Loader {
            id: topPlaceholder

            Layout.fillWidth: true

            sourceComponent: fakeConversationPlaceholder
            active: root.moreUpAvailable
            visible: active
        }

        ListView {
            id: messagesView

            Layout.fillWidth: true

            // Sized to its own content, so it never scrolls itself and realises
            // every row of the window - the outer Flickable is still the thing
            // that scrolls. Note this is a feedback loop: the height decides
            // which rows are realised, those decide averageSize, and averageSize
            // decides contentHeight for the rows that are not
            // (qquicklistview.cpp:505-523, :913). It converges once the height
            // covers everything, but it takes a few passes to get there and does
            // so again after each batch.
            Layout.preferredHeight: contentHeight

            // Not optional. A ListView is a Flickable, this one sits inside
            // another, and pointer events are delivered innermost first - so
            // without this the inner view swallows the wheel before the outer
            // WheelHandler ever sees it.
            interactive: false

            // Delegates adopt an externally built instance, so they cannot be
            // recycled: a reused delegate is handed a different contentInstance
            // without Component.onCompleted running again, and the reparenting
            // below would never happen for it. Off is the default; stated here
            // because turning it on would break quietly.
            reuseItems: false

            // Every row of the window is meant to exist, and to keep existing.
            // Sized to its content the view's height dips while rows leave -
            // contentHeight is rebuilt from an averageSize estimate - and any
            // delegate outside that shrunken range is released and later rebuilt
            // as a different object. That breaks delegate identity across a
            // shift, which the anchoring depends on: it holds a reference to a
            // row and would be left pointing at a destroyed one. A buffer this
            // large simply never lets go.
            cacheBuffer: 1000000

            model: SortFilterProxyModel {

                sourceModel: ObjectProxyModel {
                    id: proxyModel
                    sourceModel: root.model

                    property int loadCounter: 0

                    onLoadCounterChanged: {
                        if (loadCounter === 0) {
                            console.log("X!")
                            for (let i = 0; i < proxyModel.rowCount(); i++) {
                                proxyModel.proxyObject(i).loaded = true
                            }
                        }

                    }

                    delegate: QtObject {
                        id: opmDelegate

                        property MessageDelegate contentInstance//: contentLoader.item
                        property bool loaded//: contentLoader.status === Loader.Ready

                        readonly property Loader contentLoader: Loader {
                            id: loader

                            asynchronous: true
                            // active: false

                            // Timer {
                            //     interval: 2000
                            //     running: true
                            //     onTriggered: {
                            //         loader.active = true
                            //     }
                            // }

                            Component.onCompleted: {
                                proxyModel.loadCounter++
                            }

                            sourceComponent: MessageDelegate {

                                width: contentLayout.width

                                text: model.text
                                images: model.images
                                date: model.date
                                avatar: model.avatar

                                //"text", "images", "date", "avatar"
                                buildComplexity: root.delegateBuildComplexity
                                paintComplexity: root.delegatePaintComplexity

                                Component.onCompleted: {
                                    opmDelegate.contentInstance = this
                                    proxyModel.loadCounter--
                                }

                            }
                        }
                    }

                    expectedRoles: ["text", "images", "date", "avatar"]
                    exposedRoles: ["contentInstance", "loaded"]

                }

                filters: ValueFilter {
                    roleName: "loaded"
                    value: true
                }

                // Only a change at the head displaces what is below it, and
                // therefore what the viewport is looking at; a change at the tail
                // moves nothing above it. QQmlDelegateModel connects to
                // rowsInserted and not to rowsAboutToBeInserted, so the Repeater's
                // items here are still the pre-change set.
                onRowsAboutToBeInserted: (parent, first, last) => {
                    // The very first fill also arrives at index 0, but there is
                    // nothing on screen to hold still and nothing to anchor to -
                    // and treating it as a shift would release the initial
                    // position before the view has even reached its height.
                    if (first === 0 && messagesView.count > 0)
                        root.anchorTo(messagesView.itemAtIndex(0))
                }

                // itemAt(last + 1), not itemAt(0): the rows being removed are
                // about to be destroyed, and a binding onto one of them would be
                // left pointing at nothing.
                onRowsAboutToBeRemoved: (parent, first, last) => {
                    if (first === 0)
                        root.anchorTo(messagesView.itemAtIndex(last + 1))
                }

                onRowsInserted: d.releasePending = !!d.anchorItem
                onRowsRemoved: d.releasePending = !!d.anchorItem
            }

            // A ListView positions its delegates itself, so these are plain
            // width/height rather than Layout attached properties.
            delegate: Item {
                width: ListView.view.width
                height: model.contentInstance.height

                Component.onCompleted: {
                    model.contentInstance.parent = this
                }
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
            root.releaseInitialPosition()

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

            root.setScrollBarActive(true)

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

        // Emitted on natural completion only - stop() during a burst of notches
        // does not emit it - so this runs once the scrolling settles rather than
        // on every notch.
        onFinished: {
            root.requestMoreIfPlaceholderReached()
            root.setScrollBarActive(false)
        }
    }
}
