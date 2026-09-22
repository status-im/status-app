import QtQuick
import QtTest

import AppLayouts.Chat.controls

Item {
    id: root
    width: 500
    height: 300

    ListModel {
        id: participantsListModel

        Component.onCompleted: {
            for (let index = 0; index < 6; ++index) {
                append({
                    name: "Participant " + index,
                    image: "",
                    colorId: index
                })
            }
        }
    }

    Component {
        id: componentUnderTest

        ThreadCard {
            width: 420
            threadId: "thread-id"
            originalMessageId: "parent-id"
            title: "Thread title"
            messagesCount: 12
            participantsCount: 8
            participantsModel: participantsListModel
        }
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    TestCase {
        name: "ThreadCard"
        when: windowShown

        property ThreadCard controlUnderTest

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            clickedSpy.target = controlUnderTest
            clickedSpy.clear()
        }

        function test_limitsParticipantsAndShowsRemainder() {
            const repeater = findChild(controlUnderTest, "threadCardParticipantsRepeater")
            verify(!!repeater)
            compare(repeater.count, 6)

            const remainder = findChild(controlUnderTest, "threadCardRemainingParticipants")
            verify(!!remainder)
            compare(remainder.text, "+2")

            for (let index = 0; index < 6; ++index) {
                compare(findChild(controlUnderTest, "threadCardParticipantAvatar_" + index).visible, true)
            }
        }

        function test_limitsPreviewToParticipantsCount() {
            controlUnderTest.participantsCount = 3

            for (let index = 0; index < 6; ++index) {
                compare(findChild(controlUnderTest, "threadCardParticipantAvatar_" + index).visible,
                        index < controlUnderTest.participantsCount)
            }
        }

        function test_clickEmitsThreadAndParentIds() {
            mouseClick(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2)
            compare(clickedSpy.count, 1)
            compare(clickedSpy.signalArguments[0][0], "thread-id")
            compare(clickedSpy.signalArguments[0][1], "parent-id")
        }
    }
}
