import QtQuick
import QtTest

import StatusQ.Core.Utils

TestCase {
    id: testCase
    name: "TestEmoji"

    function test_ascii_emoticons_are_resolved() {
        compare(Emoji.getAsciiEmoji(":)"), "\u{1F642}")
        compare(Emoji.getAsciiEmoji(">:)"), "\u{1F608}")
        compare(Emoji.getAsciiEmoji("not-an-emoticon"), "")
        compare(Emoji.maxAsciiEmojiLength(), 3)
    }

    function test_random_emoji() {
        verify(Emoji.getRandomEmoji().trim() !== "", "Random emoji is empty")
    }
}
