import QtQuick
import QtTest

import shared.controls.chat

Item {
    id: root

    width: 200
    height: 200

    // Takes the one-time font alias scan's warning at load, before any test lays out text.
    Text {
        font.family: "Sans Serif"
        text: "x"
    }

    Component {
        id: reactionComponent

        EmojiReaction {}
    }

    TestCase {
        name: "EmojiReaction"
        when: windowShown

        function renderedEmoji(reaction) {
            return findChild(reaction, "emojiReaction_statusEmoji").emoji
        }

        // Reaction ids follow Twemoji's filename spelling, which drops U+FE0F. The
        // character must be the catalogue's fully-qualified one, or these render in a
        // text font instead of as emoji.
        function test_idWithoutTheSelectorRendersTheQualifiedCharacter_data() {
            return [
                { tag: "heart", emojiId: "2764", expected: "\u2764\uFE0F" },
                { tag: "smiling face", emojiId: "263a", expected: "\u263A\uFE0F" },
                { tag: "hand", emojiId: "1f590", expected: "\u{1F590}\uFE0F" },
                { tag: "no selector needed", emojiId: "1f602", expected: "\u{1F602}" },
            ]
        }

        function test_idWithoutTheSelectorRendersTheQualifiedCharacter(data) {
            const reaction = createTemporaryObject(reactionComponent, root,
                                                   { emojiId: data.emojiId })
            compare(renderedEmoji(reaction), data.expected)
        }

        // An id the catalogue does not know still renders, rebuilt from its code points.
        function test_unknownIdFallsBackToTheCodePoints() {
            const reaction = createTemporaryObject(reactionComponent, root,
                                                   { emojiId: "1f9ff-1f9ff" })
            compare(renderedEmoji(reaction), "\u{1F9FF}\u{1F9FF}")
        }
    }
}
