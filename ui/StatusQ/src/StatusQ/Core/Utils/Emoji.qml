pragma Singleton

import QtQuick

import StatusQ

import "../../../assets/twemoji/twemoji.js" as Twemoji
import "./emojiList.js" as EmojiJSON

QtObject {
    readonly property var size: {
        "veryBig": "86x86",
        "big": "72x72",
        "middle": "32x32",
        "small": "18x18",
        "verySmall": "16x16"
    }
    readonly property string base: Qt.resolvedUrl("../../../assets/twemoji/svg/")
    readonly property var emojiJSON: EmojiJSON

    readonly property StatusEmojiModel emojiModel: StatusEmojiModel {
        emojiJson: EmojiJSON.emoji_json
    }

    function parse(text, renderSize = size.small) {
        const renderSizes = renderSize.split("x");
        if (!renderSize.includes("x") || renderSizes.length !== 2) {
            throw new Error("Invalid value for 'renderSize' parameter: ", renderSize);
        }
        Twemoji.twemoji.base = base
        Twemoji.twemoji.ext = `.svg`

        return Twemoji.twemoji.parse(text, {
            callback: (iconId, options) => {
                return options.base + iconId + options.ext;
            },
            attributes: function() {
              return {
                width: renderSizes[0],
                height: renderSizes[1],
                style: "vertical-align: top"
              }
            }
        })
    }
    function iconSource(text) {
        if (!text) return
        const parsed = parse(text);
        const match = parsed.match('src="(.*\.svg).*"');
        return (match && match.length >= 2) ? match[1] : undefined;
    }
    function svgImage(unicode) {
        return `${base}/${unicode}.svg`
    }
    function iconId(text) {
        if (!text) return
        const parsed = parse(text);
        const match = parsed.match('src=".*\/(.+?).svg');
        return (match && match.length >= 2) ? match[1] : undefined;
    }
    // NOTE: doing the same thing as iconId but without checking Twemoji internal checks
    function iconHex(text) {
        if (!text) return
        return text.codePointAt(0).toString(16);
    }
    function fromCodePoint(value) {
        return Twemoji.twemoji.convert.fromCodePoint(value)
    }

    // This regular expression looks for html tag `img` with following attributes in any order:
    //  - `src` containig with "/assets/twemoji/" substring
    //  - `alt` (this one is captured)
    readonly property var emojiRegexp: /<img(?=[^>]*\balt="([^"]*)")(?=[^>]*\bsrc="[^>]*\/assets\/twemoji\/[^>]*")[^>]*>/g

    function deparse(value) {
        return value.replace(emojiRegexp, "$1");
    }
    function hasEmoji(value) {
        let match = value.match(emojiRegexp)
        return match && match.length > 0
    }
    function nbEmojis(value) {
        let match = value.match(emojiRegexp)
        return match ? match.length : 0
    }
    function getEmojis(value) {
        return value.match(emojiRegexp, "$1");
    }
    function getEmojiUnicode(shortname) {
        const _emoji = emojiModel.getEmojiUnicodeFromShortname(shortname);
        if (!!_emoji)
            return _emoji;
    }

    function getEmojiCodepoint(iconCodePoint) {
        // Split the codepoint to get all the parts and then encode them from hex to utf8
        const splitCodePoint = iconCodePoint.split('-')
        let codePointParts = []
        splitCodePoint.forEach(function (codePoint) {
            codePointParts.push(`0x${codePoint}`)
        })
        return String.fromCodePoint(...codePointParts);
    }

    // Used to exclude flags emojis from the random emoji picker
    // Based on the knowledge that flags emojis are contiguous in the emoji list
    readonly property int firstFlagIndex: 3504
    readonly property int lastFlagIndex: 3772
    readonly property int flagsCount: lastFlagIndex - firstFlagIndex + 1

    // Returns a random emoji excluding flags emojis
    // WARNING: use status-go RandomWalletEmoji instead.
    // More details here: https://github.com/status-im/status-go/issues/5663
    function getRandomEmoji(size) {
        let whitelistedIndex = Math.floor(Math.random() * (EmojiJSON.emoji_json.length - flagsCount))
        // Compensating for the missing flags emojis index
        if (whitelistedIndex >= firstFlagIndex) {
            whitelistedIndex += flagsCount
        }
        var randomEmoji = EmojiJSON.emoji_json[whitelistedIndex]

        const extensionIndex = randomEmoji.unicode.lastIndexOf('.');
        let iconCodePoint = randomEmoji.unicode
        if (extensionIndex > -1) {
            iconCodePoint = iconCodePoint.substring(0, extensionIndex)
        }

        const encodedIcon = getEmojiCodepoint(iconCodePoint)

        // Adding a space because otherwise, some emojis would fuse since emoji is just a string
        return parse(encodedIcon, size || undefined) + ' '
    }

    function getSuggestions(input: string) : var {
        return emojiJSON.emoji_json.filter(emoji => {
            return emoji.name.includes(input) ||
                    emoji.shortname.includes(input) ||
                    emoji.aliases.some(a => a.includes(input)) ||
                    emoji.keywords.some(k => k.includes(input))
        })
    }
}
