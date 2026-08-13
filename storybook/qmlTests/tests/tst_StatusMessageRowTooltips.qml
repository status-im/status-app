import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Components.private as MessagePrivate

/*
 Perf guard: a chat switch creates ~100 ToolTip instances that only ever
 matter on desktop hover (verification icons, reaction author lists). They
 must be created on first hover, not with the row.
*/
Item {
    id: root

    width: 400
    height: 300

    Component {
        id: verificationIconsComp

        StatusContactVerificationIcons {
            isContact: true
        }
    }

    ListModel {
        id: reactionsData

        ListElement {
            emoji: "thumbsUp"
            numberOfReactions: 2
            didIReactWithThisEmoji: false
            jsonArrayOfUsersReactedWithThisEmoji: "[\"Alice\",\"Bob\"]"
        }
    }

    Component {
        id: reactionsComp

        MessagePrivate.StatusMessageEmojiReactions {
            reactionsModel: reactionsData
        }
    }

    TestCase {
        name: "StatusMessageRowTooltips"
        when: windowShown

        // Popups declared as resources (e.g. inside repeater delegates) have
        // no QObject parent chain, so findChild misses them — walk the data
        // lists instead.
        function findInData(item, name) {
            if (!item)
                return null
            if (item.objectName === name)
                return item
            const list = item.data ?? item.children
            if (!list)
                return null
            for (let i = 0; i < list.length; i++) {
                const found = findInData(list[i], name)
                if (found)
                    return found
            }
            return null
        }

        function test_verificationIconsTooltipNotInstantiatedBeforeHover() {
            const icons = createTemporaryObject(verificationIconsComp, root)
            verify(!!icons)
            waitForRendering(icons)

            compare(findChild(icons, "verificationIconsTooltip"), null,
                    "verification tooltip must not exist before the first hover")
        }

        function test_reactionAuthorsTooltipNotInstantiatedBeforeHover() {
            const reactions = createTemporaryObject(reactionsComp, root)
            verify(!!reactions)
            waitForRendering(reactions)

            verify(!!findChild(reactions, "messageReaction_thumbsUp"),
                   "reaction button itself must exist")
            compare(findInData(reactions, "reactionAuthorsTooltip"), null,
                    "reaction authors tooltip must not exist before the first hover")
        }
    }
}
