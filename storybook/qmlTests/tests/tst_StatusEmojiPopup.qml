import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import shared.status

/*
 The picker hands out two things per emoji: the character to insert into the text,
 and the hexcode the backend and the recents list are keyed by. They are not
 interchangeable - the hexcode follows Twemoji's filename convention, which drops
 U+FE0F - so the character has to come from the catalogue, not be rebuilt from the
 hexcode.
*/
Item {
    id: root

    width: 600
    height: 600

    StatusEmojiPopup {
        id: picker

        directParent: root
        relativeX: 0
        relativeY: 0
        width: 370
        height: 440
        userUID: "tst_StatusEmojiPopup"
        emojiModel: SQUtils.Emoji.emojiModel
    }

    Component {
        id: pickerComponent

        StatusEmojiPopup {
            directParent: root
            bottomSheetAllowed: false
            width: 370
            height: 440
            userUID: "tst_StatusEmojiPopup"
            emojiModel: SQUtils.Emoji.emojiModel
        }
    }

    StatusEmojiSuggestionPopup {
        id: suggestions
        width: 300
    }

    SignalSpy {
        id: spy
        target: picker
        signalName: "emojiSelected"
    }

    TestCase {
        name: "StatusEmojiPopup"
        when: windowShown

        function init() {
            spy.clear()
        }

        // The grid is built with the popup, so the first open does not pay for it.
        function test_gridIsBuiltWithThePopup() {
            const popup = createTemporaryObject(pickerComponent, root)
            verify(!!findChild(popup.contentItem, "StatusEmojiPopup_searchBox"))
        }

        // The message context menu shows the first rows of fullModel as quick
        // reactions, whether or not the picker was ever opened.
        function test_fullModelIsAvailableBeforeTheFirstOpen() {
            const popup = createTemporaryObject(pickerComponent, root)
            verify(popup.fullModel.count > 0)
        }

        function test_searchIsClearedOnClose() {
            const popup = createTemporaryObject(pickerComponent, root)
            popup.open()
            tryCompare(popup, "opened", true)
            const searchBox = findChild(popup.contentItem, "StatusEmojiPopup_searchBox")
            searchBox.text = "heart"
            compare(popup.searchString, "heart")
            verify(popup.fullModel.count > 0 && popup.fullModel.count < 100)

            popup.close()
            tryCompare(popup, "visible", false)
            compare(popup.searchString, "")
            compare(searchBox.text, "")
        }

        // ❤ is stored as "2764", but its character is the fully-qualified U+2764 U+FE0F. Without
        // the variation selector the base character defaults to text presentation and
        // renders from a text font instead of the emoji one.
        function test_emojiSelected_carriesTheFullyQualifiedCharacter() {
            picker.addEmoji("2764", "\u2764\uFE0F")

            compare(spy.count, 1)
            const emitted = spy.signalArguments[0][0]
            verify(emitted.includes("\uFE0F"),
                   `payload must keep U+FE0F, got ${JSON.stringify(emitted)}`)
            compare(emitted, "\u2764\uFE0F")
        }

        // The hexcode is a stored identifier: recents are persisted under it and
        // reactions are sent with it, so it must pass through untouched.
        function test_emojiSelected_passesTheHexcodeThrough() {
            picker.addEmoji("2764", "\u2764\uFE0F")

            compare(spy.count, 1)
            compare(spy.signalArguments[0][2], "2764")
        }

        // Guards the reason the character is taken from the catalogue.
        function test_rebuildingFromHexcodeWouldDropTheVariationSelector() {
            const rebuilt = SQUtils.Emoji.getEmojiCodepoint("2764")
            compare(rebuilt, "\u2764")
            verify(!rebuilt.includes("\uFE0F"))
        }

        // The ":shortname" suggestion list carries the same two values and has the same
        // requirement: `emoji` is what gets typed, `unicode` only identifies the entry.
        function test_suggestions_exposeTheFullyQualifiedCharacter() {
            const entries = SQUtils.Emoji.getSuggestions("heart")
            verify(entries.length > 0, "expected suggestions for ':heart'")

            suggestions.openPopup(entries, "heart")
            suggestions.listView.currentIndex = 0

            compare(suggestions.emoji, entries[0].emoji)
            compare(suggestions.unicode, entries[0].unicode)
            suggestions.close()
        }

        // At least one of them must actually need the selector, or the check above
        // would pass even if the character were rebuilt from the hexcode.
        function test_suggestions_includeAnEmojiThatNeedsTheSelector() {
            const entries = SQUtils.Emoji.getSuggestions("heart")
            const qualified = entries.filter(e => e.emoji.includes("\uFE0F"))
            verify(qualified.length > 0,
                   "expected a ':heart' suggestion whose character carries U+FE0F")
            verify(!qualified[0].unicode.includes("fe0f"),
                   "...and whose hexcode does not, which is the trap")
        }
    }
}
