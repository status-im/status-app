pragma ComponentBehavior: Bound

import QtCore

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import Storybook

import "ChatViewPocComponents"

SplitView {
    id: root

    readonly property int initialMessageCount: 200

    // Window //////////////////////////////////////////////////////////////////
    //
    // Only a slice of the source model reaches the view. The two bounds are
    // independent state rather than first + size, because a slide has to move
    // one end, wait, and only then move the other.

    readonly property int windowFirst: d.windowFirst
    readonly property int windowLast: d.windowLast
    readonly property int windowSize: d.windowLast - d.windowFirst + 1

    // True while a slide in that direction is waiting for its delegates. "Up"
    // means toward the beginning of the model - older messages - which is what
    // scrolling up in a chat does.
    readonly property bool movingUp: d.movingUp
    readonly property bool movingDown: d.movingDown

    // Delegate loading ////////////////////////////////////////////////////////
    //
    // The delay is drawn per row from [minDelegateLoadingDelay,
    // maxDelegateLoadingDelay]. The spread is what makes a batch arrive
    // scattered rather than all at once; the floor is what makes every row
    // slow, which is a different kind of bad device.

    readonly property bool asynchronousDelegates: asyncSwitch.checked
    readonly property int minDelegateLoadingDelay: minDelaySpinBox.value
    readonly property int maxDelegateLoadingDelay: maxDelaySpinBox.value

    // Moves the window by `count` rows, clamped to what the model has left.
    // Returns how far it actually went, 0 if it could not move or a slide is
    // already running.
    function slideWindowUp(count) {
        return d.startSlide(-count)
    }

    function slideWindowDown(count) {
        return d.startSlide(count)
    }

    // Inserts `count` freshly generated messages at `index`. Both ends are just
    // indices - 0 is the beginning, model.count the end - so there is one path
    // here regardless of what the panel asked for.
    function insertMessages(count, index) {
        const rows = d.createMessages(count)

        if (index >= messagesModel.count)
            messagesModel.append(rows)
        else
            messagesModel.insert(Math.max(0, index), rows)
    }

    QtObject {
        id: d

        // Control defaults. Named here rather than inlined, so the initial
        // value of a control and what "Restore defaults" puts back cannot
        // drift apart.
        readonly property int defaultWindowFirst: 0
        readonly property int defaultWindowSize: 60
        readonly property int defaultSlideStep: 10

        readonly property bool defaultAsynchronous: true
        readonly property int defaultMinDelay: 0
        readonly property int defaultMaxDelay: 200
        readonly property int defaultInsertCount: 10
        readonly property int defaultInsertPosition: 0   // "End"
        readonly property int defaultInsertIndex: 0

        function restoreDefaults() {
            d.windowFirst = d.defaultWindowFirst
            d.windowLast = d.defaultWindowFirst + d.defaultWindowSize - 1
            slideStepSpinBox.value = d.defaultSlideStep
            asyncSwitch.checked = d.defaultAsynchronous
            minDelaySpinBox.value = d.defaultMinDelay
            maxDelaySpinBox.value = d.defaultMaxDelay
            countSpinBox.value = d.defaultInsertCount
            positionComboBox.currentIndex = d.defaultInsertPosition
            indexSpinBox.value = d.defaultInsertIndex
        }

        // Window state ////////////////////////////////////////////////////////

        property int windowFirst: d.defaultWindowFirst
        property int windowLast: d.defaultWindowFirst + d.defaultWindowSize - 1

        // Slide state /////////////////////////////////////////////////////////

        property bool movingUp: false
        property bool movingDown: false

        readonly property bool moving: d.movingUp || d.movingDown

        // How far this slide is going, and how many of the rows it added are
        // still building. Rows count themselves in and out, so nothing here
        // has to guess which delegates belong to the batch.
        property int slideAmount: 0
        property int batchPending: 0

        // Guards finishSlide() against being re-entered by the destruction of
        // the rows it is itself trimming.
        property bool finishing: false

        // Grows the window at one end and leaves the other alone. The opposite
        // end is trimmed in finishSlide(), once every delegate added here has
        // something to show - that delay is the whole point: the two ends must
        // not change in the same frame.
        function startSlide(delta) {
            if (d.moving)
                return 0

            const room = delta > 0 ? messagesModel.count - 1 - d.windowLast
                                   : d.windowFirst
            const n = Math.min(Math.abs(delta), room)

            if (n <= 0)
                return 0

            d.slideAmount = n
            d.batchPending = 0

            // Set before the bound moves: the rows the proxy is about to insert
            // read it as they are built, and hold themselves back.
            if (delta > 0) {
                d.movingDown = true
                d.windowLast += n
            } else {
                d.movingUp = true
                d.windowFirst -= n
            }

            // Repeater builds its delegates synchronously, so by now every row
            // of the batch has counted itself in. Zero means there was nothing
            // to wait for.
            if (d.batchPending === 0)
                d.finishSlide()

            return n
        }

        // Reveals the batch, drops the far end, and puts the viewport back
        // where it was. Only the change *above* the viewport moves anything on
        // screen - the batch appended below a downward slide, and the rows
        // trimmed below an upward one, cost nothing.
        //
        // Every surviving row shifts by the same amount, because they are
        // stacked in a Column and all that changed is height above them. So
        // any one of them works as the reference; there is no need to work out
        // which row the viewport is actually showing.
        function finishSlide() {
            d.finishing = true

            // During the transition the window holds size + n rows. Sliding
            // down, the old rows are 0..size-1 and the trim takes 0..n-1;
            // sliding up, the old rows start at n and the trim takes the last
            // n. Either way index n is an old row that survives - as long as
            // one exists at all, which it does only while n < size. A slide
            // longer than the window replaces everything on screen, and then
            // there is nothing to hold still.
            const survivors = messagesRepeater.count - d.slideAmount

            const anchor = d.slideAmount < survivors
                         ? messagesRepeater.itemAt(d.slideAmount) : null

            // Both read before anything moves: changing contentHeight runs
            // Flickable's own fixup, which can move contentY behind our back.
            messagesColumn.forceLayout()

            const anchorY = anchor ? anchor.y : 0
            const contentY = flickable.contentY

            d.revealAll()

            if (d.movingDown)
                d.windowFirst += d.slideAmount
            else
                d.windowLast -= d.slideAmount

            if (anchor) {
                // Column positions from a polish, so anchor.y would still be
                // the old one without this.
                messagesColumn.forceLayout()

                // Holding the anchor still under the viewport is just this.
                // The clamp only bites when standing still is impossible
                // anyway - sliding down while already at the top removes the
                // very rows being read, and there is nothing above to show.
                const limit = Math.max(0, flickable.contentHeight - flickable.height)

                flickable.contentY = Math.max(
                    0, Math.min(limit, contentY + anchor.y - anchorY))
            }

            d.movingUp = false
            d.movingDown = false
            d.slideAmount = 0
            d.finishing = false
        }

        function revealAll() {
            for (let i = 0; i < messagesRepeater.count; i++) {
                const row = messagesRepeater.itemAt(i)

                if (row)
                    row.revealed = true
            }
        }

        // Called by every row as it is built. Returns whether the row joined
        // the batch, which the row remembers so it reports back exactly once.
        function rowCreated() {
            if (!d.moving)
                return false

            d.batchPending++
            return true
        }

        // Called once by each counted row, whether it finished loading or was
        // destroyed before it could.
        function rowSettled() {
            d.batchPending--

            if (d.batchPending === 0 && d.moving && !d.finishing)
                d.finishSlide()
        }

        // Sample data /////////////////////////////////////////////////////////
        //
        // Deterministic on purpose - every reload gives the same heights, so
        // what the view does is comparable between runs. Each message carries
        // its own serial in the text, so an insertion is visible for what it is.

        readonly property var lorem:
            ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor "
           + "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis "
           + "nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo "
           + "consequat.").split(" ")

        property int nextSerial: 0

        function createMessage() {
            const i = d.nextSerial++

            const words = []
            const wordCount = 3 + (i * 7) % 60

            for (let w = 0; w < wordCount; w++)
                words.push(d.lorem[(i + w) % d.lorem.length])

            const images = []
            const imageCount = i % 11 === 0 ? 1 + i % 3 : 0

            for (let j = 0; j < imageCount; j++)
                images.push({ url: `https://picsum.photos/id/${(i + j) % 70}/1200/1300` })

            return {
                messageText: `**#${i}** ` + words.join(" "),
                messageImages: images,
                messageDate: new Date(2024, 0, 1 + i),
                messageAvatar: `https://picsum.photos/id/${i % 70}/50/50`
            }
        }

        function createMessages(count) {
            const rows = []

            for (let i = 0; i < count; i++)
                rows.push(d.createMessage())

            return rows
        }
    }

    // The roles are prefixed because MessageDelegate already owns `text`,
    // `images`, `date` and `avatar`; a required property cannot redeclare them.
    ListModel {
        id: messagesModel

        Component.onCompleted: append(d.createMessages(root.initialMessageCount))
    }

    // Both bounds are inclusive, and IndexFilter reads them against the source
    // model's rows, so this is a plain [first, last] slice.
    SortFilterProxyModel {
        id: windowModel

        sourceModel: messagesModel

        filters: IndexFilter {
            id: windowFilter

            minimumIndex: d.windowFirst
            maximumIndex: d.windowLast
        }

        // IndexFilter judges a row by its position, and QSortFilterProxyModel
        // never re-tests a row it has already judged: an insertion renumbers
        // the rows after it, so accepted rows stay accepted past maximumIndex
        // and rejected rows never come back into range. The filter therefore
        // has to be re-run whenever the source changes shape.
        //
        // Connected here rather than from a handler on the model, because the
        // order matters: re-filtering from a slot that runs before the proxy
        // has processed the same change is at best undone, and on a removal
        // leaves empty rows behind. Connecting once the proxy is complete puts
        // this after the proxy's own handler. (It assumes sourceModel is never
        // reassigned, which would reconnect the proxy behind us.)
        Component.onCompleted: {
            messagesModel.rowsInserted.connect(windowFilter.invalidated)
            messagesModel.rowsRemoved.connect(windowFilter.invalidated)
        }
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: "#1b1b1f"

        Flickable {
            id: flickable

            anchors.fill: parent

            contentWidth: width
            contentHeight: messagesColumn.height

            ScrollBar.vertical: ScrollBar {}

            Column {
                id: messagesColumn

                width: flickable.width

                Repeater {
                    id: messagesRepeater

                    model: windowModel

                    delegate: Loader {
                        id: messageItem

                        required property string messageText
                        required property var messageImages
                        required property date messageDate
                        required property string messageAvatar

                        // A row is not shown the moment it finishes building.
                        // One built outside a slide is a batch of one and
                        // reveals itself; one built for a slide waits until
                        // every row of that slide is ready, so the batch
                        // arrives in a single frame instead of trickling in.
                        property bool revealed: false

                        // Whether this row is one of the outstanding loads
                        // d.batchPending is counting. Remembered rather than
                        // recomputed, so the row reports back exactly once.
                        property bool counted: false

                        width: messagesColumn.width
                        height: messageItem.revealed ? messageItem.implicitHeight : 0
                        visible: messageItem.revealed

                        asynchronous: root.asynchronousDelegates
                        active: false

                        sourceComponent: MessageDelegate {
                            text: messageItem.messageText
                            images: messageItem.messageImages
                            date: messageItem.messageDate
                            avatar: messageItem.messageAvatar
                        }

                        Timer {
                            interval: root.minDelegateLoadingDelay
                                      + Math.random() * Math.max(
                                            0, root.maxDelegateLoadingDelay
                                             - root.minDelegateLoadingDelay)
                            running: true

                            onTriggered: {
                                messageItem.active = true
                            }
                        }

                        Component.onCompleted: {
                            messageItem.counted = d.rowCreated()
                        }

                        onLoaded: {
                            if (messageItem.counted) {
                                messageItem.counted = false
                                d.rowSettled()
                            } else {
                                messageItem.revealed = true
                            }
                        }

                        Component.onDestruction: {
                            if (messageItem.counted) {
                                messageItem.counted = false
                                d.rowSettled()
                            }
                        }
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 280
        SplitView.preferredWidth: 320

        ColumnLayout {
            Layout.fillWidth: true

            spacing: 4

            Label {
                text: "View"
                font.bold: true
            }

            Label {
                text: "Items in the view: " + messagesRepeater.count
            }

            Label {
                text: "Items in the model: " + messagesModel.count
            }

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Window"
                font.bold: true
            }

            // The upper bound never dips below the initial row count, and that
            // matters: Settings restores this value from a C++ componentComplete,
            // which runs before any Component.onCompleted - so the model is still
            // empty at that point. A `to` of 0 would clamp the restored value to
            // 0, and since the property it is bound to has not changed, the
            // binding would never re-evaluate once the model fills.
            RowLayout {
                Layout.fillWidth: true

                Label { text: "First" }

                SpinBox {
                    id: windowFirstSpinBox

                    Layout.fillWidth: true

                    // Locked while a slide is running: the slide owns both
                    // bounds until it completes.
                    enabled: !root.movingUp && !root.movingDown

                    from: 0
                    to: Math.max(messagesModel.count, root.initialMessageCount) - 1
                    stepSize: 10
                    editable: true

                    value: d.windowFirst

                    onValueModified: {
                        const size = root.windowSize

                        d.windowFirst = value
                        d.windowLast = value + size - 1
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Size" }

                SpinBox {
                    id: windowSizeSpinBox

                    Layout.fillWidth: true

                    enabled: !root.movingUp && !root.movingDown

                    from: 1
                    to: 1000
                    stepSize: 10
                    editable: true

                    value: root.windowSize

                    onValueModified: d.windowLast = d.windowFirst + value - 1
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

                Button {
                    Layout.fillWidth: true

                    text: "Slide up"
                    enabled: !root.movingUp && !root.movingDown

                    onClicked: root.slideWindowUp(slideStepSpinBox.value)
                }

                Button {
                    Layout.fillWidth: true

                    text: "Slide down"
                    enabled: !root.movingUp && !root.movingDown

                    onClicked: root.slideWindowDown(slideStepSpinBox.value)
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
                        color: root.movingUp ? "#2ecc71" : "#bdbdbd"
                    }

                    Label { text: "Moving up" }
                }

                RowLayout {
                    spacing: 4

                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10

                        radius: width / 2
                        color: root.movingDown ? "#2ecc71" : "#bdbdbd"
                    }

                    Label { text: "Moving down" }
                }

                Item { Layout.fillWidth: true }
            }

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Delegate loading"
                font.bold: true
            }

            Switch {
                id: asyncSwitch

                Layout.fillWidth: true

                text: "Asynchronous"
                checked: d.defaultAsynchronous
            }

            // The two bounds cap each other, so the range cannot be inverted.
            RowLayout {
                Layout.fillWidth: true

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

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Insert messages"
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

                Label { text: "At" }

                ComboBox {
                    id: positionComboBox

                    Layout.fillWidth: true

                    model: ["End", "Beginning", "Index"]
                    currentIndex: d.defaultInsertPosition
                }
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

            Button {
                Layout.fillWidth: true

                text: "Insert"

                // A model change mid-slide re-filters the window and can build
                // or drop rows outside the batch the slide is counting. The
                // accounting survives it, but a PoC is easier to read when it
                // cannot happen at all.
                enabled: !root.movingUp && !root.movingDown

                onClicked: {
                    const index = {
                        "Beginning": 0,
                        "End": messagesModel.count,
                        "Index": indexSpinBox.value
                    }[positionComboBox.currentValue]

                    root.insertMessages(countSpinBox.value, index)
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

    // Kept across reloads, so a hot reload does not silently drop the view back
    // to whatever the default happened to be mid-experiment.
    Settings {
        category: "WindowedChatViewPage"

        property alias windowFirst: d.windowFirst
        property alias windowLast: d.windowLast
        property alias slideStep: slideStepSpinBox.value
        property alias asynchronousDelegates: asyncSwitch.checked
        property alias minDelegateLoadingDelay: minDelaySpinBox.value
        property alias maxDelegateLoadingDelay: maxDelaySpinBox.value
        property alias insertCount: countSpinBox.value
        property alias insertPosition: positionComboBox.currentIndex
        property alias insertIndex: indexSpinBox.value
    }
}

// category: Panels
// status: good
