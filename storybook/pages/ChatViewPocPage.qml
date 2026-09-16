import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import Storybook

import "ChatViewPocComponents"

SplitView {
    id: root

    readonly property int numberOfMessagesInViewport: 120

    /**
     * Generates a sample Lorem Ipsum text with the specified number of words.
     * @param {number} wordCount - The number of words to generate.
     * @returns {string} - Lorem Ipsum text with the desired word count.
     */
    function generateLoremIpsum(wordCount) {
        if (wordCount <= 0) return "";

        const lorem =
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. " +
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. " +
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. " +
            "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

        const loremWords = lorem.replace(/\s+/g, " ").trim().split(" ");
        const baseLength = loremWords.length;

        // Choose a random starting index
        const startIdx = Math.floor(Math.random() * baseLength);

        const result = [];
        let i = 0;
        while (result.length < wordCount) {
            // Wrap around with modulo, offset by startIdx

            let word = loremWords[(startIdx + i) % baseLength]
            const addNewLine = Math.floor(Math.random() * 20) === 0

            const strikethrough = Math.floor(Math.random() * 5) === 0
            const bold = Math.floor(Math.random() * 5) === 0

            if (bold)
                word = "**" + strikethrough + "**"

            if (strikethrough)
                word = "~~" + strikethrough + "~~"

            result.push(word + (addNewLine ? "  \n" : " "));
            i++;
        }

        return result.join("");
    }

    function generateSampleModelData(size, maxWordCount) {
        const modelData = [];

        function randomDate(start, end) {
          return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()))
        }

        modelData.push({ text: "**HELLO WORLD!** (This is very first message)", images: [], date: new Date() })

        for (let i = 0; i < size; i++) {
            const wordCount = Math.floor(Math.random() * maxWordCount) + 1; // 1 to maxCount inclusive

            const text = generateLoremIpsum(wordCount)
            const date = randomDate(new Date(2012, 0, 1), new Date())
            const avatar = `https://picsum.photos/id/${(i) % 70}/50/50`

            const imageCount = Math.round(Math.random() - 0.4) * Math.floor(Math.random() * 10)
            const imagesSeed = Math.round(Math.random() * 100)
            const images = []

            for (let j = 0; j < imageCount; j++)
                images.push({url: `https://picsum.photos/id/${(imagesSeed + j) % 70}/1200/1300`})

            modelData.push({ text, images, date, avatar })
        }

        modelData.push({ text: "**GOOD BYE!** (This is the latest message)", images: [], date: new Date() })

        return modelData
    }

    function generatePlaceholderContent(size = 12, minLength = 30, maxLength = 140,
                                        minCount = 1, maxCount = 15) {
        const array = []

        function getRandomInt(max) {
          return Math.floor(Math.random() * max);
        }

        for (let i = 0; i < size; i++) {
            const count = getRandomInt(maxCount - minCount) + minCount
            const subarray = []

            for (let j = 0; j < count; j++)
                subarray.push(getRandomInt(maxLength - minLength) + minLength)

            array.push(subarray)
        }

        return array
    }

    QtObject {
        id: d

        // Frame meter ////////////////////////////////////////////////////////
        //
        // FrameAnimation fires once per rendered frame, so the interval between
        // firings is the frame time: a GUI thread blocked building delegates
        // shows up here as one huge value rather than as many small ones.

        readonly property real jankThresholdMs: 33.4

        property real lastMs: 0
        property real worstMs: 0
        property real totalMs: 0
        property int frames: 0
        property int jankyFrames: 0

        readonly property real averageMs: d.frames > 0 ? d.totalMs / d.frames : 0

        function resetStats() {
            d.lastMs = 0
            d.worstMs = 0
            d.totalMs = 0
            d.frames = 0
            d.jankyFrames = 0
        }

        function recordFrame(ms) {
            // The first frame after a reset measures the gap across the reset
            // itself, not a rendered frame; skip it.
            if (d.frames === 0 && ms > d.jankThresholdMs * 4) {
                d.frames = 1
                return
            }

            d.lastMs = ms
            d.totalMs += ms
            d.frames++

            if (ms > d.worstMs)
                d.worstMs = ms
            if (ms > d.jankThresholdMs)
                d.jankyFrames++
        }

        // Applied load ///////////////////////////////////////////////////////
        //
        // Deliberately not bound straight to the sliders. The window holds
        // `numberOfMessagesInViewport` delegates and a Repeater builds all of
        // them, so a complexity change tears down and rebuilds every one of
        // them synchronously on the GUI thread. A slider emits on every step of
        // a drag, which would mean one full rebuild of the whole window per
        // step. These only follow once the slider has been still for a moment.

        property int appliedBuildComplexity: 0
        property int appliedPaintComplexity: 0
    }

    // Fires once per rendered frame.
    FrameAnimation {
        running: true

        onTriggered: d.recordFrame(frameTime * 1000)
    }

    Timer {
        id: applyLoadTimer

        interval: 150

        onTriggered: {
            d.appliedBuildComplexity = buildSlider.value
            d.appliedPaintComplexity = paintSlider.value

            // The rebuild itself is a stall by construction; counting it would
            // swamp everything the meter is meant to show about scrolling.
            d.resetStats()
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.fill: parent

            color: "#232325"
        }

        ListModel {
            id: lm

            Component.onCompleted: {
                const size = 320
                const maxWordCount = 40

                append(root.generateSampleModelData(size, maxWordCount))
            }
        }

        ChatViewFlickable {
            id: flickable

            ScrollBar.vertical: ScrollBar {}

            fakeConversationPlaceholder: FakeConversationColumn {
                model: generatePlaceholderContent()
            }

            onMoreDownRequested: {
                const shift = Math.min(40, lm.count - indexFilter.maximumIndex - 1)

                indexFilter.minimumIndex += shift
                indexFilter.maximumIndex += shift
            }

            onMoreUpRequested: {
                const shift = Math.min(40, indexFilter.minimumIndex)

                indexFilter.minimumIndex -= shift
                indexFilter.maximumIndex -= shift
            }

            anchors.fill: parent

            delegateBuildComplexity: d.appliedBuildComplexity
            delegatePaintComplexity: d.appliedPaintComplexity

            // scrolling behaviour
            maximumFlickVelocity: 50000
            flickDeceleration: 800000
            boundsMovement: Flickable.StopAtBounds
            boundsBehavior: Flickable.DragAndOvershootBounds

            model: SortFilterProxyModel {
                sourceModel: lm

                filters: IndexFilter {
                    id: indexFilter

                    minimumIndex: lm.count - 1 - root.numberOfMessagesInViewport
                    maximumIndex: lm.count - 1
                }

                onRowsInserted: console.log("inserted!")
            }

            moreUpAvailable: indexFilter.minimumIndex !== 0
            moreDownAvailable: indexFilter.maximumIndex !== lm.count - 1
        }

        RoundButton {
            id: recentMessagesButton

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16

            visible: indexFilter.maximumIndex !== lm.count - 1

            text: "⬇️"
            font.pixelSize: 18

            flat: true

            onClicked: {
                indexFilter.minimumIndex = lm.count - 1 - root.numberOfMessagesInViewport
                indexFilter.maximumIndex = lm.count - 1

                flickable.moveDown()
            }
        }

        // Pinned over the conversation rather than parked in the controls tab:
        // the numbers only mean anything while you are scrolling, and you
        // cannot scroll and watch another tab at the same time.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12

            implicitWidth: meterLayout.implicitWidth + 20
            implicitHeight: meterLayout.implicitHeight + 16

            color: "#cc16161a"
            radius: 6
            border.width: 1
            border.color: "#343438"

            ColumnLayout {
                id: meterLayout

                anchors.centerIn: parent
                spacing: 2

                Text {
                    color: d.worstMs > d.jankThresholdMs ? "#ff6b6b" : "#e0e0e3"
                    font.bold: true
                    font.pixelSize: 12
                    text: "worst " + d.worstMs.toFixed(1) + " ms"
                }

                Text {
                    color: "#a0a0a8"
                    font.pixelSize: 12
                    text: "last " + d.lastMs.toFixed(1) + " \u00b7 avg " + d.averageMs.toFixed(1) + " ms"
                }

                Text {
                    color: d.jankyFrames > 0 ? "#ffb86b" : "#a0a0a8"
                    font.pixelSize: 12
                    text: "janky " + d.jankyFrames + " / " + d.frames
                }

                Text {
                    color: "#6f6f78"
                    font.pixelSize: 11
                    text: "build " + d.appliedBuildComplexity
                          + " \u00b7 paint " + d.appliedPaintComplexity
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 360

        ColumnLayout {
            Layout.fillWidth: true

            spacing: 4

            Label {
                text: "Simulated device load"
                font.bold: true
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 11
                text: "The window holds " + root.numberOfMessagesInViewport
                      + " delegates and a Repeater builds all of them, so every "
                      + "figure below is paid that many times over. Sliders apply "
                      + "150 ms after they stop moving, and reset the meter."
            }

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Build: " + buildSlider.value + " groups \u2192 "
                      + (buildSlider.value * 8 * root.numberOfMessagesInViewport)
                      + " objects in the window"
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 11
                text: "Objects constructed per delegate, never drawn. Paid on the "
                      + "GUI thread in the frame that realises the delegate, so this "
                      + "is what a windowing shift costs."
            }

            Slider {
                id: buildSlider

                Layout.fillWidth: true

                from: 0
                to: 256
                stepSize: 1

                onValueChanged: applyLoadTimer.restart()
            }

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Paint: " + paintSlider.value + " extra copies per message"
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 11
                text: "Wrapped markdown laid out on every width change and drawn "
                      + "through an offscreen buffer. This is what scrolling costs, "
                      + "frame after frame. Far more expensive per unit than build."
            }

            Slider {
                id: paintSlider

                Layout.fillWidth: true

                from: 0
                to: 12
                stepSize: 1

                onValueChanged: applyLoadTimer.restart()
            }

            Item { Layout.preferredHeight: 8 }

            Button {
                text: "Reset meter"

                onClicked: d.resetStats()
            }
        }
    }
}

// category: Research / Examples
// status: good
