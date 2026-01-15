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

import QtModelsToolkit

Rectangle {
    id: control
    objectName: "statusChatInput"

    signal stickerSelected(string hashId, string packId, string url)
    signal sendMessage(var event)
    signal keyUpPress()
    signal linkPreviewReloaded(string link)
    signal enableLinkPreview()
    signal enableLinkPreviewForThisMessage()
    signal disableLinkPreview()
    signal dismissLinkPreviewSettings()
    signal dismissLinkPreview(int index)
    signal openPaymentRequestModal()
    signal removePaymentRequestPreview(int index)
    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)
    
    property var usersModel

    property var emojiPopup: null
    property var stickersPopup: null
    // Use this to only enable the Connections only when this Input opens the Emoji popup
    property bool closeGifPopupAfterSelection: true
    property bool areTestNetworksEnabled
    property bool paymentRequestFeatureEnabled: false

    property bool emojiEvent: false
    property bool isColonPressed: false
    property bool isReply: false
    readonly property string replyMessageId: replyArea.messageId

    property bool isImage: false
    property bool isEdit: false

    readonly property int messageLimit: 2000 // actual message limit, we don't allow sending more than that
    readonly property int messageLimitSoft: 200 // we start showing a char counter when this no. of chars left in the message
    readonly property int messageLimitHard: 20000 // still cut-off attempts to paste beyond this limit, for app usability reasons

    property int chatType

    property string chatInputPlaceholder: qsTr("Message")

    property alias textInput: messageInputField

    property var fileUrlsAndSources: []

    property var linkPreviewModel: null
    property var paymentRequestModel: null

    property var formatBalance: null

    property var urlsList: []

    property bool askToEnableLinkPreview: false

    property int imageErrorMessageLocation: StatusChatInput.ImageErrorMessageLocation.Top // TODO: Remove this property?

    enum ImageErrorMessageLocation {
        Top,
        Bottom
    }

    function parseMessage(message: string) {
        let mentionsMap = new Map()
        let index = 0
        while (true) {
            index = message.indexOf("<a href=", index)
            if (index < 0) {
                break
            }
            const startIndex = index
            const endIndex = message.indexOf("</a>", index) + 4
            if (endIndex < 0) {
                index += 8 // "<a href="
                continue
            }
            const addrIndex = message.indexOf("0x", index + 8)
            if (addrIndex < 0) {
                index += 8 // "<a href="
                continue
            }
            const addrEndIndex = message.indexOf("\"", addrIndex)
            if (addrEndIndex < 0) {
                index += 8 // "<a href="
                continue
            }
            const mentionLink = message.substring(startIndex, endIndex)
            const linkTag = message.substring(index, endIndex)
            const linkText = linkTag.replace(/(<([^>]+)>)/ig,"").trim()
            const atSymbol = linkText.startsWith("@") ? '' : '@'
            const mentionTag = d.mentionSpanTag + atSymbol + linkText + '</span> '
            mentionsMap.set(mentionLink, mentionTag)
            index += linkTag.length
        }

        let text = message;

        for (let [key, value] of mentionsMap)
            text = text.replace(new RegExp(key, 'g'), value)

        textInput.text = text
        textInput.cursorPosition = textInput.length
    }

    function setText(text) {
        textInput.clear()
        textInput.append(text)
    }

    function clear() {
        textInput.clear()
    }

    implicitWidth: layout.implicitWidth + layout.anchors.leftMargin + layout.anchors.rightMargin
    implicitHeight: layout.implicitHeight + layout.anchors.topMargin + layout.anchors.bottomMargin

    color: StatusColors.transparent

    QtObject {
        id: d
        readonly property string emojiReplacementSymbols: ":='xX><0O;*dB8-D#%\\"

        //mentions helper properties
        property string copiedTextPlain: ""
        property string copiedTextFormatted: ""
        property var copiedMentionsPos: []
        property int copyTextStart: 0

        property int leftOfMentionIndex: -1
        property int rightOfMentionIndex: -1
        readonly property int nbEmojisInClipboard: StatusQUtils.Emoji.nbEmojis(ClipboardUtils.html)

        property bool emojiPopupOpened: false
        property bool stickersPopupOpened: false

        property var imageDialog: null

        // whether to send message using Ctrl+Return or just Enter; based on OSK (virtual keyboard presence)
        readonly property int kbdModifierToSendMessage: Qt.inputMethod.visible ? Qt.ControlModifier : Qt.NoModifier

        // common popups are emoji, jif and stickers
        // Put controlWidth as argument with default value for binding
        function getCommonPopupRelativePosition(popup, popupParent, controlWidth = control.width) {
            const popupWidth = popup ? popup.width : 0
            const popupHeight = popup ? popup.height : 0
            const controlX = controlWidth - popupWidth - Theme.halfPadding
            const controlY = -popupHeight
            return popupParent.mapFromItem(control, controlX, controlY)
        }

        readonly property point emojiPopupPosition: getCommonPopupRelativePosition(emojiPopup, emojiBtn)
        readonly property point stickersPopupPosition: getCommonPopupRelativePosition(stickersPopup, stickersBtn)

        readonly property string mentionSpanTag: `<span style="background-color: ${root.Theme.palette.mentionColor2};"><a style="color:${root.Theme.palette.mentionColor1};text-decoration:none" href='http://'>`

        readonly property StateGroup emojiPopupTakeover: StateGroup {
            states: State {
                when: d.emojiPopupOpened

                PropertyChanges {
                    target: emojiPopup

                    directParent: emojiBtn
                    relativeX: d.emojiPopupPosition.x
                    relativeY: d.emojiPopupPosition.y
                }
            }
        }
        readonly property StateGroup stickersPopupTakeover: StateGroup {
            states: State {
                when: d.stickersPopupOpened

                PropertyChanges {
                    target: stickersPopup

                    directParent: stickersBtn
                    relativeX: d.stickersPopupPosition.x
                    relativeY: d.stickersPopupPosition.y
                }
            }
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

        function sortMentions() {
            if (mentionsPos.length < 2) {
                return
            }
            mentionsPos = mentionsPos.sort(function(a, b){
                return a.leftIndex - b.leftIndex
            })
        }

        function updateMentionsPositions() {
            if (mentionsPos.length == 0) {
                return
            }

            const unformattedText = messageInputField.getText(0, messageInputField.length)
            if (!unformattedText.includes("@")) {
                return
            }

            const keyEvent = messageInputField.keyEvent
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

            sortMentions()
        }

        function cleanMentionsPos() {
            if(mentionsPos.length == 0) return

            const unformattedText = messageInputField.getText(0, messageInputField.length)
            mentionsPos = mentionsPos.filter(mention => unformattedText.charAt(mention.leftIndex) === "@")
        }

        function insertMention(aliasName, publicKey, lastAtPosition, lastCursorPosition) {
            let startInd = aliasName.indexOf("(");
            if (startInd > 0){
                aliasName = aliasName.substring(0, startInd-1)
            }

            const hasEmoji = StatusQUtils.Emoji.hasEmoji(messageInputField.text)
            const spanPlusAlias = `${d.mentionSpanTag}@${aliasName}</a></span> `;

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
            d.sortMentions()
        }

        function removeMention(mention) {
            const index = mentionsPos.indexOf(mention)
            if(index >= 0) {
                mentionsPos.splice(index, 1)
            }

            messageInputField.remove(mention.leftIndex, mention.rightIndex)
        }

        function getMentionAtPosition(position: int) {
            return mentionsPos.find(mention => mention.leftIndex < position && mention.rightIndex > position)
        }

        function getSelectedTextWithFormationChars(messageInputField) {
            const formationChars = ["*", "`", "~", "_"]
            let i = 1
            let text = ""
            while (true) {
                if (messageInputField.selectionStart - i < 0 && messageInputField.selectionEnd + i > messageInputField.length) {
                    break
                }

                text = messageInputField.getText(messageInputField.selectionStart - i, messageInputField.selectionEnd + i)

                if (!formationChars.includes(text.charAt(0)) ||
                        !formationChars.includes(text.charAt(text.length - 1))) {
                    break
                }
                i++
            }
            return text
        }
    }

    function insertInTextInput(start, text) {
        // Replace new lines with entities because `insert` gets rid of them
        messageInputField.insert(start, text.replace(/\n/g, "<br/>"));
    }

    Connections {
        enabled: d.emojiPopupOpened
        target: emojiPopup

        function onEmojiSelected(text: string, atCursor: bool) {
            // commit any potential preedit text first
            InputMethod.commit()

            insertInTextInput(atCursor ? messageInputField.cursorPosition : messageInputField.length, text)
            emojiBtn.highlighted = false
            messageInputField.forceActiveFocus();
        }
        function onClosed() {
            d.emojiPopupOpened = false
        }
    }

    Connections {
        enabled: d.stickersPopupOpened
        target: control.stickersPopup

        function onStickerSelected(hashId: string, packId: string, url: string ) {
            control.stickerSelected(hashId, packId, url)
            control.hideExtendedArea();
            messageInputField.forceActiveFocus();
        }
        function onClosed() {
            d.stickersPopupOpened = false
        }
    }

    property var mentionsPos: []

    function isUploadFilePressed(event) {
        return (event.key === Qt.Key_U) && (event.modifiers & Qt.ControlModifier) && !d.imageDialog
    }

    function checkTextInsert() {
        if (emojiSuggestions.visible) {
            replaceWithEmoji(extrapolateCursorPosition(), emojiSuggestions.shortname, emojiSuggestions.unicode);
            return true
        }
        if (suggestionsBox.visible) {
            suggestionsBox.selectCurrentItem();
            return true
        }
        return false
    }

    function onKeyPress(event) {
        // get text without HTML formatting
        const messageLength = messageInputField.length

        if (event.modifiers === d.kbdModifierToSendMessage && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
            if (checkTextInsert()) {
                event.accepted = true;
                return
            }
            if (messageLength <= messageLimit) {
                checkForInlineEmojis(true);
                control.sendMessage(event);
                control.hideExtendedArea();
                event.accepted = true;
                return;
            } else {
                // pop-up a warning message when trying to send a message over the limit
                messageLengthLimitTooltip.open();
                event.accepted = true;
                return;
            }
        }

        if (event.key === Qt.Key_Escape && control.isReply) {
            control.isReply = false;
            event.accepted = true;
            return;
        }

        const symbolPressed = event.text.length > 0 &&
                            event.key !== Qt.Key_Backspace &&
                            event.key !== Qt.Key_Delete &&
                            event.key !== Qt.Key_Escape
        if ((mentionsPos.length > 0) && symbolPressed && (messageInputField.selectedText.length === 0)) {
            for (var i = 0; i < mentionsPos.length; i++) {
                if (messageInputField.cursorPosition === mentionsPos[i].leftIndex) {
                    d.leftOfMentionIndex = i
                    event.accepted = true
                    return
                } else if (messageInputField.cursorPosition === mentionsPos[i].rightIndex) {
                    d.rightOfMentionIndex = i
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
            const message = control.extrapolateCursorPosition();

            if(message.data.startsWith(">") && !message.data.endsWith("\n\n")) {
                let newMessage1 = ""
                if (message.data.endsWith("\n> ")) {
                    newMessage1 = message.data.substr(0, message.data.lastIndexOf("> ")) + "\n\n"
                } else {
                    newMessage1 = message.data + "\n> ";
                }
                messageInputField.remove(0, messageInputField.cursorPosition);
                insertInTextInput(0, StatusQUtils.Emoji.parse(newMessage1));
                event.accepted = true
            }
        }

        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            const message = control.extrapolateCursorPosition();
            if(mentionsPos.length > 0) {
                let anticipatedCursorPosition = messageInputField.cursorPosition
                anticipatedCursorPosition += event.key === Qt.Key_Backspace ?
                                               -1 : 1

                const mention = d.getMentionAtPosition(anticipatedCursorPosition)
                if(mention) {
                    d.removeMention(mention)
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
                d.copyMentions(messageInputField.selectionStart, messageInputField.selectionEnd)
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
                if ((messageLength + clipboardText.length - selectionLength) > control.messageLimitHard)
                {
                    messageLengthLimitTooltip.open();
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
                                mentionsPos.push(mention)
                                d.sortMentions()
                            }
                        }
                    }
                    insertInTextInput(d.copyTextStart, d.copiedTextFormatted)
                } else {
                    d.copiedTextPlain = ""
                    d.copiedTextFormatted = ""
                    d.copiedMentionsPos = []
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

        // ⌘⇧U
        if (isUploadFilePressed(event)) {
            openImageDialog()
            event.accepted = true
        }

        if (event.key === Qt.Key_Down && emojiSuggestions.visible) {
            event.accepted = true
            return emojiSuggestions.listView.incrementCurrentIndex()
        }
        if (event.key === Qt.Key_Up && emojiSuggestions.visible) {
            event.accepted = true
            return emojiSuggestions.listView.decrementCurrentIndex()
        }

        isColonPressed = event.key === Qt.Key_Colon;
    }

    function getLineStartPosition(selectionStart) {
        const text = getPlainText()
        const lastNewLinePos = text.lastIndexOf("\n\n", messageInputField.selectionStart)
        return lastNewLinePos === -1 ? 0 : lastNewLinePos + 2
    }

    function prefixSelectedLine(prefix) {
        const selectedLinePosition = getLineStartPosition(messageInputField.selectionStart)
        insertInTextInput(selectedLinePosition, prefix)
    }

    function unprefixSelectedLine(prefix) {
        if( isSelectedLinePrefixedBy(messageInputField.selectionStart, prefix) ) {
            const selectedLinePosition = getLineStartPosition(messageInputField.selectionStart)
            messageInputField.remove(selectedLinePosition, selectedLinePosition + prefix.length)
        }
    }

    function isSelectedLinePrefixedBy(selectionStart, prefix) {
        const selectedLinePosition = getLineStartPosition(selectionStart)
        const text = getPlainText()
        const selectedLine = text.substring(selectedLinePosition)
        return selectedLine.startsWith(prefix)
    }

    function wrapSelection(wrapWith) {
        if (messageInputField.selectionStart - messageInputField.selectionEnd === 0) return

        // calulate the new selection start and end positions
        var newSelectionStart = messageInputField.selectionStart + wrapWith.length
        var newSelectionEnd = messageInputField.selectionEnd - messageInputField.selectionStart + newSelectionStart

        insertInTextInput(messageInputField.selectionStart, wrapWith);
        insertInTextInput(messageInputField.selectionEnd, wrapWith);

        messageInputField.select(newSelectionStart, newSelectionEnd)
    }

    function unwrapSelection(unwrapWith, selectedTextWithFormationChars) {
        if (messageInputField.selectionStart - messageInputField.selectionEnd === 0) return

        // Calculate the new selection start and end positions
        var newSelectionStart = messageInputField.selectionStart -  unwrapWith.length
        var newSelectionEnd = messageInputField.selectionEnd-messageInputField.selectionStart + newSelectionStart

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

    function getPlainText() {
        const textWithoutMention = messageInputField.text.replace(/<span style="[ :#0-9a-z;\-\.,\(\)]+">(@([a-z\.]+(\ ?[a-z]+\ ?[a-z]+)?))<\/span>/ig, "\[\[mention\]\]$1\[\[mention\]\]")

        const deparsedEmoji = StatusQUtils.Emoji.deparse(textWithoutMention);

        return StatusQUtils.StringUtils.plainText(deparsedEmoji)
    }

    function removeMentions(currentText) {
        return currentText.replace(/\[\[mention\]\]/g, '')
    }

    function parseMarkdown(markdownText) {
        const htmlText = markdownText
        .replace(/\~\~([^*]+)\~\~/gim, '~~<span style="text-decoration: line-through">$1</span>~~')
        .replace(/\*\*([^*]+)\*\*/gim, ':asterisk::asterisk:<b>$1</b>:asterisk::asterisk:')
        .replace(/\`([^*]+)\`/gim, '`<code>$1</code>`')
        .replace(/\*([^*]+)\*/gim, ':asterisk:<i>$1</i>:asterisk:')
        return htmlText.replace(/\:asterisk\:/gim, "*")
    }

    function getFormattedText(start, end) {
        start = start || 0
        end = end || messageInputField.length

        const oldFormattedText = messageInputField.getFormattedText(start, end)

        const found = oldFormattedText.match(/<!--StartFragment-->([\w\W\s]*)<!--EndFragment-->/m);

        return found[1]
    }

    function getTextWithPublicKeys() {
        let result = messageInputField.text

        if (mentionsPos.length > 0) {
            for (var k = 0; k < mentionsPos.length; k++) {
                let leftIndex = result.indexOf(mentionsPos[k].name)
                let rightIndex = leftIndex + mentionsPos[k].name.length
                result = result.substring(0, leftIndex)
                         + mentionsPos[k].pubKey
                         + result.substring(rightIndex, result.length)
            }
        }

        return result
    }

    function onRelease(event) {
        if ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.MetaModifier)) // these are likely shortcuts with no meaningful text
            return

        // the text doesn't get registered to the textarea fast enough
        // we can only get it in the `released` event

        let eventText = event.text
        if(event.key === Qt.Key_Space) {
            eventText = "&nbsp;"
        }

        if(d.rightOfMentionIndex !== -1) {
            //make sure to add an extra space between mention and text
            let mentionSeparator = event.key === Qt.Key_Space ? "" : "&nbsp;"
            messageInputField.insert(mentionsPos[d.rightOfMentionIndex].rightIndex, mentionSeparator + eventText)

            d.rightOfMentionIndex = -1
        }

        if(d.leftOfMentionIndex !== -1) {
            messageInputField.insert(mentionsPos[d.leftOfMentionIndex].leftIndex, eventText)

            d.leftOfMentionIndex = -1
        }

        if (event.key !== Qt.Key_Escape) {
            emojiEvent = emojiHandler(event)
            if (!emojiEvent) {
                emojiSuggestions.close()
            }
        }

        if (messageInputField.readOnly) {
            messageInputField.readOnly = false;
            messageInputField.cursorPosition = (d.copyTextStart + ClipboardUtils.text.length + d.nbEmojisInClipboard);
        }


        if (suggestionsBox.visible) {
            let aliasName = suggestionsBox.formattedPlainTextFilter;
            let lastCursorPosition = suggestionsBox.suggestionFilter.cursorPosition;
            let lastAtPosition = suggestionsBox.suggestionFilter.lastAtPosition;
            let suggestionItem = suggestionsBox.listView.itemAtIndex(suggestionsBox.listView.currentIndex);

            if (aliasName !== "" && aliasName.toLowerCase() === suggestionItem.preferredDisplayName.toLowerCase()
                    && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete && event.key !== Qt.Key_Left) {
                d.insertMention(aliasName, suggestionItem.pubKey, lastAtPosition, lastCursorPosition);
            } else if (event.key === Qt.Key_Space) {
                var plainTextToReplace = messageInputField.getText(lastAtPosition, lastCursorPosition);
                messageInputField.remove(lastAtPosition, lastCursorPosition);
                messageInputField.insert(lastAtPosition, plainTextToReplace);
                suggestionsBox.hide();
            }
        }
    }

    // since emoji length is not 1 we need to match that position that TextArea returns
    // to the actual position in the string.
    function extrapolateCursorPosition() {
        // we need only the message part to be html
        const text = getPlainText()
        const completelyPlainText = removeMentions(text)
        const plainText = StatusQUtils.Emoji.parse(text);

        var bracketEvent = false;
        var almostMention = false;
        var mentionEvent = false;
        var length = 0;

        // This loop calculates the cursor position inside the plain text which contains the image tags (<img>) and the mention tags ([[mention]])
        const cursorPos = messageInputField.cursorPosition
        let character = ""
        for (var i = 0; i < plainText.length; i++) {
            if (length >= cursorPos) break;

            character = plainText.charAt(i)
            if (!bracketEvent && character !== '<' && !mentionEvent && character !== '[')  {
                length++;
            } else if (!bracketEvent && character === '<') {
                bracketEvent = true;
            } else if (bracketEvent && character === '>') {
                bracketEvent = false;
                length++;
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

        let textBeforeCursor = StatusQUtils.Emoji.deparse(plainText.substr(0, i));

        return {
            cursor: countEmojiLengths(plainText.substr(0, i)) + messageInputField.cursorPosition + text.length - completelyPlainText.length,
            data: textBeforeCursor,
        };
    }

    function emojiHandler(event) {
        let message = extrapolateCursorPosition();
        pollEmojiEvent(message);

        // state machine to handle different forms of the emoji event state
        if (!emojiEvent && isColonPressed) {
            return (message.data.length <= 1 || Utils.isSpace(message.data.charAt(message.cursor - 1))) ? true : false;
        } else if (emojiEvent && isColonPressed) {
            const index = message.data.lastIndexOf(':', message.cursor - 2);
            if (index >= 0 && message.cursor > 0) {
                const shortname = message.data.substr(index, message.cursor);
                const codePoint = StatusQUtils.Emoji.getEmojiUnicode(shortname);
                if (codePoint !== undefined) {
                    replaceWithEmoji(message, shortname, codePoint);
                }
                return false;
            }
            return true;
        } else if (emojiEvent && isKeyValid(event.key) && !isColonPressed) {
            // popup
            const index2 = message.data.lastIndexOf(':', message.cursor - 1);
            if (index2 >= 0 && message.cursor > 0) {
                const emojiPart = message.data.substr(index2, message.cursor);
                if (emojiPart.length > 2) {
                    const emojis = StatusQUtils.Emoji.emojiJSON.emoji_json.filter(function (emoji) {
                        return emoji.name.includes(emojiPart) ||
                                emoji.shortname.includes(emojiPart) ||
                                emoji.aliases.some(a => a.includes(emojiPart)) ||
                                emoji.keywords.some(k => k.includes(emojiPart))
                    })

                    emojiSuggestions.openPopup(emojis, emojiPart)
                }
                return true;
            }
        } else if (emojiEvent && !isKeyValid(event.key) && !isColonPressed) {
            return false;
        }
        return false;
    }

    function countEmojiLengths(value) {
        const match = StatusQUtils.Emoji.getEmojis(value);
        var length = 0;

        if (match && match.length > 0) {
            for (var i = 0; i < match.length; i++) {
                length += StatusQUtils.Emoji.deparse(match[i]).length;
            }
            length = length - match.length;
        }
        return length;
    }

    function checkForInlineEmojis(force = false) {
         // trigger inline emoji replacements after space, or always (force==true) when sending the message
        if (force || messageInputField.getText(messageInputField.cursorPosition, messageInputField.cursorPosition - 1) === " ") {
            // figure out last word (between spaces), max length of 5
            var lastWord = ""
            const cursorPos = messageInputField.cursorPosition - (force ? 1 : 2) // just before the last non-space character
            for (let i = cursorPos; i > cursorPos - 6; i--) { // go back until we found a space or start of line
                const lastChar = messageInputField.getText(i, i+1)
                if (i < 0 || lastChar === " ") { // reached start of line or a space
                    break
                } else {
                    lastWord = lastChar + lastWord // collect the last word
                }
            }

            // check if the word contains any of the trigger chars (emojiReplacementSymbols)
            if (!!lastWord && Array.prototype.some.call(d.emojiReplacementSymbols, (trigger) => lastWord.includes(trigger))) {
                // search the ASCII aliases for a possible match
                const emojiFound = StatusQUtils.Emoji.emojiJSON.emoji_json.find(emoji => emoji.aliases_ascii.includes(lastWord))
                if (emojiFound) {
                    replaceWithEmoji("", lastWord, emojiFound.unicode, force ? 0 : 1 /*offset*/);
                }
            }
        }
    }

    function replaceWithEmoji(message, shortname, codePoint, offset = 0) {
        const encodedCodePoint = StatusQUtils.Emoji.getEmojiCodepoint(codePoint)
        messageInputField.remove(messageInputField.cursorPosition - shortname.length - offset, messageInputField.cursorPosition);
        insertInTextInput(messageInputField.cursorPosition, StatusQUtils.Emoji.parse(encodedCodePoint) + " ");
        emojiSuggestions.close()
        emojiEvent = false
    }

    // check if user has placed cursor near valid emoji colon token
    function pollEmojiEvent(message) {
        const index = message.data.lastIndexOf(':', message.cursor);
        if (index >= 0) {
            emojiEvent = validSubstr(message.data.substr(index, message.cursor - index));
        }
    }

    function validSubstr(substr) {
        for(var i = 0; i < substr.length; i++) {
            var c = substr.charAt(i);
            if (Utils.isSpace(c) || Utils.isPunct(c))
                return false;
        }
        return true;
    }

    function isKeyValid(key) {
        if (key === Qt.Key_Space || key ===  Qt.Key_Tab ||
                (key >= Qt.Key_Exclam && key <= Qt.Key_Slash) ||
                (key >= Qt.Key_Semicolon && key <= Qt.Key_Question) ||
                (key >= Qt.Key_BracketLeft && key <= Qt.Key_hyphen))
            return false;
        return true;
    }

    function resetImageArea() {
        isImage = false;
        control.fileUrlsAndSources = []
        for (let i=0; i<validators.children.length; i++) {
            const validator = validators.children[i]
            validator.images = []
        }
    }

    function resetReplyArea() {
        isReply = false
        replyArea.messageId = ""
    }

    function hideExtendedArea() {
        resetImageArea()
        resetReplyArea()
    }

    function validateImages(imagePaths = []) {
        // needed because control.fileUrlsAndSources is not a normal js array
        const existing = (control.fileUrlsAndSources || []).map(x => x.toString())
        let validImages = Utils.deduplicate(existing.concat(imagePaths))
        for (let i=0; i<validators.children.length; i++) {
            const validator = validators.children[i]
            validator.images = validImages
            validImages = validImages.filter(validImage => validator.validImages.includes(validImage))
        }
        return validImages
    }

    function showImageArea(imagePathsOrData) {
        isImage = imagePathsOrData.length > 0
        control.fileUrlsAndSources = imagePathsOrData
    }

    // Use this to validate and show the images. The concatenation of previous selected images is done automatically
    // Returns true if the images were valid and added
    function validateImagesAndShowImageArea(imagePaths) {
        const validImages = validateImages(imagePaths)
        showImageArea(validImages)
        return isImage
    }

    function showReplyArea(messageId, userName, message, contentType, image, album, albumCount, sticker) {
        isReply = true
        replyArea.userName = userName
        replyArea.message = message
        replyArea.contentType = contentType
        replyArea.image = image
        replyArea.stickerData = sticker
        replyArea.messageId = messageId
        replyArea.album = album
        replyArea.albumCount = albumCount
        messageInputField.forceActiveFocus();
    }

    function forceInputActiveFocus() {
        messageInputField.forceActiveFocus();
    }

    function openImageDialog() {
        d.imageDialog = imageDialogComponent.createObject(control)
        d.imageDialog.open()
    }

    DropAreaPanel {
        enabled: control.visible && control.enabled
        parent: control.Overlay.overlay
        anchors.fill: parent
        onDroppedOnValidScreen: (drop) => {
            let dropUrls = drop.urls
            if (!drop.hasUrls) {
                console.warn("Trying to drop, list of URLs is empty tho; formats:", drop.formats)
                if (drop.formats.includes("text/x-moz-url"))  { // Chrome uses a non-standard MIME type
                    dropUrls = drop.getDataAsString("text/x-moz-url")
                }
            }

            if (validateImagesAndShowImageArea(dropUrls))
                drop.acceptProposedAction()
            else
                console.warn("Invalid drop with URLs:", dropUrls)
        }
    }

    // This is used by Squish tests to not have to access the file dialog
    function selectImageString(filePath) {
        validateImagesAndShowImageArea([filePath])
        messageInputField.forceActiveFocus();
    }

    Component {
        id: imageDialogComponent

        StatusFileDialog {
            title: qsTr("Please choose an image")
            currentFolder: picturesShortcut
            selectMultiple: true
            nameFilters: [
                qsTr("Image files (%1)").arg(UrlUtils.validImageNameFilters)
            ]
            onAccepted: {
                validateImagesAndShowImageArea(selectedFiles)
                messageInputField.forceActiveFocus()
                destroy()
            }
            onRejected: destroy()
            Component.onDestruction: d.imageDialog = null
        }
    }

    Component {
        id: chatCommandMenuComponent

        StatusMenu {
            id: chatCommandMenu
            objectName: "chatCommandMenu"
            StatusAction {
                objectName: "chatCommandMenu_addImage"
                text: qsTr("Add image")
                icon.name: "image"
                onTriggered: control.openImageDialog()
            }

            StatusMouseArea {
                implicitWidth: paymentRequestMenuItem.width
                implicitHeight: paymentRequestMenuItem.height
                hoverEnabled: true
                visible: control.paymentRequestFeatureEnabled
                StatusMenuItem {
                    id: paymentRequestMenuItem
                    text: parent.containsMouse && !enabled ? qsTr("Not available in Testnet mode") : qsTr("Add payment request")
                    icon.name: "wallet"
                    icon.color: enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                    enabled: !control.areTestNetworksEnabled
                    onTriggered: {
                        control.openPaymentRequestModal()
                        chatCommandMenu.close()
                    }
                }
            }

            closeHandler: () => {
                              commandBtn.highlighted = false
                              destroy()
                          }
        }
    }

    StatusEmojiSuggestionPopup {
        id: emojiSuggestions
        messageInput: messageInput
        onClicked: function (index) {
            if (index === undefined) {
                index = emojiSuggestions.listView.currentIndex
            }

            const unicode = emojiSuggestions.modelList[index].unicode
            replaceWithEmoji(extrapolateCursorPosition(), emojiSuggestions.shortname, unicode);
        }
    }

    SuggestionBoxPanel {
        id: suggestionsBox
        objectName: "suggestionsBox"
        model: control.usersModel
        x: messageInput.x
        y: -height - Theme.smallPadding
        width: messageInput.width
        filter: messageInputField.text
        cursorPosition: messageInputField.cursorPosition
        inputField: messageInputField
        onItemSelected: function (item, lastAtPosition, lastCursorPosition) {
            messageInputField.forceActiveFocus()
            d.insertMention(item.preferredDisplayName, item.pubKey, lastAtPosition, lastCursorPosition)
        }
        onVisibleChanged: {
            if (!visible) {
                messageInputField.forceActiveFocus();
            }
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 4

        StatusQ.StatusFlatRoundButton {
            id: commandBtn
            objectName: "statusChatInputCommandButton"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 4
            icon.name: "chat-commands"
            type: StatusQ.StatusFlatRoundButton.Type.Tertiary
            visible: !isEdit
            onClicked: {
                highlighted = true
                let menu = chatCommandMenuComponent.createObject(commandBtn)
                menu.y = -menu.height // Show above button
                menu.open()
            }
        }

        Rectangle {
            id: messageInput

            Layout.fillWidth: true
            implicitHeight: inputLayout.implicitHeight + inputLayout.anchors.topMargin + inputLayout.anchors.bottomMargin
            implicitWidth: inputLayout.implicitWidth + inputLayout.anchors.leftMargin + inputLayout.anchors.rightMargin

            color: isEdit ? Theme.palette.statusChatInput.secondaryBackgroundColor : Theme.palette.baseColor2
            radius: 20

            // Bottom right corner has different radius
            bottomRightRadius: Theme.radius

            StatusQ.StatusToolTip {
                id: messageLengthLimitTooltip
                text: messageInputField.length >= control.messageLimitHard ? qsTr("Please reduce the message length")
                      : qsTr("Maximum message character count is %n", "", control.messageLimit)
                orientation: StatusQ.StatusToolTip.Orientation.Top
                timeout: 3000 // show for 3 seconds
            }

            StatusTextFormatMenu {
                id: textFormatMenu
                visible: !!messageInputField.selectedText && !suggestionsBox.visible
                focus: false
                x: messageInputField.positionToRectangle(messageInputField.selectionStart).x
                y: messageInputField.y - height - 5

                StatusChatInputTextFormationAction {
                    id: boldAction
                    wrapper: "**"
                    icon.name: "bold"
                    text: qsTr("Bold (%1)").arg(StatusQUtils.StringUtils.shortcutToText(shortcut))
                    selectedTextWithFormationChars: d.getSelectedTextWithFormationChars(messageInputField)
                    onToggled: !checked ? unwrapSelection(wrapper, d.getSelectedTextWithFormationChars(messageInputField))
                                        : wrapSelection(wrapper)
                    shortcut: StandardKey.Bold
                    enabled: textFormatMenu.visible
                }
                StatusChatInputTextFormationAction {
                    id: italicAction
                    wrapper: "*"
                    icon.name: "italic"
                    text: qsTr("Italic (%1)").arg(StatusQUtils.StringUtils.shortcutToText(shortcut))
                    selectedTextWithFormationChars: d.getSelectedTextWithFormationChars(messageInputField)
                    checked: (surroundedBy("*") && !surroundedBy("**")) || surroundedBy("***")
                    onToggled: !checked ? unwrapSelection(wrapper, d.getSelectedTextWithFormationChars(messageInputField))
                                        : wrapSelection(wrapper)
                    shortcut: StandardKey.Italic
                    enabled: textFormatMenu.visible
                }
                StatusChatInputTextFormationAction {
                    id: strikethruAction
                    wrapper: "~~"
                    icon.name: "strikethrough"
                    text: qsTr("Strikethrough (%1)").arg(StatusQUtils.StringUtils.shortcutToText(shortcut))
                    selectedTextWithFormationChars: d.getSelectedTextWithFormationChars(messageInputField)
                    onToggled: !checked ? unwrapSelection(wrapper, d.getSelectedTextWithFormationChars(messageInputField))
                                        : wrapSelection(wrapper)
                    shortcut: "Ctrl+Shift+S"
                    enabled: textFormatMenu.visible
                }
                StatusChatInputTextFormationAction {
                    id: codeAction
                    readonly property bool multilineSelection: messageInputField.positionToRectangle(messageInputField.selectionEnd).y >
                                                               messageInputField.positionToRectangle(messageInputField.selectionStart).y

                    wrapper: multilineSelection ? "```" : "`"
                    icon.name: "code"
                    text: qsTr("Code (%1)").arg(StatusQUtils.StringUtils.shortcutToText(shortcut))
                    selectedTextWithFormationChars: d.getSelectedTextWithFormationChars(messageInputField)
                    onToggled: !checked ? unwrapSelection(wrapper, d.getSelectedTextWithFormationChars(messageInputField))
                                        : wrapSelection(wrapper)
                    shortcut: multilineSelection ? "Ctrl+Shift+Alt+C" : "Ctrl+Shift+C"
                    enabled: textFormatMenu.visible
                }
                StatusChatInputTextFormationAction {
                    id: quoteAction
                    wrapper: "> "
                    icon.name: "quote"
                    text: qsTr("Quote (%1)").arg(StatusQUtils.StringUtils.shortcutToText(shortcut))
                    checked: messageInputField.selectedText && isSelectedLinePrefixedBy(messageInputField.selectionStart, wrapper)
                    onToggled: !checked ? unprefixSelectedLine(wrapper) : prefixSelectedLine(wrapper)
                    shortcut: "Ctrl+Shift+Q"
                    enabled: textFormatMenu.visible
                }
            }

            ColumnLayout {
                id: validators
                anchors.bottom: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Top ? parent.top : undefined
                anchors.bottomMargin: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Top ? -4 : undefined
                anchors.top: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Bottom ? parent.bottom : undefined
                anchors.topMargin: control.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Bottom ? (isImage ? -4 : 4) : undefined
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                z: 1

                StatusChatImageExtensionValidator {
                    id: imageExtValidator
                    Layout.alignment: Qt.AlignHCenter
                }
                StatusChatImageSizeValidator {
                    id: imageSizeValidator
                    Layout.alignment: Qt.AlignHCenter
                }
                StatusChatImageQtyValidator {
                    id: imageQtyValidator
                    Layout.alignment: Qt.AlignHCenter
                }

                Timer {
                    interval: 3000
                    repeat: true
                    running: !imageQtyValidator.isValid || !imageSizeValidator.isValid || !imageExtValidator.isValid
                    onTriggered: validateImages(control.fileUrlsAndSources)
                }
            }

            ColumnLayout {
                id: inputLayout
                width: parent.width
                spacing: 4

                StatusChatInputReplyArea {
                    id: replyArea
                    visible: isReply
                    Layout.fillWidth: true
                    Layout.margins: 2
                    onCloseButtonClicked: {
                        isReply = false
                    }
                }

                ChatInputLinksPreviewArea {
                    id: linkPreviewArea
                    Layout.fillWidth: true
                    visible: hasContent
                    horizontalPadding: 12
                    topPadding: 12
                    imagePreviewArray: control.fileUrlsAndSources
                    linkPreviewModel: control.linkPreviewModel
                    paymentRequestModel: control.paymentRequestModel
                    formatBalance: control.formatBalance
                    showLinkPreviewSettings: control.askToEnableLinkPreview
                    onImageRemoved: (index) => {
                        //Just do a copy and replace the whole thing because it's a plain JS array and thre's no signal when a single item is removed
                        let urls = control.fileUrlsAndSources
                        if (urls.length > index && urls[index]) {
                            urls.splice(index, 1)
                        }
                        control.fileUrlsAndSources = urls
                        validateImages(control.fileUrlsAndSources)
                    }
                    onImageClicked: (chatImage) => Global.openImagePopup(chatImage, "", false)
                    onLinkReload: (link) => control.linkPreviewReloaded(link)
                    onLinkClicked: (link) => Global.requestOpenLink(link)
                    onEnableLinkPreview: () => control.enableLinkPreview()
                    onEnableLinkPreviewForThisMessage: () => control.enableLinkPreviewForThisMessage()
                    onDisableLinkPreview: () => control.disableLinkPreview()
                    onDismissLinkPreviewSettings: () => control.dismissLinkPreviewSettings()
                    onDismissLinkPreview: (index) => control.dismissLinkPreview(index)
                    onRemovePaymentRequestPreview: (index) => control.removePaymentRequestPreview(index)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumHeight: (messageInputField.contentHeight + messageInputField.topPadding + messageInputField.bottomPadding)
                    Layout.maximumHeight: 200
                    spacing: Theme.radius
                    StatusScrollView {
                        id: inputScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        padding: 0
                        rightPadding: Theme.padding // for the scrollbar
                        contentWidth: availableWidth

                        StatusQ.StatusTextArea {
                            id: messageInputField

                            objectName: "messageInputField"

                            property int previousCursorPosition: 0

                            width: inputScrollView.availableWidth

                            textFormat: Text.RichText
                            placeholderText: control.chatInputPlaceholder
                            color: isEdit ? Theme.palette.directColor1 : Theme.palette.textColor
                            topPadding: 9
                            bottomPadding: 9
                            leftPadding: 0
                            rightPadding: 0
                            background: null

                            inputMethodHints: Qt.ImhMultiLine | Qt.ImhNoEditMenu
                            EnterKey.type: Qt.EnterKeyReturn // insert newlines hint for OSK

                            // This is needed to make sure the text area is disabled when the input is disabled
                            Binding on enabled {
                                value: control.enabled
                            }
                            Keys.onShortcutOverride: function (event) {
                                event.accepted = event.matches(StandardKey.Paste)
                            }
                            Keys.onUpPressed: function(event) {
                                if (isEdit && !activeFocus) {
                                    forceActiveFocus();
                                } else {
                                    if (messageInputField.length === 0) {
                                        control.keyUpPress();
                                    }
                                }
                                event.accepted = false
                            }
                            Keys.onPressed: function(event) {
                                keyEvent = event;
                                onKeyPress(event)
                            }
                            Keys.onReleased: (event) => onRelease(event) // gives much more up to date cursorPosition

                            property var keyEvent

                            onCursorPositionChanged: {
                                if(mentionsPos.length > 0 && ((keyEvent.key === Qt.Key_Left) || (keyEvent.key === Qt.Key_Right)
                                  || (selectedText.length>0))) {
                                    const mention = d.getMentionAtPosition(cursorPosition)
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

                                inputScrollView.ensureVisible(cursorRectangle)
                                previousCursorPosition = cursorPosition
                            }

                            onTextChanged: {
                                if (length <= control.messageLimit) {
                                    if (length === 0) {
                                        mentionsPos = [];
                                    } else {
                                        checkForInlineEmojis()
                                    }
                                } else if (length > control.messageLimitHard) {
                                    const removeFrom = (cursorPosition < messageLimitHard) ? cursorWhenPressed : messageLimitHard;
                                    remove(removeFrom, cursorPosition);
                                    messageLengthLimitTooltip.open();
                                }

                                d.updateMentionsPositions()
                                d.cleanMentionsPos()

                                messageLengthLimit.remainingChars = (messageLimit - length);
                            }

                            onLinkActivated: {
                                const mention = d.getMentionAtPosition(cursorPosition - 1)
                                if(mention) {
                                    select(mention.leftIndex, mention.rightIndex)
                                }
                            }

                            onEnabledChanged: {
                                if (!enabled) {
                                    clear()
                                    control.hideExtendedArea()
                                }
                            }

                            StatusSyntaxHighlighter {
                                quickTextDocument: messageInputField.textDocument
                                codeBackgroundColor: Theme.palette.baseColor4
                                codeForegroundColor: Theme.palette.textColor
                                hyperlinks: control.urlsList
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

                        Shortcut {
                            enabled: messageInputField.activeFocus
                            sequences: ["Ctrl+Meta+Space", "Ctrl+E"]
                            onActivated: emojiBtn.clicked(null)
                        }
                    }

                    Column {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 3

                        StyledText {
                            id: messageLengthLimit
                            property int remainingChars: -1
                            leftPadding: Theme.halfPadding
                            rightPadding: Theme.halfPadding
                            visible: messageInputField.length >= control.messageLimit - control.messageLimitSoft
                            color: {
                                if (remainingChars  >= 0)
                                    return Theme.palette.textColor
                                else
                                    return Theme.palette.dangerColor1
                            }
                            text: visible ? remainingChars.toString() : ""

                            StatusMouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    messageLengthLimitTooltip.open()
                                }
                                onExited: {
                                    messageLengthLimitTooltip.hide()
                                }
                            }
                        }

                        Row {
                            id: actions
                            spacing: 2

                            StatusQ.StatusFlatRoundButton {
                                objectName: "statusChatInputSendButton"
                                implicitHeight: 32
                                implicitWidth: 32
                                icon.name: "send"
                                type: StatusQ.StatusFlatRoundButton.Type.Tertiary
                                visible: messageInputField.length > 0 || messageInputField.preeditText || control.fileUrlsAndSources.length > 0 ||
                                         (!!control.paymentRequestModel && control.paymentRequestModel.ModelCount.count > 0)
                                onClicked: {
                                    InputMethod.commit()
                                    control.onKeyPress({modifiers: d.kbdModifierToSendMessage, key: Qt.Key_Return})
                                }
                                tooltip.text: qsTr("Send message")
                            }

                            StatusQ.StatusFlatRoundButton {
                                id: emojiBtn
                                objectName: "statusChatInputEmojiButton"
                                implicitHeight: 32
                                implicitWidth: 32
                                icon.name: "emojis"
                                icon.color: (hovered || highlighted) ? Theme.palette.primaryColor1
                                                                     : Theme.palette.baseColor1
                                type: StatusQ.StatusFlatRoundButton.Type.Tertiary
                                highlighted: d.emojiPopupOpened
                                onClicked: {
                                    if (d.emojiPopupOpened) {
                                        emojiPopup.close()
                                        return
                                    }
                                    emojiPopup.open()
                                    d.emojiPopupOpened = true
                                }
                            }

                            StatusQ.StatusFlatRoundButton {
                                id: gifBtn

                                objectName: "gifPopupButton"
                                implicitHeight: 32
                                implicitWidth: 32
                                visible: !isEdit
                                icon.name: "gif"
                                icon.color: (hovered || highlighted) ? Theme.palette.primaryColor1
                                                                     : Theme.palette.baseColor1
                                type: StatusQ.StatusFlatRoundButton.Type.Tertiary
                                onClicked: {
                                    highlighted = true
                                    control.openGifPopupRequest({// Properties needed for relative position and close
                                                                    popupParent: actions,
                                                                    closeAfterSelection: control.closeGifPopupAfterSelection
                                                                },
                                                                // Gif selected callback
                                                                (event, url) => {
                                                                    messageInputField.text += "\n" + url
                                                                    control.sendMessage(event)
                                                                    control.isReply = false
                                                                    messageInputField.forceActiveFocus()
                                                                },
                                                                // Close callback
                                                                () => {
                                                                    highlighted = false
                                                                })
                                }
                            }

                            StatusQ.StatusFlatRoundButton {
                                id: stickersBtn
                                objectName: "statusChatInputStickersButton"
                                implicitHeight: 32
                                implicitWidth: 32
                                width: visible ? 32 : 0
                                icon.name: "stickers"
                                icon.color: (hovered || highlighted) ? Theme.palette.primaryColor1
                                                                     : Theme.palette.baseColor1
                                type: StatusQ.StatusFlatRoundButton.Type.Tertiary
                                visible: !isEdit && emojiBtn.visible
                                highlighted: d.stickersPopupOpened
                                onClicked: {
                                    if (d.stickersPopupOpened) {
                                        control.stickersPopup.close()
                                        return
                                    }
                                    control.stickersPopup.open()
                                    d.stickersPopupOpened = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
