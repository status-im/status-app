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
    id: root
    objectName: "statusChatInput"

    signal stickerSelected(string hashId, string packId, string url)
    signal sendMessageRequested()
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

    property bool isReply: false
    readonly property string replyMessageId: replyArea.messageId

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
            const mentionTag = d.mentionTagStart + atSymbol + linkText + '</span> '
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
        property int copyTextStart: 0

        readonly property int nbEmojisInClipboard: StatusQUtils.Emoji.nbEmojis(ClipboardUtils.html)

        property bool emojiPopupOpened: false
        property bool stickersPopupOpened: false

        property var imageDialog: null

        // whether to send message using Ctrl+Return or just Enter; based on OSK (virtual keyboard presence)
        readonly property int kbdModifierToSendMessage: Qt.inputMethod.visible ? Qt.ControlModifier : Qt.NoModifier

        // common popups are emoji, jif and stickers
        // Put controlWidth as argument with default value for binding
        function getCommonPopupRelativePosition(popup, popupParent, controlWidth = root.width) {
            const popupWidth = popup ? popup.width : 0
            const popupHeight = popup ? popup.height : 0
            const controlX = controlWidth - popupWidth - Theme.halfPadding
            const controlY = -popupHeight
            return popupParent.mapFromItem(root, controlX, controlY)
        }

        readonly property point emojiPopupPosition: getCommonPopupRelativePosition(emojiPopup, emojiBtn)
        readonly property point stickersPopupPosition: getCommonPopupRelativePosition(stickersPopup, stickersBtn)

        readonly property string mentionTagStart: `<span style="background-color: ${root.Theme.palette.mentionColor2};"><a style="color:${root.Theme.palette.mentionColor1};text-decoration:none" href='http://'>`
        readonly property string mentionTagEnd: `</a></span>`

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
                    (event.modifiers & Qt.ControlModifier) && !d.imageDialog
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
            emojiBtn.highlighted = false
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

    function checkTextInsert() {
        if (emojiSuggestions.visible) {
            messageInputField.replaceWithEmoji(emojiSuggestions.shortname, emojiSuggestions.unicode)
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

        if (messageLength <= messageLimit) {
            checkForInlineEmojis(true)
            root.sendMessageRequested()
            root.hideExtendedArea()
        } else {
            // pop-up a warning message when trying to send a message over the limit
            lengthLimitTooltip.open()
        }
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
                    messageInputField.replaceWithEmoji(lastWord, emojiFound.unicode, force ? 0 : 1 /*offset*/)
                }
            }
        }
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
        replyArea.messageId = ""
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
        d.imageDialog = imageDialogComponent.createObject(root)
        d.imageDialog.open()
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
                onTriggered: root.openImageDialog()
            }

            StatusMouseArea {
                implicitWidth: paymentRequestMenuItem.width
                implicitHeight: paymentRequestMenuItem.height
                hoverEnabled: true
                visible: root.paymentRequestFeatureEnabled
                StatusMenuItem {
                    id: paymentRequestMenuItem
                    text: parent.containsMouse && !enabled ? qsTr("Not available in Testnet mode") : qsTr("Add payment request")
                    icon.name: "wallet"
                    icon.color: enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                    enabled: !root.areTestNetworksEnabled
                    onTriggered: {
                        root.openPaymentRequestModal()
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

        x: messageInput.x
        y: -height - Theme.smallPadding
        width: messageInput.width
        height: Math.min(400, implicitHeight)
        z: parent.z + 100

        visible: !shouldHide && messageInputField.text.length > 0
                 && model.ModelCount.count > 0 && messageInputField.lastAtPosition > -1

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
                id: lengthLimitTooltip
                text: messageInputField.length >= root.messageLimitHard ? qsTr("Please reduce the message length")
                      : qsTr("Maximum message character count is %n", "", root.messageLimit)
                orientation: StatusQ.StatusToolTip.Orientation.Top
                timeout: 3000 // show for 3 seconds
            }

            StatusTextFormatMenu {
                id: textFormatMenu
                visible: !!messageInputField.selectedText && !suggestionsBox.visible
                focus: false
                x: messageInputField.positionToRectangle(messageInputField.selectionStart).x
                y: messageInputField.y - height - 5

                component FormattingAction:  Action {
                    required property string wrapper
                    required property string name

                    checkable: true
                    checked: d.surroundedBy(d.getSelectedTextWithFormationChars(messageInputField), wrapper)
                    text: `${name} (${StatusQUtils.StringUtils.shortcutToText(shortcut)})`
                    onToggled: !checked ? messageInputField.unwrapSelection(wrapper, d.getSelectedTextWithFormationChars(messageInputField))
                                        : messageInputField.wrapSelection(wrapper)
                    enabled: textFormatMenu.visible
                }

                FormattingAction {
                    wrapper: "**"
                    name: qsTr("Bold")
                    icon.name: "bold"
                    shortcut: StandardKey.Bold
                }

                FormattingAction {
                    wrapper: "*"
                    name: qsTr("Italic")
                    icon.name: "italic"
                    checked: {
                        const text = d.getSelectedTextWithFormationChars(messageInputField)
                        return (surroundedBy(text, "*") && !surroundedBy(text, "**")) || surroundedBy(text, "***")
                    }
                    shortcut: StandardKey.Italic
                }

                FormattingAction {
                    wrapper: "~~"
                    name: qsTr("Strikethrough")
                    icon.name: "strikethrough"
                    shortcut: "Ctrl+Shift+S"
                }

                FormattingAction {
                    readonly property bool multilineSelection:
                        messageInputField.positionToRectangle(messageInputField.selectionEnd).y >
                        messageInputField.positionToRectangle(messageInputField.selectionStart).y

                    wrapper: multilineSelection ? "```" : "`"
                    name: qsTr("Code")
                    icon.name: "code"
                    shortcut: multilineSelection ? "Ctrl+Shift+Alt+C" : "Ctrl+Shift+C"
                }

                Action {
                    readonly property string wrapper: "> "

                    icon.name: "quote"
                    text: qsTr("Quote (%1)").arg(StatusQUtils.StringUtils.shortcutToText(shortcut))
                    checkable: true
                    checked: messageInputField.selectedText &&
                             messageInputField.isSelectedLinePrefixedBy(messageInputField.selectionStart, wrapper)
                    onToggled: !checked ? messageInputField.unprefixSelectedLine(wrapper)
                                        : messageInputField.prefixSelectedLine(wrapper)
                    shortcut: "Ctrl+Shift+Q"
                    enabled: textFormatMenu.visible
                }
            }

            ColumnLayout {
                id: validators
                anchors.bottom: root.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Top ? parent.top : undefined
                anchors.bottomMargin: root.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Top ? -4 : undefined
                anchors.top: root.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Bottom ? parent.bottom : undefined
                anchors.topMargin: root.imageErrorMessageLocation === StatusChatInput.ImageErrorMessageLocation.Bottom ? (isImage ? -4 : 4) : undefined
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
                    onTriggered: validateImages(root.fileUrlsAndSources)
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

                        Control {
                            id: messageInputFieldControl

                            width: inputScrollView.availableWidth

                            Keys.onEscapePressed: {
                                if (root.isReply) {
                                    root.isReply = false
                                    event.accepted = true
                                }
                            }

                            Keys.onPressed: (event) => {
                                // ⌘⇧U
                                if (d.isUploadFilePressed(event)) {
                                    event.accepted = true
                                    openImageDialog()
                                }

                                if (event.key === Qt.Key_Down && emojiSuggestions.visible) {
                                    event.accepted = true
                                    return emojiSuggestions.listView.incrementCurrentIndex()
                                }
                                if (event.key === Qt.Key_Up && emojiSuggestions.visible) {
                                    event.accepted = true
                                    return emojiSuggestions.listView.decrementCurrentIndex()
                                }
                            }

                            contentItem: StatusChatInputTextArea {
                                id: messageInputField

                                Keys.forwardTo: [messageInputFieldControl]

                                objectName: "messageInputField"

                                messageLimit: root.messageLimit
                                messageLimitHard: root.messageLimitHard

                                urlsList: root.urlsList
                                usersModel: root.usersModel

                                suggestedMentionPubKey: {
                                    suggestionsBox.listView.count

                                    return suggestionsBox.visible ? StatusQUtils.ModelUtils.get(
                                                                 suggestionsBox.model,
                                                                 suggestionsBox.listView.currentIndex,
                                                                 "pubKey") ?? ""
                                                           : ""
                                }

                                placeholderText: root.chatInputPlaceholder

                                // This is needed to make sure the text area is disabled when the input is disabled
                                Binding on enabled {
                                    value: root.enabled
                                }

                                onEnabledChanged: {
                                    if (!enabled) {
                                        clear()
                                        root.hideExtendedArea()
                                    }
                                }

                                onEmojiFilterChanged: {
                                    if (emojiFilter.length > 2) {
                                        const emojis = StatusQUtils.Emoji.getSuggestions(emojiFilter)
                                        emojiSuggestions.openPopup(emojis, emojiFilter)
                                    } else {
                                        emojiSuggestions.close()
                                    }
                                }
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
                            id: lengthLimitText
                            property int remainingChars: -1
                            leftPadding: Theme.halfPadding
                            rightPadding: Theme.halfPadding
                            visible: messageInputField.length >= root.messageLimit - root.messageLimitSoft
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
                                    lengthLimitTooltip.open()
                                }
                                onExited: {
                                    lengthLimitTooltip.hide()
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
                                visible: messageInputField.length > 0 || messageInputField.preeditText || root.fileUrlsAndSources.length > 0 ||
                                         (!!root.paymentRequestModel && root.paymentRequestModel.ModelCount.count > 0)
                                onClicked: {
                                    InputMethod.commit()
                                    root.tryFinalizeMessage()
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

                                    // Properties needed for relative position and close
                                    const properties = {
                                        popupParent: actions,
                                        closeAfterSelection: root.closeGifPopupAfterSelection
                                    }

                                    const onGifSelectedCb = url => {
                                        messageInputField.text += "\n" + url
                                        root.sendMessageRequested()
                                        root.isReply = false
                                        messageInputField.forceActiveFocus()
                                    }

                                    const onCloseCb = () => {
                                        highlighted = false
                                    }

                                    root.openGifPopupRequest(properties,
                                                             onGifSelectedCb,
                                                             onCloseCb)
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
                                        root.stickersPopup.close()
                                        return
                                    }
                                    root.stickersPopup.open()
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
