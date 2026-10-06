pragma ComponentBehavior: Bound

import QtCore

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Models
import Storybook

import QtModelsToolkit

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Utils

import "MessageDelegateComponents"

/*
  Harness for WindowedView and ItemPool. Three layers, each ignorant of the
  next but one:

    WindowedView   windowing, slides, batch reveal, anchoring. No roles, no
                   delegate type, no cache.
    this page      the binding policy - which role goes to which property.
    ItemPool       storage and construction of items. No roles.

  The middle layer is the point: role knowledge lives in exactly one place, and
  it is neither the view nor the cache.
*/
SplitView {
    id: root

    readonly property int initialMessageCount: 200

    // Inserts `count` freshly generated messages at `index`. Both ends are just
    // indices - 0 is the beginning, model.count the end - so there is one path
    // here regardless of what the panel asked for. With `instant`, the rows it
    // causes skip the pool's simulated delay.
    function insertMessages(count, index, instant) {
        const rows = d.createMessages(count)

        d.instantAcquire = instant === true

        if (index >= messagesModel.count)
            messagesModel.append(rows)
        else
            messagesModel.insert(Math.max(0, index), rows)

        d.instantAcquire = false
    }

    // Removes `count` messages starting at `index`. Mirrors insertMessages: an
    // index past the end means "from the end".
    function removeMessages(count, index) {
        const total = messagesModel.count

        if (total === 0)
            return 0

        const first = index >= total ? Math.max(0, total - count)
                                     : Math.max(0, index)
        const n = Math.min(count, total - first)

        if (n <= 0)
            return 0

        messagesModel.remove(first, n)
        return n
    }

    // Repeats a message-row shape down whatever space it is given, so the one
    // instance works both as a full-viewport screen and as a band at an end.
    Component {
        id: messageSkeleton

        LoadingSkeletonGroup {
            id: skeletonRoot

            Column {
                spacing: 0

                // As many whole rows as fit. At an end that divides exactly,
                // because the band is sized in rows; filling the viewport it
                // does not, and the band's clip takes the last one short.
                Repeater {
                    model: Math.max(1, Math.ceil(skeletonRoot.height
                                                 / d.placeholderRowHeight))

                    Item {
                        width: skeletonRoot.width
                        height: d.placeholderRowHeight

                        Row {
                            x: 16
                            y: 16
                            spacing: 16

                            LoadingSkeletonTile {
                                width: 40
                                height: 40
                                radius: 20
                            }

                            Column {
                                spacing: 8

                                LoadingSkeletonTile { width: 120; height: 12 }
                                LoadingSkeletonTile {
                                    width: Math.max(40, skeletonRoot.width - 220)
                                    height: 12
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: d

        // Control defaults, named so a control's initial value and what
        // "Restore defaults" puts back cannot drift apart.
        // The tail of the model, so the page opens with nothing more beyond the
        // bottom. Start at the head instead and the end band is on screen from
        // the first frame, and the window pages itself to the end on load.
        // The window always opens on the model's start - the newest message,
        // the way this model is ordered - and the direction only decides which
        // screen edge that start is drawn at.
        readonly property int openingWindowFirst: 0
        readonly property int defaultWindowSize: 60
        readonly property int defaultSlideStep: 10

        // 0 keeps the owner synchronous, which is what an index window really
        // is. Anything above zero stands in for a backend that answers later,
        // and is the only way the loading lights are on screen long enough to
        // see: a synchronous answer clears them inside the request call.
        readonly property int defaultAnswerDelay: 0

        // On by default here, where the harness is chat-shaped and the newest
        // message belongs at the bottom. The component itself defaults to off.
        readonly property bool defaultStickToBottom: true

        // On by default: the model here is newest-first, so this is the setting
        // that makes the page a chat. Turned off it shows the same model the
        // other way up, which is what the view did before it could do this.
        readonly property bool defaultBottomUp: true
        readonly property bool defaultAutoRequest: true
        readonly property bool defaultPlaceholder: true
        // The band is measured in placeholder rows rather than pixels, so it
        // always comes out a whole number of them.
        readonly property int placeholderRowHeight: 72
        readonly property int defaultPlaceholderRows: 10
        readonly property int defaultPrefetchMargin: 0

        readonly property bool defaultHeader: false
        readonly property bool defaultFooter: false
        readonly property int defaultSlotHeight: 48

        readonly property int defaultRowSource: 0
        readonly property int defaultPoolTarget: 80
        // The pool's own pacing, and what it falls back to after a boost.
        readonly property int defaultBackgroundInterval: 64
        readonly property bool defaultAsynchronous: true
        readonly property int defaultMinDelay: 0
        readonly property int defaultMaxDelay: 200

        readonly property int defaultInsertCount: 10
        // "Beginning": the model is newest-first, so inserting at its start is
        // what a message arriving looks like.
        readonly property int defaultInsertPosition: 1
        readonly property int defaultInsertIndex: 0

        // The crossing, in one place. The view names its edges after the screen
        // and the window after the model, and rendering bottom-up puts the
        // model's start at the bottom of the screen. Everything the page says to
        // one of them about an edge goes through here.
        readonly property bool bottomUp: bottomUpSwitch.checked

        function modelStartIsAtTheTop() {
            return !d.bottomUp
        }

        // Flipping the direction redraws every row at the other end of the
        // screen, so the opening position is worth establishing again.
        onBottomUpChanged: d.openAtTheStart()

        property bool answerAtTop: false

        // What "Capture position" stored, for "Restore" to put back. The key,
        // not the row: the row number would be wrong after the next prepend.
        property string capturedKey: ""
        property real capturedOffset: NaN

        // ---- Jumping to a row of the source model ----------------------
        //
        // The view can only position a row it holds, so a jump is up to two
        // steps: move the window onto the row, then position it. What keeps
        // that from showing as a two-step on screen is where the second step is
        // asked for - from batchRevealed(), which fires inside the reveal,
        // before the view has laid the batch out or corrected its position. The
        // request is pending for the rest of that turn and honoured by the same
        // reveal, so the rows appear already in the right place.
        //
        // The window move is wrapped in beginBatch()/endBatch(), so it is one
        // batch however it lands - every row replaced, or only some slid in -
        // and with an answer delay set it lands late, the way a backend fetch
        // would.
        //
        // Carried across as a key, never as a row number: moving the window
        // re-indexes everything the view holds.
        property string jumpKey: ""
        property int jumpMode: -1
        property real jumpOffset: NaN

        // rowForKey() is a linear scan, so nothing inside it tells QML when its
        // answer can change - and its two paths do not even read the same
        // properties: the one that finds a row reads the view's rowCount, the
        // one that finds nothing reads neither that nor anything else that ever
        // moves. A binding calling it directly therefore latches on its first
        // answer and never asks again.
        //
        // So the things that can change the answer are passed in. They are
        // unused here on purpose: being read in the binding expression is what
        // makes them dependencies, whichever path the scan then takes.
        function viewRowForKey(key, first, last, rows) {
            return windowedView.rowForKey(key)
        }

        function windowRowForKey(key, first, last, count) {
            return windowSource.rowForKey(key)
        }

        readonly property int trackedViewRow:
                d.viewRowForKey(trackedEntry.value, windowSource.first,
                                windowSource.last, windowedView.rowCount)

        readonly property int trackedWindowRow:
                d.windowRowForKey(trackedEntry.value, windowSource.first,
                                  windowSource.last, messagesModel.count)

        // The row the viewport top falls inside - the reading position, and so
        // what a window record stores. Found by position rather than by number,
        // because which row that is changes with every scroll.
        function rowAtViewportTop() {
            let best = -1
            let bestOffset = Number.MAX_VALUE

            for (let row = 0; row < windowedView.rowCount; ++row) {
                const offset = windowedView.viewportOffsetToRow(row)

                // positive means the viewport top is below this row's top, so
                // the smallest such offset is the row it sits in
                if (!isNaN(offset) && offset >= 0 && offset < bestOffset) {
                    bestOffset = offset
                    best = row
                }
            }

            return best
        }

        function captureReadingPosition() {
            const row = d.rowAtViewportTop()

            if (row < 0)
                return

            d.capturedKey = windowedView.keyAtRow(row) ?? ""
            d.capturedOffset = windowedView.viewportOffsetToRow(row)
        }

        function keyAtSourceRow(row) {
            if (row < 0 || row >= messagesModel.count)
                return ""

            return ModelUtils.get(messagesModel, row, "key") ?? ""
        }

        function jumpToSourceRow(row, mode) {
            d.jumpToKey(d.keyAtSourceRow(row), mode, NaN)
        }

        function jumpToKey(key, mode, offset) {
            if (!key)
                return

            d.jumpKey = key
            d.jumpMode = mode
            d.jumpOffset = offset

            // Already on screen: no window move, nothing to wait for.
            if (d.applyJump())
                return

            // Otherwise bring it into the window, as one batch.
            windowedView.beginBatch()

            if (answerDelaySpinBox.value <= 0) {
                d.moveWindowToJump()
                return
            }

            jumpAnswerTimer.interval = answerDelaySpinBox.value
            jumpAnswerTimer.restart()
        }

        function moveWindowToJump() {
            if (!windowSource.moveToKey(d.jumpKey))
                d.clearJump()

            windowedView.endBatch()
        }

        function applyJump() {
            if (!d.jumpKey)
                return false

            const row = windowedView.rowForKey(d.jumpKey)

            if (row < 0)
                return false

            const accepted = isNaN(d.jumpOffset)
                           ? windowedView.positionViewAtRow(row, d.jumpMode)
                           : windowedView.positionViewAtRowOffset(
                                 row, d.jumpOffset)

            d.clearJump()
            return accepted
        }

        function clearJump() {
            d.jumpKey = ""
            d.jumpMode = -1
            d.jumpOffset = NaN
        }

        // The page opens on the newest content, which is where reading starts
        // in both directions - the bottom of the screen rendering bottom-up,
        // the top of it otherwise. Stated here rather than left to
        // stickToBottom, so the opening position does not depend on a switch.
        function openAtTheStart() {
            windowSource.moveTo(d.openingWindowFirst)

            // Moving the window starts a fresh fill, and the reveal is what
            // lands the viewport - see below. If it started nothing, the
            // geometry is already known and there is nothing to wait for.
            if (!windowedView.busy)
                landTimer.restart()
        }

        // A condition rather than a remembered intent: after a fresh fill the
        // viewport goes to the opening edge exactly when the window is still
        // sitting where the page opens. Jumping the window by hand moves it off
        // there, so a hand jump keeps the position moveTo() gave it - and no
        // ordering between the flip, the rebuild and the reveal can leave a
        // one-shot flag spent on the wrong frame.
        //
        // Bottom-up the model's start is drawn at the bottom, so that is the
        // edge to land on; top-down it is drawn at the top.
        function landAtTheOpeningEdge() {
            if (windowSource.first !== d.openingWindowFirst)
                return

            windowedView.contentY = d.bottomUp
                    ? Math.max(0, windowedView.contentHeight
                                  - windowedView.height)
                    : 0
        }

        function fetch(atTop) {
            if (answerDelaySpinBox.value <= 0) {
                d.deliver(atTop)
                return
            }

            d.answerAtTop = atTop
            answerTimer.interval = answerDelaySpinBox.value
            answerTimer.restart()
        }

        // Admitting and answering together: the rows and the "that is all" come
        // from the same reply. Which model end to grow is the screen edge the
        // view asked at, crossed; which end to answer at is the one it asked at,
        // uncrossed.
        function deliver(atTop) {
            const atModelStart = atTop === d.modelStartIsAtTheTop()

            if (atModelStart)
                windowSource.growStart(slideStepSpinBox.value)
            else
                windowSource.growEnd(slideStepSpinBox.value)

            if (atTop)
                windowedView.moreLoadedTop()
            else
                windowedView.moreLoadedBottom()
        }

        function restoreDefaults() {
            windowSizeSpinBox.value = d.defaultWindowSize
            slideStepSpinBox.value = d.defaultSlideStep
            answerDelaySpinBox.value = d.defaultAnswerDelay
            stickToBottomSwitch.checked = d.defaultStickToBottom
            bottomUpSwitch.checked = d.defaultBottomUp
            autoRequestSwitch.checked = d.defaultAutoRequest
            placeholderSwitch.checked = d.defaultPlaceholder
            placeholderRowsSpinBox.value = d.defaultPlaceholderRows
            prefetchMarginSpinBox.value = d.defaultPrefetchMargin
            headerSwitch.checked = d.defaultHeader
            footerSwitch.checked = d.defaultFooter
            slotHeightSpinBox.value = d.defaultSlotHeight
            rowSourceComboBox.currentIndex = d.defaultRowSource
            poolTargetSpinBox.value = d.defaultPoolTarget
            intervalSpinBox.value = d.defaultBackgroundInterval
            asyncSwitch.checked = d.defaultAsynchronous
            minDelaySpinBox.value = d.defaultMinDelay
            maxDelaySpinBox.value = d.defaultMaxDelay
            countSpinBox.value = d.defaultInsertCount
            positionComboBox.currentIndex = d.defaultInsertPosition
            indexSpinBox.value = d.defaultInsertIndex

            // Last: the edge it lands on follows the direction, which has just
            // been put back.
            d.openAtTheStart()
        }

        // ---- The two row sources ---------------------------------------
        //
        // The view asks the same question either way - "a row item for this
        // row, please" - and everything that differs is on this side of the
        // call. ItemPool builds on demand and answers through a callback;
        // DelegatePool only ever hands out what it has already built, so a dry
        // moment has to be waited out, and RowBinder does the dressing the
        // page does by hand for the other one.
        readonly property bool fromRowPool: rowSourceComboBox.currentIndex === 1
        readonly property string poolKind: rowPool.kind

        // Rows that asked while the pool was dry, waiting for an item to be
        // released or built. Not an error: the pool paces its building on
        // purpose, and the view tolerates a late answer.
        property var starvedQueue: []
        property int starvedCount: 0

        // What the readouts bind to. readyCount() is a function and mutating
        // starvedQueue in place notifies nothing, so neither can be read from
        // a binding - these are republished where they change.
        property int waitingCount: 0
        property int readyCount: 0

        function republishPool() {
            d.waitingCount = d.starvedQueue.length
            d.readyCount = rowPool.readyCount(d.poolKind)
        }

        // Switching source leaves the rows that are already dressed alone -
        // they belong to the pool that built them, and the view has no reason
        // to ask again - so the model is dropped for a turn, which releases
        // every row and rebuilds the window from the new source.
        property bool rebuilding: false

        onFromRowPoolChanged: {
            d.clearStarved()
            d.rebuilding = true
            rowSourceTimer.restart()
        }

        function acquire(shell, row, modelRow, cb) {
            if (d.fromRowPool)
                d.acquireFromRowPool(shell, row, cb)
            else
                d.acquireFromItemPool(shell, modelRow, cb)
        }

        function acquireFromItemPool(shell, modelRow, cb) {
            itemPool.acquire(shell, (obj) => {
                // Every role binding is guarded twice over, because a row on
                // its way out fails in two different ways: the row object is
                // destroyed before the shell that holds these bindings, and
                // before that it survives as an object whose role reads have
                // already gone undefined. A null check alone catches only the
                // first.
                obj.width = Qt.binding(() => (shell ? shell.width : undefined) ?? 0)
                obj.text = Qt.binding(() => (modelRow ? modelRow.messageText : undefined) ?? "")
                obj.images = Qt.binding(() => (modelRow ? modelRow.messageImages : undefined) ?? [])
                obj.date = Qt.binding(() => (modelRow ? modelRow.messageDate : undefined) ?? new Date(0))
                obj.avatar = Qt.binding(() => (modelRow ? modelRow.messageAvatar : undefined) ?? "")

                cb(obj)
            }, d.instantAcquire)
        }

        function acquireFromRowPool(shell, row, cb) {
            const item = rowPool.acquire(d.poolKind)

            if (!item) {
                d.starvedQueue.push({ shell, cb })
                d.starvedCount++
                d.republishPool()
                return
            }

            d.dressFromRowPool(item, shell, row)
            cb(item)
            d.republishPool()
        }

        function dressFromRowPool(item, shell, row) {
            // Width is not a role, so the binder does not do it.
            item.width = Qt.binding(() => (shell ? shell.width : undefined) ?? 0)

            // Bound to the window, by number: the binder holds a persistent
            // index from here on, so it follows the row as the window shifts
            // it and lets go when the row leaves.
            item.binder.bind(windowSource.model, row)

            // Last, and easy to forget: acquire() only un-parks the item, it
            // does not hand it over. Until it is put in the shell it stays a
            // child of the pool's own container - dressed, measured, and drawn
            // nowhere. Last so that nothing is ever on screen half dressed.
            item.parent = shell
        }

        function drainStarved() {
            while (d.starvedQueue.length > 0) {
                const waiting = d.starvedQueue[0]

                // A row that left the window while it waited never had content
                // to hand back, so the view never said anything about it - a
                // destroyed shell reads as null from JS, and that is the only
                // notice there is.
                if (!waiting.shell) {
                    d.starvedQueue.shift()
                    d.republishPool()
                    continue
                }

                const item = rowPool.acquire(d.poolKind)

                if (!item)
                    return

                d.starvedQueue.shift()
                d.dressFromRowPool(item, waiting.shell, waiting.shell.row)
                waiting.cb(item)
                d.republishPool()
            }
        }

        function clearStarved() {
            d.starvedQueue = []
            d.starvedCount = 0
            d.republishPool()
        }

        function release(obj) {
            // Self-describing, not mode-describing: an item handed out before
            // the switch flipped has to go back to the pool that built it,
            // whichever source is selected now.
            if (obj.binder !== undefined) {
                obj.binder.detach()
                // Breaks the width binding without disturbing the value. The
                // next bind is the reset for everything the binder wrote.
                obj.width = obj.width
                rowPool.release(obj)
                d.republishPool()
                return
            }

            // The page installed these bindings, so the page drops them. Left
            // in place they keep evaluating against a row object that no longer
            // exists, which is where the undefined-role warnings come from -
            // and ItemPool cannot do it, since it does not know the roles.
            obj.text = ""
            obj.images = []
            obj.date = new Date(0)
            obj.avatar = ""
            obj.width = 0

            itemPool.release(obj)
        }

        // The pool paces its building to stay out of the way, which is not
        // what a window waiting on it wants: for as long as any row is queued,
        // ask for priority. Cleared again once nothing is waiting, so the pool
        // goes back to filling itself in the background.
        //
        // Hung off the queue rather than off initialLoading, which the view
        // drops as soon as it stops calling the population fresh - long before
        // the rows have their items.
        onWaitingCountChanged: {
            if (!d.fromRowPool)
                return

            if (d.waitingCount > 0)
                d.boostForFill()
            else
                rowPool.clearBoost(d.poolKind)
        }

        function boostForFill() {
            if (d.fromRowPool)
                rowPool.boost(d.poolKind, windowSizeSpinBox.value)
        }

        // The one model operation that changes a row rather than the set of
        // rows - which is where the two sources differ: a hand-written binding
        // follows the role by itself, and RowBinder is told by dataChanged.
        property int touchSerial: 0

        function touchRow(row) {
            if (row < 0 || row >= messagesModel.count)
                return

            messagesModel.setProperty(row, "messageText",
                                      "**edited " + (++d.touchSerial)
                                      + "** this row was changed in place")
        }

        // True only while insertMessages() is causing rows that should not
        // wait. The Repeater builds them synchronously inside the model
        // change, so the flag only has to stand for the duration of the call.
        property bool instantAcquire: false

        function panelInsertIndex() {
            return {
                "Beginning": 0,
                "End": messagesModel.count,
                "Index": indexSpinBox.value
            }[positionComboBox.currentValue]
        }

        // Sample data ////////////////////////////////////////////////////////
        //
        // Deterministic on purpose - every reload gives the same heights, so
        // what the view does is comparable between runs. Each message carries
        // its own serial, so an insertion is visible for what it is.

        readonly property var lorem:
            ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor "
           + "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis "
           + "nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo "
           + "consequat.").split(" ")

        // The next serial to hand out. Serials only ever go up, so a higher one
        // is a newer message whichever way round the model holds them.
        property int nextSerial: 0

        function createMessage(serial) {
            const i = serial

            const words = []
            const wordCount = 3 + (i * 7) % 60

            for (let w = 0; w < wordCount; w++)
                words.push(d.lorem[(i + w) % d.lorem.length])

            // Every 11th message carries 1-3 images. ImageGrid reserves a
            // fixed 300px per image, so a row's height is known before any of
            // them has loaded - which is what keeps them out of the anchoring.
            const images = []
            const imageCount = i % 11 === 0 ? 1 + i % 3 : 0

            for (let j = 0; j < imageCount; j++)
                images.push({ url: `https://picsum.photos/id/${(i + j) % 70}/1200/1300` })

            return {
                // Stable identity: WindowedView captures batch membership by
                // key rather than by when a shell happened to be created.
                key: "m" + i,
                messageText: `**#${i}** ` + words.join(" "),
                messageImages: images,
                messageDate: new Date(2024, 0, 1 + i),
                messageAvatar: ModelsData.icons.status
            }
        }

        // Fresh messages, newest last - which is the order to *insert* in, not
        // the order the model holds.
        function createMessages(count) {
            const rows = []

            for (let i = 0; i < count; i++)
                rows.push(d.createMessage(d.nextSerial++))

            return rows
        }

        // The initial population, newest *first*, the way a chat backend hands
        // messages over: row 0 is the newest, and older ones follow. Rendered
        // BottomToTop that comes out as a chat - oldest at the top, newest at
        // the bottom - and a message arriving later goes in at row 0.
        function createInitialMessages(count) {
            const rows = []

            for (let i = count - 1; i >= 0; i--)
                rows.push(d.createMessage(i))

            d.nextSerial = count
            return rows
        }
    }

    // The data owner: it decides what "more" means, and answers the view's
    // requests by moving an index window's bounds.
    IndexWindowSource {
        id: windowSource

        sourceModel: messagesModel

        // A row arriving where the user already is should just appear; one
        // arriving while they are reading further up should be announced by the
        // placeholder instead. Which model end that is depends on which way the
        // view renders: bottom-up, the newest row is at the model's start.
        followsStart: d.bottomUp && windowedView.atBottom
        followsEnd: !d.bottomUp && windowedView.atBottom

        // The control owns the steady size; the position is set through
        // moveTo(), since first/last are read-only by design.
        size: windowSizeSpinBox.value
    }

    ListModel {
        id: messagesModel

        Component.onCompleted: append(d.createInitialMessages(root.initialMessageCount))
    }

    // What the page puts in the view's slots. Sized from the spin box in the
    // panel, so the space a slot takes can be grown and shrunk while watching
    // what the rows do.
    Component {
        id: headerBannerComponent

        Rectangle {
            implicitHeight: slotHeightSpinBox.value
            color: "#2f3d5c"

            Label {
                anchors.centerIn: parent

                color: "white"
                text: "header - the start of the layout direction"
            }
        }
    }

    Component {
        id: footerBannerComponent

        Rectangle {
            implicitHeight: slotHeightSpinBox.value
            color: "#5c3d2f"

            Label {
                anchors.centerIn: parent

                color: "white"
                text: "footer - the end of it"
            }
        }
    }

    // What a row looks like. The view never sees this.
    Component {
        id: messageComponent

        MessageDelegate {
            // A pooled item exists before it is ever bound to a row, and is
            // parked again afterwards. Without values its own bindings can
            // survive - MessageDelegate calls toLocaleDateString on `date` -
            // an undressed item throws on every evaluation.
            text: ""
            images: []
            date: new Date(0)
            avatar: ""
        }
    }

    // The second row source. In its own file because the pool incubates its
    // delegate with no creation context, which a component declared in this
    // file - `pragma ComponentBehavior: Bound` - refuses to be instantiated
    // outside of.
    BoundRowPool {
        id: rowPool

        // A window's worth plus the chunk a slide overlaps by, and more if the
        // panel asks for it. Never less: a pool that cannot cover the window
        // leaves rows waiting on an item it will never build - it stops at its
        // target, the boost clears itself for want of anything to build, and
        // the view reveals what arrived and holds the rest. An app-level owner
        // carries the same obligation, which is why the chat sizes its target
        // from the view rather than from a setting.
        readonly property int needed: windowSizeSpinBox.value
                                      + slideStepSpinBox.value

        target: Math.max(poolTargetSpinBox.value, needed)
        backgroundIntervalMs: intervalSpinBox.value
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: "#1b1b1f"

        // Declared here rather than directly under the SplitView: ItemPool is
        // an Item, and every Item in a SplitView is a candidate pane.
        ItemPool {
            id: itemPool

            delegate: messageComponent

            target: poolTargetSpinBox.value
            asynchronous: asyncSwitch.checked
            minDelay: minDelaySpinBox.value
            maxDelay: maxDelaySpinBox.value
        }

        WindowedView {
            id: windowedView

            anchors.fill: parent

            model: d.rebuilding ? null : windowSource.model

            verticalLayoutDirection: d.bottomUp
                    ? WindowedView.VerticalLayoutDirection.BottomToTop
                    : WindowedView.VerticalLayoutDirection.TopToBottom

            // Crossed when rendering bottom-up: what lies above the top row is
            // then the model's *end*.
            moreAvailableTop: d.modelStartIsAtTheTop()
                              ? windowSource.moreAvailableStart
                              : windowSource.moreAvailableEnd
            moreAvailableBottom: d.modelStartIsAtTheTop()
                                 ? windowSource.moreAvailableEnd
                                 : windowSource.moreAvailableStart

            stickToBottom: stickToBottomSwitch.checked

            autoRequest: autoRequestSwitch.checked

            placeholder: placeholderSwitch.checked ? messageSkeleton : null
            placeholderHeight: placeholderRowsSpinBox.value
                               * d.placeholderRowHeight
            prefetchMargin: prefetchMarginSpinBox.value

            // With no delay this answers inside the signal, which is what an
            // index window really is - it has the rows already. With one, the
            // rows are admitted only when the delay is up, the way an owner
            // talking to a backend behaves: nothing exists until the reply
            // lands. The view cannot tell the difference either way.
            onMoreRequestedTop: d.fetch(true)
            onMoreRequestedBottom: d.fetch(false)

            // Deferred removals happen here, in the reveal's own turn, so both
            // ends of the window change together - and a jump waiting for its
            // row is positioned from here for the same reason: the view has not
            // laid this batch out yet, so the request lands in this turn.
            onBatchRevealed: {
                windowSource.trim()
                d.applyJump()
            }

            header: headerSwitch.checked ? headerBannerComponent : null
            footer: footerSwitch.checked ? footerBannerComponent : null

            ScrollBar.vertical: ScrollBar {}

            // The binding policy lives in the page either way - which role
            // goes to which property, and who builds the item that holds it.
            acquireDelegate: d.acquire
            releaseDelegate: d.release
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 420
        SplitView.preferredWidth: 420

        // Taller than the panel, so the controls scroll. contentWidth is
        // pinned to the viewport so only the vertical direction ever moves: a
        // row too wide to fit wraps or clips rather than sliding the whole
        // panel sideways.
        ScrollView {
            id: controlsScroll

            anchors.fill: parent
            clip: true

            contentWidth: availableWidth

            ColumnLayout {
                width: controlsScroll.availableWidth

                spacing: 4

                Label {
                    text: "View"
                    font.bold: true
                }

                Label { text: "Rows in the window: " + windowedView.rowCount }
                Label { text: "Window (model rows): " + windowSource.first
                              + "-" + windowSource.last }
                Label { text: "Rows in the model: " + messagesModel.count }
                Label {
                    text: "Drawn: " + (d.bottomUp ? "model row " + windowSource.last
                                                    + " at the top, "
                                                    + windowSource.first
                                                    + " at the bottom"
                                                  : "model row " + windowSource.first
                                                    + " at the top, "
                                                    + windowSource.last
                                                    + " at the bottom")
                }

                Item { Layout.preferredHeight: 8 }

                Label {
                    text: "Cache"
                    font.bold: true
                }

                // Where the view's rows come from. The view is identical
                // either way; everything that differs is in the page.
                ComboBox {
                    id: rowSourceComboBox

                    Layout.fillWidth: true

                    model: ["ItemPool, bindings by hand",
                            "DelegatePool, RowBinder"]
                    currentIndex: d.defaultRowSource
                }

                Label {
                    visible: !d.fromRowPool

                    text: "built " + itemPool.builtCount
                          + "  |  in use " + itemPool.acquiredCount
                          + "  |  parked " + itemPool.availableCount
                }

                Label {
                    visible: d.fromRowPool

                    text: "ready " + d.readyCount
                          + " of " + rowPool.target
                          + "  |  waiting on the pool " + d.waitingCount
                          + "  |  starved " + d.starvedCount
                          + (rowPool.boosted ? "  |  boosted" : "")
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Target" }

                    SpinBox {
                        id: poolTargetSpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: 1000
                        stepSize: 10
                        value: d.defaultPoolTarget
                        editable: true
                    }
                }

                Switch {
                    id: asyncSwitch

                    Layout.fillWidth: true
                    visible: !d.fromRowPool

                    text: "Asynchronous"
                    checked: d.defaultAsynchronous
                }

                // The two bounds cap each other, so the range cannot be inverted.
                RowLayout {
                    Layout.fillWidth: true
                    visible: !d.fromRowPool

                    Label { text: "Min delay" }

                    SpinBox {
                        id: minDelaySpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: maxDelaySpinBox.value
                        stepSize: 50
                        value: d.defaultMinDelay
                        editable: true

                        textFromValue: (value) => value + " ms"
                        valueFromText: (text) => parseInt(text)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !d.fromRowPool

                    Label { text: "Max delay" }

                    SpinBox {
                        id: maxDelaySpinBox

                        Layout.fillWidth: true

                        from: minDelaySpinBox.value
                        to: 5000
                        stepSize: 50
                        value: d.defaultMaxDelay
                        editable: true

                        textFromValue: (value) => value + " ms"
                        valueFromText: (text) => parseInt(text)
                    }
                }

                // How far apart the pool starts its background builds. It also
                // yields to any other incubation in flight, so this is a floor
                // rather than a rate.
                RowLayout {
                    Layout.fillWidth: true
                    visible: d.fromRowPool

                    Label { text: "Build interval" }

                    SpinBox {
                        id: intervalSpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: 1000
                        stepSize: 16
                        value: d.defaultBackgroundInterval
                        editable: true

                        textFromValue: (value) => value + " ms"
                        valueFromText: (text) => parseInt(text)
                    }
                }

                Button {
                    Layout.fillWidth: true
                    visible: d.fromRowPool

                    text: "Boost to a window's worth"
                    enabled: !rowPool.boosted

                    onClicked: d.boostForFill()
                }

                Item { Layout.preferredHeight: 8 }

                Label {
                    text: "Window"
                    font.bold: true
                }

                // The upper bound never dips below the initial row count: a stored
                // value is restored from a C++ componentComplete, before any
                // Component.onCompleted has populated the model, and a `to` of 0
                // would clamp it to 0 for good.
                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "First" }

                    SpinBox {
                        id: windowFirstSpinBox

                        Layout.fillWidth: true

                        enabled: !windowedView.busy

                        from: 0
                        to: Math.max(messagesModel.count, root.initialMessageCount) - 1
                        stepSize: 10
                        editable: true

                        value: windowSource.first

                        onValueModified: windowSource.moveTo(value)
                        // read-only on the source, so nothing else can desync it
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Size" }

                    SpinBox {
                        id: windowSizeSpinBox

                        Layout.fillWidth: true

                        enabled: !windowedView.busy

                        from: 1
                        to: 1000
                        stepSize: 10
                        editable: true

                        value: d.defaultWindowSize
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Slide by" }

                    SpinBox {
                        id: slideStepSpinBox

                        Layout.fillWidth: true

                        from: 1
                        to: 1000
                        stepSize: 10
                        value: d.defaultSlideStep
                        editable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Answer delay" }

                    SpinBox {
                        id: answerDelaySpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: 5000
                        stepSize: 100
                        value: d.defaultAnswerDelay
                        editable: true
                    }
                }

                Switch {
                    id: stickToBottomSwitch

                    Layout.fillWidth: true

                    text: "Stick to bottom"
                    checked: d.defaultStickToBottom
                }

                Switch {
                    id: bottomUpSwitch

                    Layout.fillWidth: true

                    text: "Bottom to top"
                    checked: d.defaultBottomUp
                }

                Switch {
                    id: autoRequestSwitch

                    Layout.fillWidth: true

                    text: "Auto request"
                    checked: d.defaultAutoRequest
                }

                Switch {
                    id: placeholderSwitch

                    Layout.fillWidth: true

                    text: "Placeholder"
                    checked: d.defaultPlaceholder
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Placeholder rows" }

                    SpinBox {
                        id: placeholderRowsSpinBox

                        Layout.fillWidth: true

                        from: 1
                        to: 20
                        value: d.defaultPlaceholderRows
                        editable: true
                    }
                }

                // Asks this far ahead of a band showing, so a batch can be
                // revealed before its placeholder is ever on screen.
                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Prefetch margin (px)" }

                    SpinBox {
                        id: prefetchMarginSpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: 2000
                        stepSize: 50
                        value: d.defaultPrefetchMargin
                        editable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    // Named after the screen, like the view's own edges, and
                    // enabled from whichever model end that turns out to be.
                    Button {
                        Layout.fillWidth: true

                        text: "Slide up"
                        enabled: !windowedView.busy && windowedView.moreAvailableTop

                        onClicked: windowedView.requestMoreTop()
                    }

                    Button {
                        Layout.fillWidth: true

                        text: "Slide down"
                        enabled: !windowedView.busy && windowedView.moreAvailableBottom

                        onClicked: windowedView.requestMoreBottom()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: 12

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10

                            radius: width / 2
                            color: windowedView.loadingTop ? "#2ecc71" : "#bdbdbd"
                        }

                        Label { text: "Loading top" }
                    }

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10

                            radius: width / 2
                            color: windowedView.loadingBottom ? "#2ecc71" : "#bdbdbd"
                        }

                        Label { text: "Loading bottom" }
                    }

                    // Lit while an admitted batch is being made ready: shells built,
                    // content acquired, heights settling. With a zero answer delay
                    // this is where a slide spends all of its time.
                    RowLayout {
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10

                            radius: width / 2
                            color: windowedView.staging ? "#2ecc71" : "#bdbdbd"
                        }

                        Label { text: "Staging batch" }
                    }

                    // Lit while a fresh population - the first load, or a jump from
                    // the First control - is staged and showing nothing yet.
                    RowLayout {
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10

                            radius: width / 2
                            color: windowedView.initialLoading ? "#2ecc71" : "#bdbdbd"
                        }

                        Label { text: "Initial load" }
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.preferredHeight: 8 }

                Label {
                    text: "Header and footer"
                    font.bold: true
                }

                // Which screen edge each lands at follows the direction, as
                // ListView's do: the header goes at the start of it.
                Label {
                    text: "Drawn: header at the "
                          + (d.bottomUp ? "bottom" : "top")
                          + ", footer at the "
                          + (d.bottomUp ? "top" : "bottom")
                }

                Switch {
                    id: headerSwitch

                    Layout.fillWidth: true

                    text: "Header"
                    checked: d.defaultHeader
                }

                Switch {
                    id: footerSwitch

                    Layout.fillWidth: true

                    text: "Footer"
                    checked: d.defaultFooter
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Slot height" }

                    SpinBox {
                        id: slotHeightSpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: 600
                        stepSize: 10
                        value: d.defaultSlotHeight
                        editable: true
                    }
                }

                Item { Layout.preferredHeight: 8 }

                Label {
                    text: "Addressing"
                    font.bold: true
                }

                // The whole jump, as the app will have to do it: a row of the
                // *source* model goes in, and whatever has to happen for it to
                // end up on screen happens - the window moves when the row is
                // outside it, and the position is applied inside the reveal
                // that brings the row in, so there is one frame rather than a
                // visible two-step.
                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Go to source row" }

                    SpinBox {
                        id: jumpIndexSpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: Math.max(0, messagesModel.count - 1)
                        stepSize: 10
                        value: 100
                        editable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    ComboBox {
                        id: jumpModeComboBox

                        Layout.fillWidth: true

                        model: ["Beginning", "Center", "End", "Contain"]
                        currentIndex: 1
                    }

                    Button {
                        Layout.fillWidth: true

                        text: "Go"
                        enabled: !windowedView.busy && messagesModel.count > 0

                        onClicked: d.jumpToSourceRow(jumpIndexSpinBox.value,
                                                     jumpModeComboBox.currentIndex)
                    }
                }

                // What the jump works with. The key is the identity; every row
                // number below is derived from it, and re-derived whenever
                // anything moves.
                ModelEntry {
                    id: trackedEntry

                    sourceModel: messagesModel
                    key: "key"
                    value: d.keyAtSourceRow(jumpIndexSpinBox.value)
                }

                Label {
                    text: "That row is " + (trackedEntry.available
                                            ? trackedEntry.value
                                              + ", now at model row "
                                              + trackedEntry.row
                                            : "not in the model")
                }

                Label {
                    text: "Window says: " + (d.trackedWindowRow < 0
                                             ? "-" : d.trackedWindowRow)
                          + "   |   view holds: "
                          + (d.trackedViewRow < 0 ? "- (outside the window)"
                                           : "model row " + d.trackedViewRow)
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        Layout.fillWidth: true

                        text: "Model start"
                        onClicked: windowedView.positionViewAtBeginning()
                    }

                    Button {
                        Layout.fillWidth: true

                        text: "Model end"
                        onClicked: windowedView.positionViewAtEnd()
                    }
                }

                // The window record in miniature: capture where the tracked row
                // sits in the viewport, lose the position, put it back exactly -
                // through the same jump, so it works from outside the window
                // too.
                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        Layout.fillWidth: true

                        // Captures where the reader is, not where the
                        // source-row box points: the row at the viewport top.
                        // So it keeps working however far the window has been
                        // scrolled from whatever is selected above.
                        text: "Capture position"
                        enabled: windowedView.rowCount > 0 && !windowedView.busy

                        onClicked: d.captureReadingPosition()
                    }

                    Button {
                        Layout.fillWidth: true

                        text: "Restore"
                        enabled: !isNaN(d.capturedOffset)
                                 && !windowedView.busy

                        onClicked: d.jumpToKey(d.capturedKey, -1,
                                               d.capturedOffset)
                    }
                }

                Label {
                    text: isNaN(d.capturedOffset)
                          ? "nothing captured"
                          : "captured " + d.capturedKey + " at "
                            + Math.round(d.capturedOffset) + "px"
                }

                RowLayout {
                    spacing: 4

                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10

                        radius: width / 2
                        color: positionedFlash.running ? "#2ecc71" : "#bdbdbd"
                    }

                    Label { text: "Row positioned" }
                }

                Item { Layout.preferredHeight: 8 }

                Label {
                    text: "Model operations"
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Count" }

                    SpinBox {
                        id: countSpinBox

                        Layout.fillWidth: true

                        from: 1
                        to: 1000
                        value: d.defaultInsertCount
                        editable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "At (model row)" }

                    ComboBox {
                        id: positionComboBox

                        Layout.fillWidth: true

                        model: ["End", "Beginning", "Index"]
                        currentIndex: d.defaultInsertPosition
                    }
                }

                // The model is newest-first, so its beginning holds the newest
                // message. Rendered bottom-up that is the bottom of the screen:
                // inserting at the beginning is a message arriving, and inserting
                // at the end is an older page being backfilled.
                Label {
                    Layout.fillWidth: true

                    text: d.bottomUp
                          ? "model row 0 is the newest - it appears at the bottom"
                          : "model row 0 is the newest - it appears at the top"
                    font.italic: true
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Index"
                        enabled: indexSpinBox.enabled
                    }

                    SpinBox {
                        id: indexSpinBox

                        Layout.fillWidth: true

                        enabled: positionComboBox.currentValue === "Index"

                        // Same restore-ordering trap as the window's First box.
                        from: 0
                        to: Math.max(messagesModel.count, root.initialMessageCount)
                        value: d.defaultInsertIndex
                        editable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        Layout.fillWidth: true

                        text: "Insert"

                        onClicked: root.insertMessages(
                                       countSpinBox.value, d.panelInsertIndex(), false)
                    }

                    Button {
                        Layout.fillWidth: true

                        text: "Insert now"

                        onClicked: root.insertMessages(
                                       countSpinBox.value, d.panelInsertIndex(), true)
                    }
                }

                Button {
                    Layout.fillWidth: true

                    text: "Remove"
                    enabled: messagesModel.count > 0

                    onClicked: root.removeMessages(
                                   countSpinBox.value, d.panelInsertIndex())
                }

                // Changes a row instead of the set of rows, which is the one
                // operation the two row sources answer differently: a binding
                // installed by hand follows the role by itself, while the
                // binder hears about it through dataChanged.
                RowLayout {
                    Layout.fillWidth: true

                    Label { text: "Touch row" }

                    SpinBox {
                        id: touchRowSpinBox

                        Layout.fillWidth: true

                        from: 0
                        to: Math.max(0, messagesModel.count - 1)
                        stepSize: 10
                        value: 0
                        editable: true
                    }

                    Button {
                        text: "Edit"
                        enabled: messagesModel.count > 0

                        onClicked: d.touchRow(touchRowSpinBox.value)
                    }
                }

                Item { Layout.preferredHeight: 16 }

                Button {
                    Layout.fillWidth: true

                    text: "Restore defaults"

                    onClicked: d.restoreDefaults()
                }
            }
        }
    }

    Component.onCompleted: d.openAtTheStart()

    // The reveal clears initialLoading before it writes the final content
    // height, so the bottom edge is not known until that turn is over.
    Connections {
        target: windowedView

        function onInitialLoadingChanged() {
            if (!windowedView.initialLoading)
                landTimer.restart()
        }
    }

    // A row that found the pool dry is dressed as soon as there is anything to
    // dress it with.
    Connections {
        target: rowPool

        function onAvailabilityChanged(kind, readyCount) {
            if (kind !== d.poolKind)
                return

            d.republishPool()

            if (readyCount > 0)
                d.drainStarved()
        }
    }

    // Lit briefly when the view reports a jump honoured.
    Timer {
        id: positionedFlash

        interval: 400
    }

    Connections {
        target: windowedView

        function onRowPositioned(row) {
            positionedFlash.restart()
        }
    }

    // Lets the model-less turn through, then opens the rebuilt window where
    // the page always opens it.
    Timer {
        id: rowSourceTimer

        interval: 0

        onTriggered: {
            d.rebuilding = false
            d.openAtTheStart()
        }
    }

    Timer {
        id: answerTimer

        onTriggered: d.deliver(d.answerAtTop)
    }

    // A jump's window move answered late, the way a backend fetch would.
    Timer {
        id: jumpAnswerTimer

        onTriggered: d.moveWindowToJump()
    }

    // A Timer rather than Qt.callLater: the storybook destroys and rebuilds a
    // page on a hot reload, and a callLater still pending across that fires
    // into a context that no longer exists. A Timer dies with the page.
    Timer {
        id: landTimer

        interval: 0

        onTriggered: d.landAtTheOpeningEdge()
    }

    Settings {
        category: "WindowedViewPage"

        property alias slideStep: slideStepSpinBox.value
        property alias answerDelay: answerDelaySpinBox.value
        property alias stickToBottom: stickToBottomSwitch.checked
        property alias bottomUp: bottomUpSwitch.checked
        property alias placeholder: placeholderSwitch.checked
        property alias autoRequest: autoRequestSwitch.checked
        property alias placeholderRows: placeholderRowsSpinBox.value
        property alias prefetchMargin: prefetchMarginSpinBox.value
        property alias header: headerSwitch.checked
        property alias footer: footerSwitch.checked
        property alias slotHeight: slotHeightSpinBox.value
        property alias rowSource: rowSourceComboBox.currentIndex
        property alias poolTarget: poolTargetSpinBox.value
        property alias asynchronous: asyncSwitch.checked
        property alias minDelay: minDelaySpinBox.value
        property alias maxDelay: maxDelaySpinBox.value
        property alias insertCount: countSpinBox.value
        property alias insertPosition: positionComboBox.currentIndex
        property alias insertIndex: indexSpinBox.value
    }
}

// category: Panels
// status: good
