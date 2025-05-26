import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import SortFilterProxyModel 0.2

import "ChatViewPocComponents"

Item {
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

            for (let j = 0; j < count; j++) {
                subarray.push(getRandomInt(maxLength - minLength) + minLength)
            }

            array.push(subarray)
        }

        return array
    }

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

    Flickable {
        id: flickable

        ScrollBar.vertical: ScrollBar {
            id: scrollbar

            onPressedChanged: {
                if (pressed)
                    return

                const isTopPlaceholderVisible = flickable.contentY < topPlaceholder.height

                if (isTopPlaceholderVisible) {
                    const first = messagesRepeater.itemAt(0)

                    const offset = first.y - flickable.contentY

                    flickable.contentY = Qt.binding(() => {
                        return first.y - offset
                    })

                    const shift = Math.min(40, indexFilter.minimumIndex)

                    indexFilter.minimumIndex -= shift
                    indexFilter.maximumIndex -= shift
                }

                const isBottomPlaceholderVisible = bottomPlaceholder.visible
                                                 && !isTopPlaceholderVisible && flickable.contentY + flickable.height >= bottomPlaceholder.y


                if (isBottomPlaceholderVisible) {
                    const last = messagesRepeater.itemAt(messagesRepeater.count - 1)

                    const offset = flickable.contentY - last.y

                    flickable.contentY = Qt.binding(() => {
                        return last.y + offset
                    })

                    const shift = Math.min(40, lm.count - indexFilter.maximumIndex - 1)

                    indexFilter.minimumIndex += shift
                    indexFilter.maximumIndex += shift
                }
            }
        }

        anchors.fill: parent

        contentY: contentHeight - height

        contentWidth: root.width
        contentHeight: content.height

        // scrolling behaviour
        maximumFlickVelocity: 50000
        flickDeceleration: 800000
        boundsMovement: Flickable.StopAtBounds
        boundsBehavior: Flickable.DragAndOvershootBounds

        ColumnLayout {
            id: content

            width: root.width

            FakeConversationColumn {
                id: topPlaceholder

                visible: indexFilter.minimumIndex !== 0

                model: generatePlaceholderContent()
            }

            Repeater {
                id: messagesRepeater

                model: SortFilterProxyModel {
                    sourceModel: lm

                    filters: IndexFilter {
                        id: indexFilter

                        minimumIndex: lm.count - 1 - root.numberOfMessagesInViewport
                        maximumIndex: lm.count - 1
                    }

                    onRowsInserted: console.log("inserted!")
                }

                delegate: MessageDelegate {
                    Layout.fillWidth: true
                }
            }

            FakeConversationColumn {
                id: bottomPlaceholder

                visible: indexFilter.maximumIndex !== lm.count - 1
                model: generatePlaceholderContent()
            }
        }
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
            const maxVelocity = flickable.maximumFlickVelocity
            const deceleration = flickable.flickDeceleration

            flickable.contentY = Qt.binding(() => {
                return 0//first.y - offset
            })

            indexFilter.minimumIndex = lm.count - 1 - root.numberOfMessagesInViewport
            indexFilter.maximumIndex = lm.count - 1

            flickable.maximumFlickVelocity = 2500 * 20
            flickable.flickDeceleration = 1500
            flickable.flick(0, -2500 * 20)

            flickable.maximumFlickVelocity = maxVelocity
            flickable.flickDeceleration = deceleration
        }
    }
}

// category: Research / Examples
// status: good
