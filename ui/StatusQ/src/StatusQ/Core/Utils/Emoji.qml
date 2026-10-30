pragma Singleton

import QtQuick

import StatusQ

QtObject {
    readonly property StatusEmojiModel emojiModel: StatusEmojiModel { id: emojiModel }

    function getEmojiCodepoint(iconCodePoint) {
        // Split the codepoint to get all the parts and then encode them from hex to utf8
        const splitCodePoint = iconCodePoint.split('-')
        let codePointParts = []
        splitCodePoint.forEach(function (codePoint) {
            codePointParts.push(`0x${codePoint}`)
        })
        return String.fromCodePoint(...codePointParts);
    }

    // Returns a random emoji (the character as the catalogue stores it), excluding flags
    // WARNING: use status-go RandomWalletEmoji instead.
    // More details here: https://github.com/status-im/status-go/issues/5663
    function getRandomEmoji() {
        return emojiModel.getRandomEmoji()
    }

    function getSuggestions(input: string) : var {
        return emojiModel.getSuggestions(input)
    }

    // Length of the longest ASCII emoticon, to bound the look-back when matching one.
    function maxAsciiEmojiLength(): int {
        return emojiModel.maxAsciiEmojiAliasLength()
    }

    // Returns the emoji character for an ASCII emoticon, or "" when it isn't one.
    function getAsciiEmoji(text: string): string {
        return emojiModel.getEmojiFromAsciiAlias(text)
    }
}
