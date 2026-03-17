import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls as StatusQ

import AppLayouts.Chat.panels
import mainui
import utils

import shared.controls.chat
import shared.panels

import QtModelsToolkit

Control {
    id: root
    objectName: "statusChatInput"

    signal stickerSelected(string hashId, string packId, string url)
    signal sendMessageRequested()
    signal editRequested()
    signal linkPreviewReloaded(string link)
    signal enableLinkPreview()
    signal enableLinkPreviewForThisMessage()
    signal disableLinkPreview()
    signal dismissLinkPreviewSettings()
    signal dismissLinkPreview(int index)
    signal openPaymentRequestModal(var callback)
    signal removePaymentRequestPreview(int index)
    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    property var usersModel

    property var emojiPopup: null
    property var stickersPopup: null
    // Use this to only enable the Connections only when this Input opens the Emoji popup
    property bool closeGifPopupAfterSelection: true
    property bool areTestNetworksEnabled
    property bool paymentRequestFeatureEnabled: false

    property bool isReply: false

    property bool isImage: false
    property bool isEdit: false

    readonly property int messageLimit: 2000 // actual message limit, we don't allow sending more than that
    readonly property int messageLimitSoft: 200 // we start showing a char counter when this no. of chars left in the message
    readonly property int messageLimitHard: 20000 // still cut-off attempts to paste beyond this limit, for app usability reasons

    property string chatInputPlaceholder: qsTr("Message")

    property alias textInput: messageInputField

    property var fileUrlsAndSources: []

    property var linkPreviewModel: null
    property var paymentRequestModel: null

    property var formatBalance: null

    property var urlsList: []

    property bool askToEnableLinkPreview: false

    onEnabledChanged: {
        if (enabled)
            return

        clear()
        hideExtendedArea()
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
            const mentionTag = messageInputField.mentionTagStart + atSymbol + linkText + '</span> '
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

    padding: Theme.smallPadding

    QtObject {
        id: d

        // whether to send message using Ctrl+Return or just Enter; based on
        // OSK (virtual keyboard presence)
        readonly property int kbdModifierToSendMessage:
            Qt.inputMethod.visible ? Qt.ControlModifier : Qt.NoModifier

        property bool emojiPopupOpened: false
        property bool stickersPopupOpened: false

        // common popups are emoji, gif and stickers
        // Put controlWidth as argument with default value for binding
        function getCommonPopupRelativePosition(popup, popupParent, controlWidth = root.width) {
            const popupWidth = popup ? popup.width : 0
            const popupHeight = popup ? popup.height : 0
            const controlX = controlWidth - popupWidth - Theme.halfPadding
            const controlY = -popupHeight
            return popupParent.mapFromItem(root, controlX, controlY)
        }

        readonly property point emojiPopupPosition: getCommonPopupRelativePosition(emojiPopup, toolBar.emojiButton)
        readonly property point stickersPopupPosition: getCommonPopupRelativePosition(stickersPopup, toolBar.stickersButton)

        readonly property StateGroup emojiPopupTakeover: StateGroup {
            states: State {
                when: d.emojiPopupOpened

                PropertyChanges {
                    target: emojiPopup

                    directParent: toolBar.emojiButton
                    relativeX: 0
                    relativeY: -emojiPopup.height - root.Theme.halfPadding
                }
            }
        }
        readonly property StateGroup stickersPopupTakeover: StateGroup {
            states: State {
                when: d.stickersPopupOpened

                PropertyChanges {
                    target: stickersPopup

                    directParent: toolBar.stickersButton
                    relativeX: 0
                    relativeY: -stickersPopup.height - root.Theme.halfPadding
                }
            }
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

        function surroundedBy(text: string, surroundings: string) : bool {
            if (text === "")
                return false

            const firstIndex = text.indexOf(surroundings)
            if (firstIndex === -1) {
                return false
            }

            return (text.lastIndexOf(surroundings) > firstIndex)
        }

        function isUploadFilePressed(event) {
            return (event.key === Qt.Key_U) &&
                    (event.modifiers & Qt.ControlModifier) && !imageDialog.visible
        }
    }

    Connections {
        enabled: d.emojiPopupOpened
        target: emojiPopup

        function onEmojiSelected(text: string, atCursor: bool) {
            // commit any potential preedit text first
            InputMethod.commit()

            messageInputField.insertInTextInput(atCursor ? messageInputField.cursorPosition
                                                         : messageInputField.length, text)
            messageInputField.forceActiveFocus();
        }
        function onClosed() {
            d.emojiPopupOpened = false
        }
    }

    Connections {
        enabled: d.stickersPopupOpened
        target: root.stickersPopup

        function onStickerSelected(hashId: string, packId: string, url: string ) {
            root.stickerSelected(hashId, packId, url)
            root.hideExtendedArea();
            messageInputField.forceActiveFocus();
        }
        function onClosed() {
            d.stickersPopupOpened = false
        }
    }

    // Preliminary handling key events of text area. When not accepted events
    // events are forwarded to the text area itself
    Item {
        id: keyEventsFilter

        Keys.onEscapePressed: event => {
            if (root.isReply)
                root.isReply = false
            else
                event.accepted = false
        }

        Keys.onUpPressed: event => {
            if (messageInputField.length === 0)
                root.editRequested()

            event.accepted = false
        }

        Keys.onPressed: event => {
            if (event.modifiers === d.kbdModifierToSendMessage &&
                    (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                tryFinalizeMessage()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Tab) {
                if (checkTextInsert()) {
                    event.accepted = true
                    return
                }
            }

            // ⌘⇧U
            if (d.isUploadFilePressed(event)) {
                event.accepted = true
                imageDialog.open()
                return
            }

            if (event.key === Qt.Key_Down && emojiSuggestions.visible) {
                event.accepted = true
                emojiSuggestions.listView.incrementCurrentIndex()
                return
            }
            if (event.key === Qt.Key_Up && emojiSuggestions.visible) {
                event.accepted = true
                emojiSuggestions.listView.decrementCurrentIndex()
                return
            }

            if (event.matches(StandardKey.Paste)) {
                if (!ClipboardUtils.hasImage)
                    return

                const clipboardImage = ClipboardUtils.imageBase64
                validateImagesAndShowImageArea([clipboardImage])
                event.accepted = true
            }
        }
    }

    function checkTextInsert() {
        if (emojiSuggestions.visible) {
            messageInputField.replaceWithEmoji(emojiSuggestions.shortname,
                                               emojiSuggestions.unicode)
            return true
        }
        if (suggestionsBox.visible) {
            suggestionsBox.selectCurrentItem()
            return true
        }

        return false
    }

    /**
        This method does final clean-up and emits sendMessageRequested if message
        is well-formed.
        - if there is active mention suggestion, accepts the suggestion, no send request
        - if message exceeds length limit, triggers tooltip, no send request
        - converts textual emoji representations (like ":)") to actual emojis
        - emits send request
        - hides extended area
      */
    function tryFinalizeMessage() {
        const messageLength = messageInputField.length

        if (checkTextInsert())
            return

        if (messageLength > messageLimit) {
            // pop-up a warning message when trying to send a message over the limit
            lengthLimitTooltip.open()
            return
        }

        messageInputField.convertInlineEmojis()
        root.sendMessageRequested()
        root.hideExtendedArea()
    }

    // exposed because tests use it
    function getPlainText() {
        return messageInputField.getPlainText()
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
        return messageInputField.getTextWithPublicKeys()
    }

    function resetImageArea() {
        isImage = false;
        root.fileUrlsAndSources = []
        for (let i=0; i<validators.children.length; i++) {
            const validator = validators.children[i]
            validator.images = []
        }
    }

    function resetReplyArea() {
        isReply = false
    }

    function hideExtendedArea() {
        resetImageArea()
        resetReplyArea()
    }

    function validateImages(imagePaths = []) {
        // needed because root.fileUrlsAndSources is not a normal js array
        const existing = (root.fileUrlsAndSources || []).map(x => x.toString())
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
        root.fileUrlsAndSources = imagePathsOrData
    }

    // Use this to validate and show the images. The concatenation of previous selected images is done automatically
    // Returns true if the images were valid and added
    function validateImagesAndShowImageArea(imagePaths) {
        const validImages = validateImages(imagePaths)
        showImageArea(validImages)
        return isImage
    }

    function showReplyArea(userName, senderIcon, senderColor, message, contentType, image, album, albumCount, sticker, paymentRequests) {
        isReply = true

        replyPanel.nameText = userName
        replyPanel.avatarImage = senderIcon
        replyPanel.avatarColor = senderColor
        replyPanel.messageText = contentType === Constants.messageContentType.stickerType
                ? "" : StatusQUtils.Utils.stripHtmlTags(message)

        const imageCount = albumCount || (image ? 1 : 0)
        const paymentRequestCount = paymentRequests ? paymentRequests.ModelCount.count : 0

        const parts = []

        if (sticker)
            parts.push(qsTr("Sticker"))

        if (paymentRequestCount > 1) {
            parts.push(qsTr("Multiple payment requests"))
        } else if (paymentRequestCount === 1) {
            const request = StatusQUtils.ModelUtils.get(paymentRequests, 0)
            const formattedAmount = root.formatBalance ? root.formatBalance(request.amount, request.tokenKey)
                                                       : request.amount
            parts.push(qsTr("Payment request %1 %2").arg(formattedAmount).arg(request.symbol))
        }

        if (imageCount)
            parts.push(qsTr("%n Image(s)", "", imageCount))

        replyPanel.extraContentText = parts.join(", ")

        messageInputField.forceActiveFocus();
    }

    function forceInputActiveFocus() {
        messageInputField.forceActiveFocus();
    }

    DropAreaPanel {
        enabled: root.visible && root.enabled
        parent: root.Overlay.overlay
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

    StatusFileDialog {
        id: imageDialog

        title: qsTr("Please choose an image")
        currentFolder: picturesShortcut
        selectMultiple: true
        nameFilters: [
            qsTr("Image files (%1)").arg(UrlUtils.validImageNameFilters)
        ]
        onAccepted: {
            validateImagesAndShowImageArea(selectedFiles)
            messageInputField.forceActiveFocus()
        }
    }

    StatusEmojiSuggestionPopup {
        id: emojiSuggestions

        width: root.width

        onClicked: index => {
            if (index === undefined) {
                index = emojiSuggestions.listView.currentIndex
            }

            const unicode = emojiSuggestions.modelList[index].unicode
            messageInputField.replaceWithEmoji(emojiSuggestions.shortname, unicode)
        }
    }

    SuggestionBoxPanel {
        id: suggestionsBox
        objectName: "suggestionsBox"

        model: messageInputField.suggestionsModel
        inputField: messageInputField

        y: -height - root.Theme.smallPadding
        width: root.width
        height: Math.min(400, implicitHeight)
        z: parent.z + 100

        visible: !shouldHide && messageInputField.activeMentionInput

        property bool shouldHide: false

        function selectItem(index: int) {
            const item = messageInputField.suggestionsModel.get(index)

            messageInputField.forceActiveFocus()
            messageInputField.insertMention(item.preferredDisplayName, item.pubKey)
        }

        function selectCurrentItem() {
            selectItem(listView.currentIndex)
        }

        function hide() {
            shouldHide = true
        }

        listView.onCountChanged: {
            Qt.callLater(function () {
                listView.currentIndex = 0
            })
        }

        onClicked: index => selectItem(index)

        onVisibleChanged: {
            if (!visible)
                messageInputField.forceActiveFocus();

            // If the previous selection was made using the mouse, the currentIndex was changed to -1
            // We change it back to 0 so that it can be used to select using the keyboard
            if (visible && listView.currentIndex === -1)
                listView.currentIndex = 0

            if (visible && !StatusQUtils.Utils.isMobile)
                listView.forceActiveFocus()
        }

        Connections {
            target: messageInputField

            function onCursorPositionChanged() {
                suggestionsBox.shouldHide = false
            }
        }
    }

    background: Item {
        clip: true

        Rectangle {
            anchors.fill: parent

            topLeftRadius: 20
            topRightRadius: 20

            border.color: Theme.palette.directColor7
            color: StatusColors.transparent
        }
    }

    contentItem: ColumnLayout {
        Rectangle {
            id: expandHandler

            Layout.preferredWidth: 32
            Layout.preferredHeight: 5
            Layout.alignment: Qt.AlignHCenter

            radius: height / 2
            color: Theme.palette.directColor7

            visible: false
        }

        ColumnLayout {
            Layout.fillWidth: true

            StatusChatInputReplyPanel {
                id: replyPanel

                Layout.fillWidth: true

                padding: Theme.padding
                bottomPadding: 0

                visible: root.isReply

                onCloseClicked: root.isReply = false
            }

            StatusQ.StatusToolTip {
                id: lengthLimitTooltip
                text: messageInputField.length >= root.messageLimitHard ? qsTr("Please reduce the message length")
                      : qsTr("Maximum message character count is %n", "", root.messageLimit)
                orientation: StatusQ.StatusToolTip.Orientation.Top
                timeout: 3000 // show for 3 seconds
            }

            ColumnLayout {
                id: validators
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
                    onTriggered: validateImages(root.fileUrlsAndSources)
                }
            }

            ColumnLayout {
                id: inputLayout

                ChatInputLinksPreviewArea {
                    id: linkPreviewArea
                    Layout.fillWidth: true
                    visible: hasContent
                    horizontalPadding: 12
                    topPadding: 12
                    imagePreviewArray: root.fileUrlsAndSources
                    linkPreviewModel: root.linkPreviewModel
                    paymentRequestModel: root.paymentRequestModel
                    formatBalance: root.formatBalance
                    showLinkPreviewSettings: root.askToEnableLinkPreview
                    onImageRemoved: (index) => {
                        //Just do a copy and replace the whole thing because it's a plain JS array and thre's no signal when a single item is removed
                        let urls = root.fileUrlsAndSources
                        if (urls.length > index && urls[index]) {
                            urls.splice(index, 1)
                        }
                        root.fileUrlsAndSources = urls
                        validateImages(root.fileUrlsAndSources)
                    }
                    onImageClicked: (chatImage) => Global.openImagePopup(chatImage, "", false)
                    onLinkReload: (link) => root.linkPreviewReloaded(link)
                    onLinkClicked: (link) => Global.requestOpenLink(link)
                    onEnableLinkPreview: () => root.enableLinkPreview()
                    onEnableLinkPreviewForThisMessage: () => root.enableLinkPreviewForThisMessage()
                    onDisableLinkPreview: () => root.disableLinkPreview()
                    onDismissLinkPreviewSettings: () => root.dismissLinkPreviewSettings()
                    onDismissLinkPreview: (index) => root.dismissLinkPreview(index)
                    onRemovePaymentRequestPreview: (index) => root.removePaymentRequestPreview(index)
                }

                StatusScrollView {
                    id: inputScrollView

                    Layout.preferredHeight: messageInputField.implicitHeight

                    Layout.fillWidth: true
                    Layout.maximumHeight: 200

                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    padding: 0
                    rightPadding: Theme.padding // for the scrollbar
                    contentWidth: availableWidth

                    StatusChatInputTextArea {
                        id: messageInputField
                        objectName: "messageInputField"

                        Keys.forwardTo: [keyEventsFilter]

                        topPadding: 9
                        bottomPadding: 9
                        leftPadding: 0
                        rightPadding: 0

                        messageLimit: root.messageLimit
                        messageLimitHard: root.messageLimitHard

                        urlsList: root.urlsList
                        usersModel: root.usersModel
                        urlToBeHighlighted: linkPreviewArea.hoveredUrl

                        suggestedMentionPubKey: {
                            suggestionsBox.listView.count

                            return suggestionsBox.visible
                                    ? StatusQUtils.ModelUtils.get(
                                          suggestionsBox.model,
                                          suggestionsBox.listView.currentIndex,
                                          "pubKey") ?? ""
                                    : ""
                        }

                        placeholderText: root.chatInputPlaceholder

                        onEmojiFilterChanged: {
                            if (emojiFilter.length > 2) {
                                const emojis = StatusQUtils.Emoji.getSuggestions(emojiFilter)
                                emojiSuggestions.openPopup(emojis, emojiFilter)
                            } else {
                                emojiSuggestions.close()
                            }
                        }

                        onAttemptToExceedHardLimit: {
                            lengthLimitTooltip.open()
                        }

                        Shortcut {
                            enabled: messageInputField.activeFocus
                            sequences: ["Ctrl+Meta+Space", "Ctrl+E"]
                            onActivated: toolBar.emojiButton.clicked(null)
                        }

                        StatusChatInputSelectionMarker {
                            anchors.fill: parent
                            clip: true

                            selectionStartRect: {
                                messageInputField.font
                                messageInputField.positionToRectangle(
                                            messageInputField.selectionStart)
                            }
                            selectionEndRect: {
                                messageInputField.font
                                messageInputField.positionToRectangle(
                                            messageInputField.selectionEnd)
                            }
                        }
                    }
                }
            }
        }

        StatusChatInputToolBar {
            id: toolBar

            styleButtonVisible: false
            showFormatting: !!messageInputField.selectedText

            cameraButton.visible: false

            imageButton.checked: imageDialog.visible
            imageButton.onClicked: {
                imageDialog.open()
            }

            sendButton.limitText: messageInputField.length >= root.messageLimit - root.messageLimitSoft
                                  ? (root.messageLimit - messageInputField.length).toString()
                                  : ""

            sendButton.onClicked: {
                InputMethod.commit()
                root.tryFinalizeMessage()
            }

            tokenButton.visible: !root.areTestNetworksEnabled && root.paymentRequestFeatureEnabled
            tokenButton.onClicked: {
                root.openPaymentRequestModal(popup => {
                    popup.closed.connect(() => {
                        tokenButton.checked = false
                    })
                })
            }

            Layout.fillWidth: true

            boldButton.checked: isFormatted("**")
            boldButton.onClicked: toggleFormatting("**")

            italicButton.checked: isFormatted("*")

            italicButton.onClicked: toggleFormatting("*")

            strikeThroughButton.checked: isFormatted("~~")
            strikeThroughButton.onClicked: toggleFormatting("~~")

            quoteButton.checked: !!messageInputField.selectedText
                && messageInputField.isSelectedLinePrefixedBy(messageInputField.selectionStart, "> ")
            quoteButton.onClicked: {
                if (messageInputField.isSelectedLinePrefixedBy(messageInputField.selectionStart, "> "))
                    messageInputField.unprefixSelectedLine("> ")
                else
                    messageInputField.prefixSelectedLine("> ")
            }

            codeButton.checked: isFormatted(codeWrapper)
            codeButton.onClicked: toggleFormatting(codeWrapper)

            readonly property bool multilineSelection:
                messageInputField.positionToRectangle(messageInputField.selectionEnd).y >
                messageInputField.positionToRectangle(messageInputField.selectionStart).y

            readonly property string codeWrapper: multilineSelection ? "```" : "`"

            function isFormatted(wrapper: string) : bool {
                if (wrapper === "*") {
                    const text = d.getSelectedTextWithFormationChars(messageInputField)
                    return (d.surroundedBy(text, "*") && !d.surroundedBy(text, "**")) || d.surroundedBy(text, "***")
                }

                return d.surroundedBy(d.getSelectedTextWithFormationChars(messageInputField), wrapper)
            }

            function toggleFormatting(wrapper: string) {
                if (isFormatted(wrapper))
                    messageInputField.unwrapSelection(wrapper, d.getSelectedTextWithFormationChars(messageInputField))
                else
                    messageInputField.wrapSelection(wrapper)
            }

            stickersButton.checked: d.stickersPopupOpened
            stickersButton.onClicked: {
                if (d.stickersPopupOpened) {
                    root.stickersPopup.close()
                    return
                }
                if (root.stickersPopup) {
                    root.stickersPopup.open()
                    d.stickersPopupOpened = true
                }
            }

            gifButton.checked: false
            gifButton.onClicked: {
                gifButton.checked = true

                const properties = {
                    popupParent: toolBar.gifButton,
                    closeAfterSelection: root.closeGifPopupAfterSelection,
                    relativeX: 0
                }

                const onGifSelectedCb = url => {
                    messageInputField.text += "\n" + url
                    root.sendMessageRequested()
                    root.isReply = false
                    messageInputField.forceActiveFocus()
                }

                const onCloseCb = () => {
                    gifButton.checked = false
                }

                root.openGifPopupRequest(properties, onGifSelectedCb, onCloseCb)
            }

            emojiButton.checked: d.emojiPopupOpened
            emojiButton.onClicked: {
                if (d.emojiPopupOpened) {
                    emojiPopup.close()
                    return
                }
                if (emojiPopup) {
                    emojiPopup.open()
                    d.emojiPopupOpened = true
                }
            }

            mentionButton.checked: !suggestionsBox.shouldHide && messageInputField.activeMentionInput

            mentionButton.onClicked: {
                if (mentionButton.checked) {
                    suggestionsBox.shouldHide = false
                    messageInputField.getPlainText()

                    if (!messageInputField.activeMentionInput)
                        messageInputField.insert(messageInputField.length, "@")
                } else {
                    suggestionsBox.shouldHide = true
                }
            }
        }
    }
}
