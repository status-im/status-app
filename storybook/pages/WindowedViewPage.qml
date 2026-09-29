pragma ComponentBehavior: Bound

import QtCore

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Models
import Storybook

import StatusQ.Core.Utils

import "ChatViewPocComponents"
import "WindowedViewComponents"

/*
  Harness for WindowedView and RowPool. Three layers, each ignorant of the next
  but one:

    WindowedView   windowing, slides, batch reveal, anchoring. No roles, no
                   delegate type, no cache.
    this page      the binding policy - which role goes to which property.
    RowPool        storage and construction of items. No roles.

  The middle layer is the point: role knowledge lives in exactly one place, and
  it is neither the view nor the cache.
*/
SplitView {
    id: root

    readonly property int initialMessageCount: 200

    // Exposed for the tests: the data owner is a QtObject, so it is not
    // reachable by walking the item tree.
    readonly property var dataSource: windowSource

    // Settings restores this from a C++ componentComplete, which runs before any
    // Component.onCompleted - so it is already correct when the window is placed.
    property int restoredFirst: 0

    readonly property int buildComplexity: buildSpinBox.value
    readonly property int paintComplexity: paintSpinBox.value

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

    QtObject {
        id: d

        // Control defaults, named so a control's initial value and what
        // "Restore defaults" puts back cannot drift apart.
        readonly property int defaultWindowFirst: 0
        readonly property int defaultWindowSize: 60
        readonly property int defaultSlideStep: 10

        readonly property int defaultPoolTarget: 80
        readonly property bool defaultAsynchronous: true
        readonly property int defaultMinDelay: 0
        readonly property int defaultMaxDelay: 200
        readonly property int defaultBuild: 0
        readonly property int defaultPaint: 0

        readonly property int defaultInsertCount: 10
        readonly property int defaultInsertPosition: 0   // "End"
        readonly property int defaultInsertIndex: 0

        function restoreDefaults() {
            windowSizeSpinBox.value = d.defaultWindowSize
            windowSource.moveTo(d.defaultWindowFirst)
            slideStepSpinBox.value = d.defaultSlideStep
            poolTargetSpinBox.value = d.defaultPoolTarget
            asyncSwitch.checked = d.defaultAsynchronous
            minDelaySpinBox.value = d.defaultMinDelay
            maxDelaySpinBox.value = d.defaultMaxDelay
            buildSpinBox.value = d.defaultBuild
            paintSpinBox.value = d.defaultPaint
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

            buildComplexity: root.buildComplexity
            paintComplexity: root.paintComplexity
        }
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: "#1b1b1f"

        // Declared here rather than directly under the SplitView: RowPool is an
        // Item, and every Item in a SplitView is a candidate pane.
        RowPool {
            id: rowPool

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

            moreAvailableStart: windowSource.moreAvailableStart
            moreAvailableEnd: windowSource.moreAvailableEnd

            // Answered synchronously here; a fetch-more owner would call
            // moreLoaded*() much later instead, and the view cannot tell.
            onMoreRequestedStart: {
                windowSource.growStart(slideStepSpinBox.value)
                windowedView.moreLoadedStart()
            }

            onMoreRequestedEnd: {
                windowSource.growEnd(slideStepSpinBox.value)
                windowedView.moreLoadedEnd()
            }

            // Deferred removals happen here, in the reveal's own turn, so both
            // ends of the window change together.
            onBatchRevealed: windowSource.trim()

            ScrollBar.vertical: ScrollBar {}

            // The binding policy, and the only place that knows the roles.
            acquireDelegate: (parent, modelRow, cb) => rowPool.acquire(parent, (obj) => {
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
            // and RowPool cannot do it, since it does not know the roles.
            releaseDelegate: (obj) => {
                obj.text = ""
                obj.images = []
                obj.date = new Date(0)
                obj.avatar = ""
                obj.width = 0

                rowPool.release(obj)
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 340

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
                text: "built " + rowPool.builtCount
                      + "  |  in use " + rowPool.acquiredCount
                      + "  |  parked " + rowPool.availableCount
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

                Button {
                    Layout.fillWidth: true

                    text: "Slide up"
                    enabled: !windowedView.busy && windowSource.moreAvailableStart

                    onClicked: windowedView.requestMoreStart()
                }

                Button {
                    Layout.fillWidth: true

                    text: "Slide down"
                    enabled: !windowedView.busy && windowSource.moreAvailableEnd

                    onClicked: windowedView.requestMoreEnd()
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
                        color: windowedView.loadingStart ? "#2ecc71" : "#bdbdbd"
                    }

                    Label { text: "Loading start" }
                }

                RowLayout {
                    spacing: 4

                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10

                        radius: width / 2
                        color: windowedView.loadingEnd ? "#2ecc71" : "#bdbdbd"
                    }

                    Label { text: "Loading end" }
                }

                Item { Layout.fillWidth: true }
            }

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Simulated device load"
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Build" }

                SpinBox {
                    id: buildSpinBox

                    Layout.fillWidth: true

                    from: 0
                    to: 200
                    stepSize: 5
                    value: d.defaultBuild
                    editable: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Paint" }

                SpinBox {
                    id: paintSpinBox

                    Layout.fillWidth: true

                    from: 0
                    to: 50
                    value: d.defaultPaint
                    editable: true
                }
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

    // Kept across reloads, so a hot reload does not silently drop the view back
    // to whatever the default happened to be mid-experiment.
    Component.onCompleted: windowSource.moveTo(root.restoredFirst)

    Settings {
        category: "WindowedViewPage"

        property alias windowFirst: root.restoredFirst
        property alias slideStep: slideStepSpinBox.value
        property alias poolTarget: poolTargetSpinBox.value
        property alias asynchronous: asyncSwitch.checked
        property alias minDelay: minDelaySpinBox.value
        property alias maxDelay: maxDelaySpinBox.value
        property alias buildComplexity: buildSpinBox.value
        property alias paintComplexity: paintSpinBox.value
        property alias insertCount: countSpinBox.value
        property alias insertPosition: positionComboBox.currentIndex
        property alias insertIndex: indexSpinBox.value
    }
}

// category: Panels
// status: good
