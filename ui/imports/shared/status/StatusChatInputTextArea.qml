import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls as StatusQ

import AppLayouts.Chat.adaptors
import utils

import QtModelsToolkit

StatusQ.StatusTextArea {
    id: root

    // Maximum size of the message that is considered as appropriate to be sent.
    // The user can provide more content, up to messageLimitHard, but behavior
    // of the input changes above that limit, e.g. inline emojis are not
    // coverted into images.
    property int messageLimit: 20

    // Strict limit of the input. Content exceeding that limit will be ignored.
    property int messageLimitHard: 200

    // List of urls that are intended to be highlighted.
    property var urlsList: []

    // Url intended to have special highlighting. Can be used e.g. when
    // corresponding preview is hovered.
    property string urlToBeHighlighted

    // Model of users used for creating mention suggestions list. Expected
    // roles: "pubKey", "preferredDisplayName".
    required property var usersModel

    // Read-only model of mentions suggestions. It's subset of usersModel
    // filtered according to the provided partial name.
    readonly property alias suggestionsModel: suggestionsFilterAdaptor.model

    // Pub key of mention which is intended to be inserted when user enters full
    // name of that contact. E.g. pub key of contact "Maria" is provided, user's
    // input @maria will be converted to interactive mention. But if the pub key
    // points to contact "Maria2", input @maria won't trigger convertion into
    // mention (would do after entering the remaining part - "2").
    property string suggestedMentionPubKey

    // Partial emoji name currently provided by the user (like :man). Can be
    // used to provide emoji suggestions list.
    readonly property alias emojiFilter: d.emojiFilter

    // Used for mention suggestion handling. To be removed later.
    readonly property alias lastAtPosition: suggestionsFilterAdaptor.lastAtPosition

    // Indicates whether the mention insertion is active. Mention insertion is
    // active when @ was entered and there are suggestions available for the
    // provided partial name.
    readonly property bool activeMentionInput:
        suggestionsFilterAdaptor.lastAtPosition > -1 &&
        suggestionsFilterAdaptor.model.ModelCount.count > 0

    // Mention internal representation details, exposed to potentially use in
    // external processing.
    readonly property string mentionTagStart:
        `<span style="background-color: ${Theme.palette.mentionColor2};"><a style="color:${Theme.palette.mentionColor1};text-decoration:none" href='http://'>`
    readonly property string mentionTagEnd: `</a></span>`

    // Signal emitted when user attempts to add content exceeding hard limit.
    signal attemptToExceedHardLimit

    textFormat: Text.RichText
    color: Theme.palette.textColor
    background: null
    inputMethodHints: Qt.ImhMultiLine | Qt.ImhNoEditMenu

    EnterKey.type: Qt.EnterKeyReturn // insert newlines hint for OSK

    Keys.onShortcutOverride: function (event) {
        event.accepted = event.matches(StandardKey.Paste)
    }

    Keys.onPressed: event => {
        d.lastKeyPressedEvent = event

        const symbolPressed = event.text.length > 0 &&
                            event.key !== Qt.Key_Backspace &&
                            event.key !== Qt.Key_Delete &&
                            event.key !== Qt.Key_Escape

        if (d.mentionsPos.length > 0 && symbolPressed && root.selectedText.length === 0) {
            for (let i = 0; i < d.mentionsPos.length; i++) {
                if (root.cursorPosition === d.mentionsPos[i].leftIndex) {
                    d.leftOfMentionIndex = i
                    event.accepted = true
                    return
                } else if (root.cursorPosition === d.mentionsPos[i].rightIndex) {
                    d.rightOfMentionIndex = i
                    event.accepted = true
                    return
                }
            }
        }

        // handle new line in blockquote
        if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
            && (event.modifiers & Qt.ShiftModifier)) {
            const message = d.extrapolateCursorPosition()

            if (message.data.startsWith(">") && !message.data.endsWith("\n\n")) {
                let newMessage1 = ""
                if (message.data.endsWith("\n> ")) {
                    newMessage1 = message.data.substr(0, message.data.lastIndexOf("> ")) + "\n\n"
                } else {
                    newMessage1 = message.data + "\n> "
                }
                root.remove(0, root.cursorPosition)
                insertInTextInput(0, StatusQUtils.Emoji.parse(newMessage1))
                event.accepted = true
            }
        }

        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            const message = d.extrapolateCursorPosition()
            if (d.mentionsPos.length > 0) {
                let anticipatedCursorPosition = root.cursorPosition
                anticipatedCursorPosition += event.key === Qt.Key_Backspace ?
                                               -1 : 1

                const mention = d.getMentionAtPosition(anticipatedCursorPosition)
                if (mention) {
                    d.removeMention(mention)
                    event.accepted = true
                }
            }

            // handle backspace when entering an existing blockquote
            if(message.data.startsWith(">") && message.data.endsWith("\n\n")) {
                const newMessage = message.data.substr(0, message.data.lastIndexOf("\n")) + "> ";
                root.remove(0, root.cursorPosition);
                insertInTextInput(0, StatusQUtils.Emoji.parse(newMessage));
                event.accepted = true
            }
        }

        if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) {
            if (root.selectedText !== "") {
                d.copiedTextPlain = root.getText(
                            root.selectionStart, root.selectionEnd)
                d.copiedTextFormatted = root.getFormattedText(
                            root.selectionStart, root.selectionEnd)
                d.copyMentions(root.selectionStart, root.selectionEnd)
            }
        } else if (event.matches(StandardKey.Paste)) {
            if (!ClipboardUtils.hasText)
                return

            const clipboardText = StatusQUtils.StringUtils.plainText(ClipboardUtils.text)
            // prevent repetitive & huge clipboard paste, where huge is total char count > than messageLimitHard
            const selectionLength = root.selectionEnd - root.selectionStart
            if ((length + clipboardText.length - selectionLength) > root.messageLimitHard)
            {
                attemptToExceedHardLimit()
                event.accepted = true
                return
            }

            root.remove(root.selectionStart, root.selectionEnd)

            // cursor position must be stored in a helper property because setting readonly to true causes change
            // of the cursor position to the end of the input
            d.copyTextStart = root.cursorPosition
            root.readOnly = true

            const copiedText = StatusQUtils.StringUtils.plainText(d.copiedTextPlain)

            if (copiedText === clipboardText) {
                if (d.copiedTextPlain.includes("@")) {
                    d.copiedTextFormatted = d.copiedTextFormatted.replace(
                                        /span style="/g, "span style=\" text-decoration:none;")

                    let lastFoundIndex = -1
                    for (let j = 0; j < d.copiedMentionsPos.length; j++) {
                        const name = d.copiedMentionsPos[j].name
                        const indexOfName = d.copiedTextPlain.indexOf(name, lastFoundIndex)
                        lastFoundIndex += name.length

                        if (indexOfName === d.copiedMentionsPos[j].leftIndex + 1) {
                            const mention = {
                                name: name,
                                pubKey: d.copiedMentionsPos[j].pubKey,
                                leftIndex: (d.copiedMentionsPos[j].leftIndex + d.copyTextStart - 1),
                                rightIndex: (d.copiedMentionsPos[j].leftIndex + d.copyTextStart + name.length)
                            }
                            d.mentionsPos.push(mention)
                            d.sortMentions()
                        }
                    }
                }
                insertInTextInput(d.copyTextStart, d.copiedTextFormatted)
            } else {
                d.copiedTextPlain = ""
                d.copiedTextFormatted = ""
                d.copiedMentionsPos = []
                root.insert(d.copyTextStart, ((d.nbEmojisInClipboard === 0) ?
                ("<div style='white-space: pre-wrap'>" + StatusQUtils.StringUtils.escapeHtml(ClipboardUtils.text) + "</div>")
                : StatusQUtils.Emoji.deparse(ClipboardUtils.html)))
            }

            // Reset readOnly immediately after paste completes
            // Don't wait for onReleased which might not fire on mobile
            if (StatusQUtils.Utils.isMobile) {
                root.readOnly = false
                root.cursorPosition = (d.copyTextStart + ClipboardUtils.text.length + d.nbEmojisInClipboard)
            }
            event.accepted = true
        }
    }

    // gives up-to-date cursorPosition
    Keys.onReleased: event => {
        // these are likely shortcuts with no meaningful text
        if ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.MetaModifier))
            return

        if ((event.key === Qt.Key_Shift))
            return

        // the text doesn't get registered to the textarea fast enough
        // we can only get it in the `released` event

        const eventText = event.key === Qt.Key_Space ? "&nbsp;" : event.text

        if(d.rightOfMentionIndex !== -1) {
            //make sure to add an extra space between mention and text
            let mentionSeparator = event.key === Qt.Key_Space ? "" : "&nbsp;"
            root.insert(d.mentionsPos[d.rightOfMentionIndex].rightIndex, mentionSeparator + eventText)

            d.rightOfMentionIndex = -1
        }

        if(d.leftOfMentionIndex !== -1) {
            root.insert(d.mentionsPos[d.leftOfMentionIndex].leftIndex, eventText)

            d.leftOfMentionIndex = -1
        }

        if (event.key !== Qt.Key_Escape)
             d.emojiHandler(event)

        if (root.readOnly) {
            root.readOnly = false
            root.cursorPosition = d.copyTextStart + ClipboardUtils.text.length + d.nbEmojisInClipboard
        }

        if (suggestedMentionPubKey) {
            const namePrefix = suggestionsFilterAdaptor.filter
            const lastCursorPosition = root.cursorPosition
            const lastAtPosition = suggestionsFilterAdaptor.lastAtPosition
            const fullName = StatusQUtils.ModelUtils.getByKey(
                               suggestionsFilterAdaptor.model, "pubKey",
                               root.suggestedMentionPubKey, "preferredDisplayName")

            const namePrefixLowerCase = namePrefix.toLowerCase()
            const fullNameLowerCase = fullName.toLowerCase()

            if (namePrefix !== "" && namePrefixLowerCase === fullNameLowerCase
                    && event.key !== Qt.Key_Backspace
                    && event.key !== Qt.Key_Delete
                    && event.key !== Qt.Key_Left) {
                d.insertMention(fullName, suggestedMentionPubKey,
                                lastAtPosition, lastCursorPosition)
            }
        }
    }

    onCursorPositionChanged: {
        if (d.mentionsPos.length > 0 &&
                (d.lastKeyPressedEvent.key === Qt.Key_Left ||
                 d.lastKeyPressedEvent.key === Qt.Key_Right ||
                 selectedText.length>0)) {
            const mention = d.getMentionAtPosition(cursorPosition)

            if (mention) {
                const cursorMovingLeft = (cursorPosition < d.previousCursorPosition);
                const newCursorPosition = cursorMovingLeft ?
                                            mention.leftIndex :
                                            mention.rightIndex
                const isSelection = (selectedText.length>0);
                isSelection ? moveCursorSelection(newCursorPosition, TextEdit.SelectCharacters) :
                              cursorPosition = newCursorPosition
            }
        }

        d.previousCursorPosition = cursorPosition
    }

    onTextChanged: {
        if (length <= root.messageLimit) {
            if (length === 0) {
                d.mentionsPos = []
            } else {
                d.convertInlineEmojis()
            }
        } else if (length > root.messageLimitHard) {
            const removeFrom = cursorPosition < root.messageLimitHard
                             ? cursorWhenPressed
                             : root.messageLimitHard
            remove(removeFrom, cursorPosition)

            attemptToExceedHardLimit()
        }

        d.updateMentionsPositions()
        d.cleanMentionsPos()
        suggestionsFilterAdaptor.invalidateFilter()
    }

    onLinkActivated: {
        const mention = d.getMentionAtPosition(cursorPosition - 1)
        if(mention) {
            select(mention.leftIndex, mention.rightIndex)
        }
    }

    function insertMention(name: string, pubKey: string) {
        d.insertMention(name, pubKey,
                         suggestionsFilterAdaptor.lastAtPosition,
                         suggestionsFilterAdaptor.cursorPosition)
    }

    function getTextWithPublicKeys() {
        let result = root.text

        if (d.mentionsPos.length > 0) {
            for (let k = 0; k < d.mentionsPos.length; k++) {
                const leftIndex = result.indexOf(d.mentionsPos[k].name)
                const rightIndex = leftIndex + d.mentionsPos[k].name.length
                result = result.substring(0, leftIndex)
                         + d.mentionsPos[k].pubKey
                         + result.substring(rightIndex, result.length)
            }
        }

        return result
    }

    function replaceWithEmoji(shortname, codePoint, offset = 0) {
        d.replaceWithEmoji(shortname, codePoint, offset)
    }

    function insertInTextInput(start, text) {
        // Replace new lines with entities because `insert` gets rid of them
        root.insert(start, text.replace(/\n/g, "<br/>"));
    }

    function wrapSelection(wrapWith) {
        if (root.selectionStart - root.selectionEnd === 0)
            return

        // calulate the new selection start and end positions
        const newSelectionStart = root.selectionStart + wrapWith.length
        const newSelectionEnd = root.selectionEnd
                              - root.selectionStart + newSelectionStart

        insertInTextInput(root.selectionStart, wrapWith);
        insertInTextInput(root.selectionEnd, wrapWith);

        root.select(newSelectionStart, newSelectionEnd)
    }

    function unwrapSelection(unwrapWith, selectedTextWithFormationChars) {
        if (root.selectionStart - root.selectionEnd === 0)
            return

        // Calculate the new selection start and end positions
        const newSelectionStart = root.selectionStart -  unwrapWith.length
        const newSelectionEnd = root.selectionEnd-root.selectionStart + newSelectionStart

        selectedTextWithFormationChars = selectedTextWithFormationChars.trim()
        // Check if the selectedTextWithFormationChars has formation chars and if so, calculate how many so we can adapt the start and end pos
        const selectTextDiff = (selectedTextWithFormationChars.length - root.selectedText.length) / 2

        // Remove the deselected option from the before and after the selected text
        const prefixChars = root.getText((root.selectionStart - selectTextDiff), root.selectionStart)
        const updatedPrefixChars = prefixChars.replace(unwrapWith, '')
        const postfixChars = root.getText(root.selectionEnd, (root.selectionEnd + selectTextDiff))
        const updatedPostfixChars = postfixChars.replace(unwrapWith, '')

        // Create updated selected string with pre and post formatting characters
        const updatedSelectedStringWithFormatChars = updatedPrefixChars + root.selectedText + updatedPostfixChars

        root.remove(root.selectionStart - selectTextDiff, root.selectionEnd + selectTextDiff)

        insertInTextInput(root.selectionStart, updatedSelectedStringWithFormatChars)

        root.select(newSelectionStart, newSelectionEnd)
    }

    function prefixSelectedLine(prefix) {
        const selectedLinePosition = d.getLineStartPosition(root.selectionStart)
        root.insertInTextInput(selectedLinePosition, prefix)
    }

    function unprefixSelectedLine(prefix) {
        if (isSelectedLinePrefixedBy(root.selectionStart, prefix)) {
            const selectedLinePosition = d.getLineStartPosition(root.selectionStart)
            root.remove(selectedLinePosition, selectedLinePosition + prefix.length)
        }
    }

    function isSelectedLinePrefixedBy(selectionStart, prefix) {
        const selectedLinePosition = d.getLineStartPosition(selectionStart)
        const text = getPlainText()
        const selectedLine = text.substring(selectedLinePosition)
        return selectedLine.startsWith(prefix)
    }

    function getPlainText() {
        const textWithoutMention = root.text.replace(
                                     /<span style="[ :#0-9a-z;\-\.,\(\)]+">(@([a-z\.]+(\ ?[a-z]+\ ?[a-z]+)?))<\/span>/ig,
                                     "\[\[mention\]\]$1\[\[mention\]\]")
        const deparsedEmoji = StatusQUtils.Emoji.deparse(textWithoutMention);

        return StatusQUtils.StringUtils.plainText(deparsedEmoji)
    }

    function convertInlineEmojis() {
        d.convertInlineEmojis(true)
    }

    QtObject {
        id: d

        // General
        property int previousCursorPosition: 0
        property KeyEvent lastKeyPressedEvent

        // Mentions
        property int leftOfMentionIndex: -1
        property int rightOfMentionIndex: -1

        property var mentionsPos: []
        property var copiedMentionsPos: []

        property string copiedTextPlain
        property string copiedTextFormatted
        property int copyTextStart: 0

        // Emojis
        readonly property int nbEmojisInClipboard:
            StatusQUtils.Emoji.nbEmojis(ClipboardUtils.html)

        property string emojiFilter: ""

        function updateMentionsPositions() {
            if (mentionsPos.length == 0) {
                return
            }

            const unformattedText = root.getText(0, root.length)
            if (!unformattedText.includes("@")) {
                return
            }

            const keyEvent = d.lastKeyPressedEvent
            if ((keyEvent.key === Qt.Key_Right) || (keyEvent.key === Qt.Key_Left)
                    || (keyEvent.key === Qt.Key_Up) || (keyEvent.key === Qt.Key_Down)) {
                return
            }

            let lastRightIndex = -1
            for (var k = 0; k < mentionsPos.length; k++) {
                const aliasIndex = unformattedText.indexOf(mentionsPos[k].name, lastRightIndex)
                if (aliasIndex === -1) {
                    continue
                }
                lastRightIndex = aliasIndex + mentionsPos[k].name.length

                if (aliasIndex - 1 !== mentionsPos[k].leftIndex) {
                    mentionsPos[k].leftIndex = aliasIndex - 1
                    mentionsPos[k].rightIndex = aliasIndex + mentionsPos[k].name.length
                }
            }

            d.sortMentions()
        }

        function insertMention(aliasName, publicKey, lastAtPosition, lastCursorPosition) {
            const hasEmoji = StatusQUtils.Emoji.hasEmoji(root.text)
            const spanPlusAlias = `${root.mentionTagStart}@${aliasName}${root.mentionTagEnd} `;

            let rightIndex = hasEmoji ? lastCursorPosition + 2 : lastCursorPosition
            root.remove(lastAtPosition, rightIndex)
            root.insert(lastAtPosition, spanPlusAlias)
            root.cursorPosition = lastAtPosition + aliasName.length + 2;
            if (root.cursorPosition === 0) {
                // It reset to 0 for some reason, go back to the end
                root.cursorPosition = root.length
            }

            mentionsPos = mentionsPos.filter(mention => mention.leftIndex !== lastAtPosition)
            mentionsPos.push({name: aliasName, pubKey: publicKey, leftIndex: lastAtPosition, rightIndex: (lastAtPosition+aliasName.length + 1)});
            d.sortMentions()
        }

        function sortMentions() {
            if (mentionsPos.length < 2) {
                return
            }
            mentionsPos = mentionsPos.sort(function(a, b){
                return a.leftIndex - b.leftIndex
            })
        }

        function cleanMentionsPos() {
            if(mentionsPos.length == 0) return

            const unformattedText = root.getText(0, root.length)
            mentionsPos = mentionsPos.filter(mention => unformattedText.charAt(mention.leftIndex) === "@")
        }

        function removeMention(mention) {
            const index = mentionsPos.indexOf(mention)
            if(index >= 0) {
                mentionsPos.splice(index, 1)
            }

            root.remove(mention.leftIndex, mention.rightIndex)
        }

        function getMentionAtPosition(position: int) : var {
            return mentionsPos.find(mention => mention.leftIndex < position && mention.rightIndex > position)
        }

        function copyMentions(start, end) {
            copiedMentionsPos = []
            for (let k = 0; k < mentionsPos.length; k++) {
                if (mentionsPos[k].leftIndex >= start && mentionsPos[k].rightIndex <= end) {
                    const mention = {
                        name: mentionsPos[k].name,
                        pubKey: mentionsPos[k].pubKey,
                        leftIndex: mentionsPos[k].leftIndex - start,
                        rightIndex: mentionsPos[k].rightIndex - start
                    }
                    copiedMentionsPos.push(mention)
                }
            }
        }

        // Emojis
        function emojiHandler(event) {
            const message = extrapolateCursorPosition()

            // sets emoji even to true if threre is : before cursor and the string
            // between : and cursor does not contain spaces or punctuation
            const emojiEvent = pollEmojiEvent(message)
            const isColonPressed = event.text === ":"

            // state machine to handle different forms of the emoji event state
            if (emojiEvent && isColonPressed) {
                const index = message.data.lastIndexOf(':', message.cursor - 2)
                if (index >= 0 && message.cursor > 0) {
                    const shortname = message.data.substr(index, message.cursor)
                    const codePoint = StatusQUtils.Emoji.getEmojiUnicode(shortname)
                    if (codePoint !== undefined)
                        replaceWithEmoji(shortname, codePoint)
                }
            } else if (emojiEvent && isKeyValid(event.key) && !isColonPressed) {
                const index2 = message.data.lastIndexOf(':', message.cursor - 1);
                if (index2 >= 0 && message.cursor > 0) {
                    d.emojiFilter = message.data.substr(index2, message.cursor)
                    return
                }
            }

            d.emojiFilter = ""
        }

        // check if user has placed cursor near valid emoji colon token
        function pollEmojiEvent(message) {
            const index = message.data.lastIndexOf(':', message.cursor)

            if (index === -1)
                return false

            return validSubstr(message.data.substring(index, message.cursor))
        }

        function validSubstr(substr) {
            for(let i = 0; i < substr.length; i++) {
                const c = substr.charAt(i)
                if (Utils.isSpace(c) || Utils.isPunct(c))
                    return false
            }
            return true
        }

        function isKeyValid(key) {
            if (key === Qt.Key_Space || key ===  Qt.Key_Tab ||
                    (key >= Qt.Key_Exclam && key <= Qt.Key_Slash) ||
                    (key >= Qt.Key_Semicolon && key <= Qt.Key_Question) ||
                    (key >= Qt.Key_BracketLeft && key <= Qt.Key_hyphen))
                return false;
            return true;
        }

        function replaceWithEmoji(shortname, codePoint, offset = 0) {
            const encodedCodePoint = StatusQUtils.Emoji.getEmojiCodepoint(codePoint)
            root.remove(root.cursorPosition - shortname.length - offset,
                                     root.cursorPosition);
            insertInTextInput(root.cursorPosition,
                              StatusQUtils.Emoji.parse(encodedCodePoint) + " ");
            d.emojiFilter = ""
        }

        // since emoji length is not 1 we need to match that position that TextArea returns
        // to the actual position in the string.
        function extrapolateCursorPosition() {
            // we need only the message part to be html
            const text = getPlainText()
            const completelyPlainText = d.removeMentions(text)
            const plainText = StatusQUtils.Emoji.parse(text)

            let bracketEvent = false
            let almostMention = false
            let mentionEvent = false
            let length = 0

            // This loop calculates the cursor position inside the plain text which contains the image tags (<img>) and the mention tags ([[mention]])
            const cursorPos = root.cursorPosition
            let character = ""

            let i = 0
            for (; i < plainText.length; i++) {
                if (length >= cursorPos) break

                character = plainText.charAt(i)
                if (!bracketEvent && character !== '<' && !mentionEvent && character !== '[')  {
                    length++
                } else if (!bracketEvent && character === '<') {
                    bracketEvent = true
                } else if (bracketEvent && character === '>') {
                    bracketEvent = false
                    length++
                } else if (!mentionEvent && almostMention && plainText.charAt(i) === '[') {
                    almostMention = false
                    mentionEvent = true
                } else if (!mentionEvent && !almostMention && plainText.charAt(i) === '[') {
                    almostMention = true
                } else if (!mentionEvent && almostMention && plainText.charAt(i) !== '[') {
                    almostMention = false
                } else if (mentionEvent && !almostMention && plainText.charAt(i) === ']') {
                    almostMention = true
                } else if (mentionEvent && almostMention && plainText.charAt(i) === ']') {
                    almostMention = false
                    mentionEvent = false
                }
            }

            const textBeforeCursor = StatusQUtils.Emoji.deparse(plainText.substr(0, i))

            return {
                cursor: countEmojiLengths(plainText.substr(0, i)) +
                            root.cursorPosition +
                            text.length - completelyPlainText.length,
                data: textBeforeCursor,
            }
        }

        function countEmojiLengths(value) {
            const match = StatusQUtils.Emoji.getEmojis(value);
            let length = 0;

            if (match && match.length > 0) {
                for (let i = 0; i < match.length; i++)
                    length += StatusQUtils.Emoji.deparse(match[i]).length
                length = length - match.length
            }
            return length
        }

        function getLineStartPosition(selectionStart) {
            const text = getPlainText()
            const lastNewLinePos = text.lastIndexOf("\n", root.selectionStart)
            return lastNewLinePos === -1 ? 0 : lastNewLinePos + 1
        }

        function removeMentions(currentText) {
            return currentText.replace(/\[\[mention\]\]/g, '')
        }

        // trigger inline emoji replacements at the end of the input, after space,
        // or always (force==true) when sending the message
        function convertInlineEmojis(force = false) {
            const position = root.cursorPosition

            if (force || root.getText(position, position - 1) === " ") {
                // figure out last word (between spaces), max length of 5
                let lastWord = ""

                // just before the last non-space character
                const cursorPos = position - (force ? 1 : 2)

                // go back until we found a space or start of line
                for (let i = cursorPos; i > cursorPos - 6; i--) {
                    const lastChar = root.getText(i, i + 1)

                    if (i < 0 || lastChar === " ") // reached start of line or a space
                        break
                    else
                        lastWord = lastChar + lastWord // collect the last word
                }

                const emojiReplacementSymbols = ":='xX><0O;*dB8-D#%\\"

                // check if the word contains any of the trigger chars (emojiReplacementSymbols)
                if (!!lastWord && Array.prototype.some.call(emojiReplacementSymbols,
                                                            trigger => lastWord.includes(trigger))) {
                    // search the ASCII aliases for a possible match
                    const emojiFound = StatusQUtils.Emoji.emojiJSON.emoji_json.find(
                                         emoji => emoji.aliases_ascii.includes(lastWord))

                    if (emojiFound) {
                        root.replaceWithEmoji(
                                    lastWord, emojiFound.unicode, force ? 0 : 1 /*offset*/)
                    }
                }
            }
        }
    }

    SuggestionsFilterAdaptor {
        id: suggestionsFilterAdaptor

        sourceModel: root.usersModel

        filter: getFilter().substring(
                    lastAtPosition + 1,
                    root.cursorPosition).replace(/\*/g, "")

        property int lastAtPosition: -1 // todo: rename to lastMentionAtPosition
        property int cursorPosition: root.cursorPosition

        function getFilter() {
            if (root.text.length === 0 ||
                    root.cursorPosition === 0)
                return ""

            return StatusQUtils.StringUtils.plainText(root.text)
        }

        function invalidateFilter() {
            const filter = getFilter()
            lastAtPosition = filter.substring(0, root.cursorPosition).lastIndexOf("@")
        }
    }

    StatusSyntaxHighlighter {
        quickTextDocument: root.textDocument
        codeBackgroundColor: Theme.palette.baseColor4
        codeForegroundColor: Theme.palette.textColor
        hyperlinks: root.urlsList
        hyperlinkColor: Theme.palette.primaryColor1
        highlightedHyperlink: root.urlToBeHighlighted
        hyperlinkHoverColor: Theme.palette.primaryColor3
    }
    StatusMouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: parent.hoveredLink
        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
}
