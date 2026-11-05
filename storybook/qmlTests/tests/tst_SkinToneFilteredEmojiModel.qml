import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import shared.status

// The message context menu shows the first rows of this model as quick
// reactions, with no emoji picker alive.
Item {
    id: root

    Component {
        id: modelComponent

        SkinToneFilteredEmojiModel {
            emojiModel: SQUtils.Emoji.emojiModel
        }
    }

    TestCase {
        name: "SkinToneFilteredEmojiModel"

        property var savedRecents

        function initTestCase() {
            savedRecents = SQUtils.Emoji.emojiModel.recentEmojis
        }

        function cleanup() {
            SQUtils.Emoji.emojiModel.recentEmojis = savedRecents
        }

        function unicodes(model) {
            const result = []
            for (let i = 0; i < model.count; ++i)
                result.push(SQUtils.ModelUtils.get(model, i, "unicode"))
            return result
        }

        function test_baseToneByDefault() {
            const model = createTemporaryObject(modelComponent, root)
            const all = unicodes(model)

            verify(model.count > 0)
            verify(all.includes("1f44b"), "base waving hand expected")
            verify(!all.includes("1f44b-1f3fb"), "toned variants must be filtered out")
        }

        function test_chosenToneReplacesTheBase() {
            const model = createTemporaryObject(modelComponent, root, { skinColor: "1f3fb" })
            const all = unicodes(model)

            verify(all.includes("1f44b-1f3fb"))
            verify(!all.includes("1f44b"))
            verify(!all.includes("1f44b-1f3fc"))
            verify(all.includes("1f600"), "emoji without tones stay")
        }

        function test_recentsComeFirst() {
            SQUtils.Emoji.emojiModel.recentEmojis = ["1f680", "2764"]
            const model = createTemporaryObject(modelComponent, root)

            compare(SQUtils.ModelUtils.get(model, 0, "unicode"), "1f680")
            compare(SQUtils.ModelUtils.get(model, 1, "unicode"), "2764")
        }
    }
}
