pragma ComponentBehavior: Bound

import QtCore

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Models
import Storybook

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


    // Settings restores this from a C++ componentComplete, which runs before any
    // Component.onCompleted - so it is already correct when the window is placed.

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
        readonly property int defaultWindowFirst: 0
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
        readonly property bool defaultPlaceholder: true
        // The band is measured in placeholder rows rather than pixels, so it
        // always comes out a whole number of them.
        readonly property int placeholderRowHeight: 72
        readonly property int defaultPlaceholderRows: 2

        readonly property int defaultPoolTarget: 80
        readonly property bool defaultAsynchronous: true
        readonly property int defaultMinDelay: 0
        readonly property int defaultMaxDelay: 200

        readonly property int defaultInsertCount: 10
        readonly property int defaultInsertPosition: 0   // "End"
        readonly property int defaultInsertIndex: 0

        property bool answerAtTop: false

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
        // from the same reply.
        function deliver(atTop) {
            if (atTop) {
                windowSource.growStart(slideStepSpinBox.value)
                windowedView.moreLoadedTop()
            } else {
                windowSource.growEnd(slideStepSpinBox.value)
                windowedView.moreLoadedBottom()
            }
        }

        function restoreDefaults() {
            windowSizeSpinBox.value = d.defaultWindowSize
            windowSource.moveTo(d.defaultWindowFirst)
            slideStepSpinBox.value = d.defaultSlideStep
            answerDelaySpinBox.value = d.defaultAnswerDelay
            stickToBottomSwitch.checked = d.defaultStickToBottom
            placeholderSwitch.checked = d.defaultPlaceholder
            placeholderRowsSpinBox.value = d.defaultPlaceholderRows
            poolTargetSpinBox.value = d.defaultPoolTarget
            asyncSwitch.checked = d.defaultAsynchronous
            minDelaySpinBox.value = d.defaultMinDelay
            maxDelaySpinBox.value = d.defaultMaxDelay
            countSpinBox.value = d.defaultInsertCount
            positionComboBox.currentIndex = d.defaultInsertPosition
            indexSpinBox.value = d.defaultInsertIndex
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

        property int nextSerial: 0

        function createMessage() {
            const i = d.nextSerial++

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

        function createMessages(count) {
            const rows = []

            for (let i = 0; i < count; i++)
                rows.push(d.createMessage())

            return rows
        }
    }

    // The data owner: it decides what "more" means, and answers the view's
    // requests by moving an index window's bounds.
    IndexWindowSource {
        id: windowSource

        sourceModel: messagesModel

        // The control owns the steady size; the position is set through
        // moveTo(), since first/last are read-only by design.
        size: windowSizeSpinBox.value
    }

    ListModel {
        id: messagesModel

        Component.onCompleted: append(d.createMessages(root.initialMessageCount))
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

            model: windowSource.model

            moreAvailableTop: windowSource.moreAvailableStart
            moreAvailableBottom: windowSource.moreAvailableEnd

            stickToBottom: stickToBottomSwitch.checked

            placeholder: placeholderSwitch.checked ? messageSkeleton : null
            placeholderHeight: placeholderRowsSpinBox.value
                               * d.placeholderRowHeight

            // With no delay this answers inside the signal, which is what an
            // index window really is - it has the rows already. With one, the
            // rows are admitted only when the delay is up, the way an owner
            // talking to a backend behaves: nothing exists until the reply
            // lands. The view cannot tell the difference either way.
            onMoreRequestedTop: d.fetch(true)
            onMoreRequestedBottom: d.fetch(false)

            // Deferred removals happen here, in the reveal's own turn, so both
            // ends of the window change together.
            onBatchRevealed: windowSource.trim()

            ScrollBar.vertical: ScrollBar {}

            // The binding policy, and the only place that knows the roles.
            acquireDelegate: (parent, row, modelRow, cb) => itemPool.acquire(parent, (obj) => {
                // Every role binding is guarded twice over, because a row on
                // its way out fails in two different ways: the row object is
                // destroyed before the shell that holds these bindings, and
                // before that it survives as an object whose role reads have
                // already gone undefined. A null check alone catches only the
                // first.
                obj.width = Qt.binding(() => (parent ? parent.width : undefined) ?? 0)
                obj.text = Qt.binding(() => (modelRow ? modelRow.messageText : undefined) ?? "")
                obj.images = Qt.binding(() => (modelRow ? modelRow.messageImages : undefined) ?? [])
                obj.date = Qt.binding(() => (modelRow ? modelRow.messageDate : undefined) ?? new Date(0))
                obj.avatar = Qt.binding(() => (modelRow ? modelRow.messageAvatar : undefined) ?? "")

                cb(obj)
            }, d.instantAcquire)

            // The page installed the bindings, so the page drops them. Left in
            // place they keep evaluating against a row object that no longer
            // exists, which is where the undefined-role warnings come from -
            // and ItemPool cannot do it, since it does not know the roles.
            releaseDelegate: (obj) => {
                obj.text = ""
                obj.images = []
                obj.date = new Date(0)
                obj.avatar = ""
                obj.width = 0

                itemPool.release(obj)
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 420
        SplitView.preferredWidth: 420

        ColumnLayout {
            Layout.fillWidth: true

            spacing: 4

            Label {
                text: "View"
                font.bold: true
            }

            Label { text: "Rows in the window: " + windowedView.rowCount }
            Label { text: "Window: " + windowSource.first + "-" + windowSource.last }
            Label { text: "Rows in the model: " + messagesModel.count }

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Cache"
                font.bold: true
            }

            Label {
                text: "built " + itemPool.builtCount
                      + "  |  in use " + itemPool.acquiredCount
                      + "  |  parked " + itemPool.availableCount
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

            RowLayout {
                Layout.fillWidth: true

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

            Item { Layout.preferredHeight: 16 }

            Button {
                Layout.fillWidth: true

                text: "Restore defaults"

                onClicked: d.restoreDefaults()
            }
        }
    }

    Component.onCompleted: windowSource.moveTo(d.defaultWindowFirst)

    Timer {
        id: answerTimer

        onTriggered: d.deliver(d.answerAtTop)
    }

    Settings {
        category: "WindowedViewPage"

        property alias slideStep: slideStepSpinBox.value
        property alias answerDelay: answerDelaySpinBox.value
        property alias stickToBottom: stickToBottomSwitch.checked
        property alias placeholder: placeholderSwitch.checked
        property alias placeholderRows: placeholderRowsSpinBox.value
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
