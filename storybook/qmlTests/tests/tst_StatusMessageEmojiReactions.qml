import QtQuick
import QtTest

import StatusQ.Components.private as MessagePrivate

Item {
    id: root

    width: 600
    height: 400

    ListModel {
        id: reactionsA

        ListElement {
            emoji: "1f600"
            didIReactWithThisEmoji: true
            numberOfReactions: 1
            jsonArrayOfUsersReactedWithThisEmoji: "[\"You\"]"
        }
        ListElement {
            emoji: "1f44d"
            didIReactWithThisEmoji: false
            numberOfReactions: 2
            jsonArrayOfUsersReactedWithThisEmoji: "[\"Bob\", \"John\"]"
        }
        ListElement {
            emoji: "1f602"
            didIReactWithThisEmoji: true
            numberOfReactions: 3
            jsonArrayOfUsersReactedWithThisEmoji: "[\"You\", \"Sally\", \"Tom\"]"
        }
    }

    ListModel {
        id: reactionsB

        ListElement {
            emoji: "2764"
            didIReactWithThisEmoji: false
            numberOfReactions: 5
            jsonArrayOfUsersReactedWithThisEmoji: "[\"Mia\"]"
        }
    }

    Component {
        id: reactionsComp

        MessagePrivate.StatusMessageEmojiReactions {
            x: 10
            y: 100
            width: 400
            reactionsModel: reactionsA
        }
    }

    SignalSpy {
        id: toggleSpy
        signalName: "toggleReaction"
    }

    SignalSpy {
        id: addSpy
        signalName: "addEmojiClicked"
    }

    SignalSpy {
        id: hoverSpy
        signalName: "hoverChanged"
    }

    TestCase {
        name: "StatusMessageEmojiReactions"
        when: windowShown

        property var reactions

        function init() {
            failOnWarning(/TypeError|ReferenceError|Unable to assign|Binding loop|undefined/)
            reactions = createTemporaryObject(reactionsComp, root)
            verify(!!reactions)
            for (const spy of [toggleSpy, addSpy, hoverSpy]) {
                spy.clear()
                spy.target = reactions
            }
            waitForRendering(reactions)
        }

        function cleanup() {
            mouseMove(root, 1, 1)
        }

        function reaction(hexcode) {
            return findChild(reactions, "messageReaction_" + hexcode)
        }

        function reactionIds() {
            const result = []
            for (const child of reactions.children)
                if (child.objectName.startsWith("messageReaction_"))
                    result.push(child.objectName.slice("messageReaction_".length))
            return result
        }

        function countText(item) {
            return findChild(item, "emojiReaction").parent.children[1].text
        }

        function addButton() {
            const children = reactions.children
            return children[children.length - 1]
        }

        function tooltip() {
            return findChild(reactions, "reactionAuthorsTooltip")
        }

        function test_showsTheReactions() {
            compare(reactionIds(), ["1f600", "1f44d", "1f602"])

            const smile = reaction("1f600")
            compare(findChild(smile, "emojiReaction").emoji, "😀")
            compare(countText(smile), "1")
            compare(countText(reaction("1f44d")), "2")
            compare(smile.Accessible.name, "1f600")

            // the user's own reactions are outlined
            compare(smile.border.width, 1)
            compare(reaction("1f44d").border.width, 0)
            verify(smile.color.toString() !== reaction("1f44d").color.toString())
        }

        function test_followsTheModel() {
            reactionsA.setProperty(1, "numberOfReactions", 7)
            compare(countText(reaction("1f44d")), "7")

            reactionsA.setProperty(1, "didIReactWithThisEmoji", true)
            compare(reaction("1f44d").border.width, 1)

            reactionsA.append({ emoji: "1f525", didIReactWithThisEmoji: false, numberOfReactions: 1,
                                jsonArrayOfUsersReactedWithThisEmoji: "[\"Ann\"]" })
            compare(reactionIds(), ["1f600", "1f44d", "1f602", "1f525"])
            reactionsA.remove(3)
            compare(reactionIds(), ["1f600", "1f44d", "1f602"])

            reactionsA.setProperty(1, "numberOfReactions", 2)
            reactionsA.setProperty(1, "didIReactWithThisEmoji", false)
        }

        // a pooled message row points its reactions at another message's
        function test_switchesToAnotherModel() {
            reactions.reactionsModel = reactionsB
            compare(reactionIds(), ["2764"])
            compare(countText(reaction("2764")), "5")

            reactions.reactionsModel = null
            compare(reactionIds(), [])
            verify(addButton().visible)
        }

        function test_clickTogglesTheReaction() {
            mouseClick(reaction("1f44d"))
            compare(toggleSpy.count, 1)
            compare(toggleSpy.signalArguments[0][0], "1f44d")
        }

        function test_addButton() {
            const add = addButton()
            verify(add.visible)
            mouseClick(add)
            compare(addSpy.count, 1)
            compare(addSpy.signalArguments[0][1].button, Qt.LeftButton)

            reactions.limitReached = true
            mouseClick(add)
            compare(addSpy.count, 1, "no reaction can be added past the limit")

            // reactions not allowed in this chat
            reactions.enabled = false
            verify(!add.visible)
            mouseClick(reaction("1f44d"))
            compare(toggleSpy.count, 0)
        }

        function test_hoverAndHighlight() {
            const thumbs = reaction("1f44d")
            // a string, not the color: a read value type can stay bound to its property
            const restingColor = thumbs.color.toString()

            mouseMove(thumbs, thumbs.width / 2, thumbs.height / 2)
            tryCompare(thumbs.border, "width", 1)
            verify(thumbs.color.toString() !== restingColor)
            compare(hoverSpy.count, 1)
            compare(hoverSpy.signalArguments[0][0], true)

            mouseMove(root, 1, 1)
            tryCompare(thumbs.border, "width", 0)
            compare(thumbs.color.toString(), restingColor)
            compare(hoverSpy.signalArguments[1][0], false)

            reactions.messageHighlighted = true
            compare(thumbs.border.width, 1)
        }

        // one tooltip serves all the reactions, built on the first hover
        function test_authorsToolTip() {
            const smile = reaction("1f600")
            const laugh = reaction("1f602")
            verify(!tooltip(), "nothing is built before a hover")

            mouseMove(smile, smile.width / 2, smile.height / 2)
            tryVerify(() => !!tooltip() && tooltip().opened, 3000)
            const tip = tooltip()
            compare(tip.text, "You reacted with 😀")
            compare(tip.parent, smile)

            mouseMove(laugh, laugh.width / 2, laugh.height / 2)
            tryCompare(tip, "parent", laugh)
            // the list's separators follow the locale
            verify(/^You, Sally.* Tom reacted with 😂$/.test(tip.text), tip.text)
            tryVerify(() => tip.opened, 3000)

            mouseMove(root, 1, 1)
            tryVerify(() => !tip.visible)

            // the hovered reaction goes away with its model
            mouseMove(laugh, laugh.width / 2, laugh.height / 2)
            tryVerify(() => tip.opened, 3000)
            reactions.reactionsModel = reactionsB
            tryVerify(() => !tip.visible)
        }

        function test_touchRaisesNoToolTip() {
            const smile = reaction("1f600")
            touchEvent(smile).press(0, smile, smile.width / 2, smile.height / 2).commit()
            wait(1000)
            verify(!tooltip() || !tooltip().visible)
            touchEvent(smile).release(0, smile, smile.width / 2, smile.height / 2).commit()
            compare(toggleSpy.count, 1, "a tap still toggles the reaction")
        }
    }
}
