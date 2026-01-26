import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import shared
import shared.controls.chat
import shared.panels

import mainui

import AppLayouts.Chat.panels

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls as StatusQ


import AppLayouts.Chat.adaptors

import QtModelsToolkit

StatusQ.StatusTextArea {
    id: messageInputField

    property int messageLimit: 20
    property int messageLimitHard: 200

    property var urlsList: []

    property int previousCursorPosition: 0
    property KeyEvent lastKeyPressedEvent

    required property var usersModel
    readonly property alias suggestionsModel: suggestionsFilterAdaptor.model

    readonly property alias emojiFilter: _d.emojiFilter

    // to be removed later
    readonly property alias lastAtPosition: suggestionsFilterAdaptor.lastAtPosition

    textFormat: Text.RichText

    color: Theme.palette.textColor
    topPadding: 9
    bottomPadding: 9
    leftPadding: 0
    rightPadding: 0
    background: null

    inputMethodHints: Qt.ImhMultiLine | Qt.ImhNoEditMenu
    EnterKey.type: Qt.EnterKeyReturn // insert newlines hint for OSK

    Keys.onShortcutOverride: function (event) {
        event.accepted = event.matches(StandardKey.Paste)
    }
    Keys.onUpPressed: function(event) {
        if (isEdit && !activeFocus) {
            forceActiveFocus();
        } else {
            if (messageInputField.length === 0) {
                root.keyUpPress();
            }
        }
        event.accepted = false
    }
    Keys.onPressed: event => {
        lastKeyPressedEvent = event
        _d.onKeyPress(event)
    }
    Keys.onReleased: event => _d.onRelease(event) // gives much more up to date cursorPosition

    onCursorPositionChanged: {
        if(_d.mentionsPos.length > 0 && ((lastKeyPressedEvent.key === Qt.Key_Left) || (lastKeyPressedEvent.key === Qt.Key_Right)
          || (selectedText.length>0))) {
            const mention = _d.getMentionAtPosition(cursorPosition)
            if (mention) {
                const cursorMovingLeft = (cursorPosition < previousCursorPosition);
                const newCursorPosition = cursorMovingLeft ?
                                            mention.leftIndex :
                                            mention.rightIndex
                const isSelection = (selectedText.length>0);
                isSelection ? moveCursorSelection(newCursorPosition, TextEdit.SelectCharacters) :
                              cursorPosition = newCursorPosition
            }
        }

        previousCursorPosition = cursorPosition
    }

    onTextChanged: {
        if (length <= messageInputField.messageLimit) {
            if (length === 0) {
                _d.mentionsPos = [];
            } else {
                checkForInlineEmojis()
            }
        } else if (length > messageInputField.messageLimitHard) {
            const removeFrom = (cursorPosition < messageInputField.messageLimitHard) ? cursorWhenPressed : messageInputField.messageLimitHard;
            remove(removeFrom, cursorPosition);
            lengthLimitTooltip.open();
        }

        _d.updateMentionsPositions()
        _d.cleanMentionsPos()

        lengthLimitText.remainingChars = (messageInputField.messageLimit - length);
    }

    onLinkActivated: {
        const mention = _d.getMentionAtPosition(cursorPosition - 1)
        if(mention) {
            select(mention.leftIndex, mention.rightIndex)
        }
    }

    function insertMention(name: string, pubKey: string) {
        _d.insertMention(name, pubKey,
                         suggestionsFilterAdaptor.lastAtPosition,
                         suggestionsFilterAdaptor.cursorPosition)
    }

    function getTextWithPublicKeys() {
        let result = messageInputField.text

        if (_d.mentionsPos.length > 0) {
            for (let k = 0; k < _d.mentionsPos.length; k++) {
                const leftIndex = result.indexOf(_d.mentionsPos[k].name)
                const rightIndex = leftIndex + _d.mentionsPos[k].name.length
                result = result.substring(0, leftIndex)
                         + _d.mentionsPos[k].pubKey
                         + result.substring(rightIndex, result.length)
            }
        }

        return result
    }

    function replaceWithEmoji(shortname, codePoint, offset = 0) {
        _d.replaceWithEmoji(shortname, codePoint, offset)
    }

    function insertInTextInput(start, text) {
        // Replace new lines with entities because `insert` gets rid of them
        messageInputField.insert(start, text.replace(/\n/g, "<br/>"));
    }

    function wrapSelection(wrapWith) {
        if (messageInputField.selectionStart - messageInputField.selectionEnd === 0)
            return

        // calulate the new selection start and end positions
        const newSelectionStart = messageInputField.selectionStart + wrapWith.length
        const newSelectionEnd = messageInputField.selectionEnd
                              - messageInputField.selectionStart + newSelectionStart

        insertInTextInput(messageInputField.selectionStart, wrapWith);
        insertInTextInput(messageInputField.selectionEnd, wrapWith);

        messageInputField.select(newSelectionStart, newSelectionEnd)
    }

    function unwrapSelection(unwrapWith, selectedTextWithFormationChars) {
        if (messageInputField.selectionStart - messageInputField.selectionEnd === 0)
            return

        // Calculate the new selection start and end positions
        const newSelectionStart = messageInputField.selectionStart -  unwrapWith.length
        const newSelectionEnd = messageInputField.selectionEnd-messageInputField.selectionStart + newSelectionStart

        selectedTextWithFormationChars = selectedTextWithFormationChars.trim()
        // Check if the selectedTextWithFormationChars has formation chars and if so, calculate how many so we can adapt the start and end pos
        const selectTextDiff = (selectedTextWithFormationChars.length - messageInputField.selectedText.length) / 2

        // Remove the deselected option from the before and after the selected text
        const prefixChars = messageInputField.getText((messageInputField.selectionStart - selectTextDiff), messageInputField.selectionStart)
        const updatedPrefixChars = prefixChars.replace(unwrapWith, '')
        const postfixChars = messageInputField.getText(messageInputField.selectionEnd, (messageInputField.selectionEnd + selectTextDiff))
        const updatedPostfixChars = postfixChars.replace(unwrapWith, '')

        // Create updated selected string with pre and post formatting characters
        const updatedSelectedStringWithFormatChars = updatedPrefixChars + messageInputField.selectedText + updatedPostfixChars

        messageInputField.remove(messageInputField.selectionStart - selectTextDiff, messageInputField.selectionEnd + selectTextDiff)

        insertInTextInput(messageInputField.selectionStart, updatedSelectedStringWithFormatChars)

        messageInputField.select(newSelectionStart, newSelectionEnd)
    }

    function prefixSelectedLine(prefix) {
        const selectedLinePosition = _d.getLineStartPosition(messageInputField.selectionStart)
        messageInputField.insertInTextInput(selectedLinePosition, prefix)
    }

    function unprefixSelectedLine(prefix) {
        if (isSelectedLinePrefixedBy(messageInputField.selectionStart, prefix)) {
            const selectedLinePosition = _d.getLineStartPosition(messageInputField.selectionStart)
            messageInputField.remove(selectedLinePosition, selectedLinePosition + prefix.length)
        }
    }

    function isSelectedLinePrefixedBy(selectionStart, prefix) {
        const selectedLinePosition = _d.getLineStartPosition(selectionStart)
        const text = getPlainText()
        const selectedLine = text.substring(selectedLinePosition)
        return selectedLine.startsWith(prefix)
    }

    function getPlainText() {
        const textWithoutMention = messageInputField.text.replace(
                                     /<span style="[ :#0-9a-z;\-\.,\(\)]+">(@([a-z\.]+(\ ?[a-z]+\ ?[a-z]+)?))<\/span>/ig,
                                     "\[\[mention\]\]$1\[\[mention\]\]")
        const deparsedEmoji = StatusQUtils.Emoji.deparse(textWithoutMention);

        return StatusQUtils.StringUtils.plainText(deparsedEmoji)
    }

    QtObject {
        id: _d

        // Mentions
        property int leftOfMentionIndex: -1
        property int rightOfMentionIndex: -1

        property var mentionsPos: []
        property var copiedMentionsPos: []

        // Emojis
        property string emojiFilter: ""

        function onKeyPress(event) {
            // get text without HTML formatting
            const messageLength = messageInputField.length

            if (event.modifiers === d.kbdModifierToSendMessage &&
                    (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                tryFinalizeMessage()
                event.accepted = true
                return
            }

            const symbolPressed = event.text.length > 0 &&
                                event.key !== Qt.Key_Backspace &&
                                event.key !== Qt.Key_Delete &&
                                event.key !== Qt.Key_Escape
            if ((mentionsPos.length > 0) && symbolPressed && (messageInputField.selectedText.length === 0)) {
                for (var i = 0; i < mentionsPos.length; i++) {
                    if (messageInputField.cursorPosition === mentionsPos[i].leftIndex) {
                        _d.leftOfMentionIndex = i
                        event.accepted = true
                        return
                    } else if (messageInputField.cursorPosition === mentionsPos[i].rightIndex) {
                        _d.rightOfMentionIndex = i
                        event.accepted = true
                        return
                    }
                }
            }

            if (event.key === Qt.Key_Tab) {
                if (checkTextInsert()) {
                    event.accepted = true;
                    return
                }
            }

            // handle new line in blockquote
            if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && (event.modifiers & Qt.ShiftModifier)) {
                const message = _d.extrapolateCursorPosition()

                if(message.data.startsWith(">") && !message.data.endsWith("\n\n")) {
                    let newMessage1 = ""
                    if (message.data.endsWith("\n> ")) {
                        newMessage1 = message.data.substr(0, message.data.lastIndexOf("> ")) + "\n\n"
                    } else {
                        newMessage1 = message.data + "\n> ";
                    }
                    messageInputField.remove(0, messageInputField.cursorPosition)
                    insertInTextInput(0, StatusQUtils.Emoji.parse(newMessage1))
                    event.accepted = true
                }
            }

            if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                const message = _d.extrapolateCursorPosition()
                if(mentionsPos.length > 0) {
                    let anticipatedCursorPosition = messageInputField.cursorPosition
                    anticipatedCursorPosition += event.key === Qt.Key_Backspace ?
                                                   -1 : 1

                    const mention = _d.getMentionAtPosition(anticipatedCursorPosition)
                    if(mention) {
                        _d.removeMention(mention)
                        event.accepted = true
                    }
                }

                // handle backspace when entering an existing blockquote
                if(message.data.startsWith(">") && message.data.endsWith("\n\n")) {
                    const newMessage = message.data.substr(0, message.data.lastIndexOf("\n")) + "> ";
                    messageInputField.remove(0, messageInputField.cursorPosition);
                    insertInTextInput(0, StatusQUtils.Emoji.parse(newMessage));
                    event.accepted = true
                }
            }

            if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) {
                if (messageInputField.selectedText !== "") {
                    d.copiedTextPlain = messageInputField.getText(
                                messageInputField.selectionStart, messageInputField.selectionEnd)
                    d.copiedTextFormatted = messageInputField.getFormattedText(
                                messageInputField.selectionStart, messageInputField.selectionEnd)
                    _d.copyMentions(messageInputField.selectionStart, messageInputField.selectionEnd)
                }
            } else if (event.matches(StandardKey.Paste)) {
                if (ClipboardUtils.hasImage) {
                    const clipboardImage = ClipboardUtils.imageBase64
                    validateImagesAndShowImageArea([clipboardImage])
                    event.accepted = true
                } else if (ClipboardUtils.hasText) {
                    const clipboardText = StatusQUtils.StringUtils.plainText(ClipboardUtils.text)
                    // prevent repetitive & huge clipboard paste, where huge is total char count > than messageLimitHard
                    const selectionLength = messageInputField.selectionEnd - messageInputField.selectionStart;
                    if ((messageLength + clipboardText.length - selectionLength) > root.messageLimitHard)
                    {
                        lengthLimitTooltip.open();
                        event.accepted = true;
                        return;
                    }

                    messageInputField.remove(messageInputField.selectionStart, messageInputField.selectionEnd)

                    // cursor position must be stored in a helper property because setting readonly to true causes change
                    // of the cursor position to the end of the input
                    d.copyTextStart = messageInputField.cursorPosition
                    messageInputField.readOnly = true

                    const copiedText = StatusQUtils.StringUtils.plainText(d.copiedTextPlain)
                    if (copiedText === clipboardText) {
                        if (d.copiedTextPlain.includes("@")) {
                            d.copiedTextFormatted = d.copiedTextFormatted.replace(/span style="/g, "span style=\" text-decoration:none;")

                            let lastFoundIndex = -1
                            for (let j = 0; j < _d.copiedMentionsPos.length; j++) {
                                const name = _d.copiedMentionsPos[j].name
                                const indexOfName = d.copiedTextPlain.indexOf(name, lastFoundIndex)
                                lastFoundIndex += name.length

                                if (indexOfName === _d.copiedMentionsPos[j].leftIndex + 1) {
                                    const mention = {
                                        name: name,
                                        pubKey: _d.copiedMentionsPos[j].pubKey,
                                        leftIndex: (_d.copiedMentionsPos[j].leftIndex + d.copyTextStart - 1),
                                        rightIndex: (_d.copiedMentionsPos[j].leftIndex + d.copyTextStart + name.length)
                                    }
                                    mentionsPos.push(mention)
                                    _d.sortMentions()
                                }
                            }
                        }
                        insertInTextInput(d.copyTextStart, d.copiedTextFormatted)
                    } else {
                        d.copiedTextPlain = ""
                        d.copiedTextFormatted = ""
                        _d.copiedMentionsPos = []
                        messageInputField.insert(d.copyTextStart, ((d.nbEmojisInClipboard === 0) ?
                        ("<div style='white-space: pre-wrap'>" + StatusQUtils.StringUtils.escapeHtml(ClipboardUtils.text) + "</div>")
                        : StatusQUtils.Emoji.deparse(ClipboardUtils.html)));
                    }

                    // Reset readOnly immediately after paste completes
                    // Don't wait for onRelease which might not fire on mobile
                    if (StatusQUtils.Utils.isMobile) {
                        messageInputField.readOnly = false
                        messageInputField.cursorPosition = (d.copyTextStart + ClipboardUtils.text.length + d.nbEmojisInClipboard)
                    }
                    event.accepted = true
                }
            }
        }

        function onRelease(event) {
            if ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.MetaModifier)) // these are likely shortcuts with no meaningful text
                return

            if ((event.key === Qt.Key_Shift))
                return

            // the text doesn't get registered to the textarea fast enough
            // we can only get it in the `released` event

            let eventText = event.text
            if(event.key === Qt.Key_Space) {
                eventText = "&nbsp;"
            }

            if(_d.rightOfMentionIndex !== -1) {
                //make sure to add an extra space between mention and text
                let mentionSeparator = event.key === Qt.Key_Space ? "" : "&nbsp;"
                messageInputField.insert(mentionsPos[_d.rightOfMentionIndex].rightIndex, mentionSeparator + eventText)

                _d.rightOfMentionIndex = -1
            }

            if(_d.leftOfMentionIndex !== -1) {
                messageInputField.insert(mentionsPos[_d.leftOfMentionIndex].leftIndex, eventText)

                _d.leftOfMentionIndex = -1
            }

            if (event.key !== Qt.Key_Escape)
                 _d.emojiHandler(event)

            if (messageInputField.readOnly) {
                messageInputField.readOnly = false;
                messageInputField.cursorPosition = (d.copyTextStart + ClipboardUtils.text.length + d.nbEmojisInClipboard);
            }

            if (suggestionsBox.visible) {
                const namePrefix = suggestionsFilterAdaptor.filter
                const lastCursorPosition = messageInputField.cursorPosition
                const lastAtPosition = suggestionsFilterAdaptor.lastAtPosition

                const suggestionItem = StatusQUtils.ModelUtils.get(
                        suggestionsFilterAdaptor.model,
                        suggestionsBox.listView.currentIndex)

                const namePrefixLowerCase = namePrefix.toLowerCase()
                const fullName = suggestionItem.preferredDisplayName
                const fullNameLowerCase = fullName.toLowerCase()

                if (namePrefix !== "" && namePrefixLowerCase === fullNameLowerCase
                        && event.key !== Qt.Key_Backspace
                        && event.key !== Qt.Key_Delete
                        && event.key !== Qt.Key_Left) {
                    _d.insertMention(fullName, suggestionItem.pubKey,
                                    lastAtPosition, lastCursorPosition)
                }
            }
        }

        function updateMentionsPositions() {
            if (mentionsPos.length == 0) {
                return
            }

            const unformattedText = messageInputField.getText(0, messageInputField.length)
            if (!unformattedText.includes("@")) {
                return
            }

            const keyEvent = messageInputField.lastKeyPressedEvent
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

            _d.sortMentions()
        }

        function insertMention(aliasName, publicKey, lastAtPosition, lastCursorPosition) {
            const hasEmoji = StatusQUtils.Emoji.hasEmoji(messageInputField.text)
            const spanPlusAlias = `${d.mentionTagStart}@${aliasName}${d.mentionTagEnd} `;

            let rightIndex = hasEmoji ? lastCursorPosition + 2 : lastCursorPosition
            messageInputField.remove(lastAtPosition, rightIndex)
            messageInputField.insert(lastAtPosition, spanPlusAlias)
            messageInputField.cursorPosition = lastAtPosition + aliasName.length + 2;
            if (messageInputField.cursorPosition === 0) {
                // It reset to 0 for some reason, go back to the end
                messageInputField.cursorPosition = messageInputField.length
            }

            mentionsPos = mentionsPos.filter(mention => mention.leftIndex !== lastAtPosition)
            mentionsPos.push({name: aliasName, pubKey: publicKey, leftIndex: lastAtPosition, rightIndex: (lastAtPosition+aliasName.length + 1)});
            _d.sortMentions()
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

            const unformattedText = messageInputField.getText(0, messageInputField.length)
            mentionsPos = mentionsPos.filter(mention => unformattedText.charAt(mention.leftIndex) === "@")
        }

        function removeMention(mention) {
            const index = mentionsPos.indexOf(mention)
            if(index >= 0) {
                mentionsPos.splice(index, 1)
            }

            messageInputField.remove(mention.leftIndex, mention.rightIndex)
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
                // popup
                const index2 = message.data.lastIndexOf(':', message.cursor - 1);
                if (index2 >= 0 && message.cursor > 0) {
                    _d.emojiFilter = message.data.substr(index2, message.cursor)
                    return
                }
            }

            _d.emojiFilter = ""
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
            messageInputField.remove(messageInputField.cursorPosition - shortname.length - offset,
                                     messageInputField.cursorPosition);
            insertInTextInput(messageInputField.cursorPosition,
                              StatusQUtils.Emoji.parse(encodedCodePoint) + " ");
            _d.emojiFilter = ""
        }

        // since emoji length is not 1 we need to match that position that TextArea returns
        // to the actual position in the string.
        function extrapolateCursorPosition() {
            // we need only the message part to be html
            const text = getPlainText()
            const completelyPlainText = _d.removeMentions(text)
            const plainText = StatusQUtils.Emoji.parse(text)

            let bracketEvent = false
            let almostMention = false
            let mentionEvent = false
            let length = 0

            // This loop calculates the cursor position inside the plain text which contains the image tags (<img>) and the mention tags ([[mention]])
            const cursorPos = messageInputField.cursorPosition
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
                            messageInputField.cursorPosition +
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
            const lastNewLinePos = text.lastIndexOf("\n", messageInputField.selectionStart)
            return lastNewLinePos === -1 ? 0 : lastNewLinePos + 1
        }

        function removeMentions(currentText) {
            return currentText.replace(/\[\[mention\]\]/g, '')
        }
    }

    SuggestionsFilterAdaptor {
        id: suggestionsFilterAdaptor

        sourceModel: messageInputField.usersModel

        filter: getFilter().substring(
                    lastAtPosition + 1,
                    messageInputField.cursorPosition).replace(/\*/g, "")

        property int lastAtPosition: -1 // todo: rename to lastMentionAtPosition
        property int cursorPosition: messageInputField.cursorPosition

        function getFilter() {
            if (messageInputField.text.length === 0 ||
                    messageInputField.cursorPosition === 0)
                return ""

            return StatusQUtils.StringUtils.plainText(messageInputField.text)
        }


        function invalidateFilter() {
            const filter = getFilter()
            lastAtPosition = filter.substring(0, messageInputField.cursorPosition).lastIndexOf("@")
        }

        function selectItem(item: var, lastAtPosition: int, lastCursorPosition: int) {
            messageInputField.forceActiveFocus()
            d.insertMention(item.preferredDisplayName, item.pubKey,
                            lastAtPosition, lastCursorPosition)
        }

        Connections {
            target: messageInputField

            function onTextChanged() {
                suggestionsFilterAdaptor.invalidateFilter()
            }
        }
    }

    StatusSyntaxHighlighter {
        quickTextDocument: messageInputField.textDocument
        codeBackgroundColor: Theme.palette.baseColor4
        codeForegroundColor: Theme.palette.textColor
        hyperlinks: messageInputField.urlsList
        hyperlinkColor: Theme.palette.primaryColor1
        highlightedHyperlink: linkPreviewArea.hoveredUrl
        hyperlinkHoverColor: Theme.palette.primaryColor3
    }
    StatusMouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: parent.hoveredLink
        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
}
