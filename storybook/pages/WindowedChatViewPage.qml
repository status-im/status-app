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
    // Only a slice of the source model reaches the view. Nothing moves the
    // window yet - it is placed by hand from the panel.

    readonly property int windowFirst: windowFirstSpinBox.value
    readonly property int windowSize: windowSizeSpinBox.value

    // Delegate loading ////////////////////////////////////////////////////////
    //
    // The delay is drawn per row from [0, maxDelegateLoadingDelay], which is
    // what makes a batch arrive scattered rather than all at once.

    readonly property bool asynchronousDelegates: asyncSwitch.checked
    readonly property int maxDelegateLoadingDelay: maxDelaySpinBox.value

    // Sample data /////////////////////////////////////////////////////////////
    //
    // Deterministic on purpose - every reload gives the same heights, so what
    // the view does is comparable between runs. Each message carries its own
    // serial in the text, so an insertion is visible for what it is.
    //
    // The roles are prefixed because MessageDelegate already owns `text`,
    // `images`, `date` and `avatar`; a required property cannot redeclare them.

    QtObject {
        id: d

        // Control defaults. Named here rather than inlined, so the initial
        // value of a control and what "Restore defaults" puts back cannot
        // drift apart.
        readonly property int defaultWindowFirst: 0
        readonly property int defaultWindowSize: 60

        readonly property bool defaultAsynchronous: true
        readonly property int defaultMaxDelay: 200
        readonly property int defaultInsertCount: 10
        readonly property int defaultInsertPosition: 0   // "End"
        readonly property int defaultInsertIndex: 0

        function restoreDefaults() {
            windowFirstSpinBox.value = d.defaultWindowFirst
            windowSizeSpinBox.value = d.defaultWindowSize
            asyncSwitch.checked = d.defaultAsynchronous
            maxDelaySpinBox.value = d.defaultMaxDelay
            countSpinBox.value = d.defaultInsertCount
            positionComboBox.currentIndex = d.defaultInsertPosition
            indexSpinBox.value = d.defaultInsertIndex
        }

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

    ListModel {
        id: messagesModel

        Component.onCompleted: append(d.createMessages(root.initialMessageCount))
    }

    // Both bounds are inclusive, and IndexFilter reads them against the source
    // model's rows, so this is a plain [first, first + size) slice.
    SortFilterProxyModel {
        id: windowModel

        sourceModel: messagesModel

        filters: IndexFilter {
            id: windowFilter

            minimumIndex: root.windowFirst
            maximumIndex: root.windowFirst + root.windowSize - 1
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

                        Timer {
                            interval: Math.random() * root.maxDelegateLoadingDelay
                            running: true

                            onTriggered: {
                                messageItem.active = true
                            }
                        }

                        asynchronous: root.asynchronousDelegates

                        active: false
                        width: messagesColumn.width
                        height: messageItem.implicitHeight

                        required property string messageText
                        required property var messageImages
                        required property date messageDate
                        required property string messageAvatar

                        sourceComponent: MessageDelegate {
                            text: messageItem.messageText
                            images: messageItem.messageImages
                            date: messageItem.messageDate
                            avatar: messageItem.messageAvatar
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

            RowLayout {
                Layout.fillWidth: true

                Label { text: "First" }

                SpinBox {
                    id: windowFirstSpinBox

                    Layout.fillWidth: true

                    from: 0
                    to: Math.max(0, messagesModel.count - 1)
                    stepSize: 10
                    value: d.defaultWindowFirst
                    editable: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Size" }

                SpinBox {
                    id: windowSizeSpinBox

                    Layout.fillWidth: true

                    from: 1
                    to: 1000
                    stepSize: 10
                    value: d.defaultWindowSize
                    editable: true
                }
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

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Max delay" }

                SpinBox {
                    id: maxDelaySpinBox

                    Layout.fillWidth: true

                    from: 0
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

                    from: 0
                    to: messagesModel.count
                    value: d.defaultInsertIndex
                    editable: true
                }
            }

            Button {
                Layout.fillWidth: true

                text: "Insert"

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

        property alias windowFirst: windowFirstSpinBox.value
        property alias windowSize: windowSizeSpinBox.value
        property alias asynchronousDelegates: asyncSwitch.checked
        property alias maxDelegateLoadingDelay: maxDelaySpinBox.value
        property alias insertCount: countSpinBox.value
        property alias insertPosition: positionComboBox.currentIndex
        property alias insertIndex: indexSpinBox.value
    }
}

// category: Panels
// status: good
