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

import AppLayouts.Chat.adaptors
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
    signal imageClicked(var image)
    signal linkClicked(string link)
    signal editCancelRequested()

    property var usersModel
    property bool usersModelIncludeAtEveryone: true

    property var emojiPopup: null
    property var stickersPopup: null
    // Use this to only enable the Connections only when this Input opens the Emoji popup
    property bool closeGifPopupAfterSelection: true
    property bool areTestNetworksEnabled
    property bool paymentRequestFeatureEnabled: false

    property bool isReply: false

    property bool isImage: false
    property bool isEdit: false
    property bool imageFeaturesEnabled: !isEdit
    property bool stickersButtonVisible: !isEdit
    property bool gifButtonVisible: true
    property bool paymentRequestButtonVisible: !isEdit && !areTestNetworksEnabled && paymentRequestFeatureEnabled
    property int editInputMaxLines: 9

    readonly property int messageLimit: 2000 // actual message limit, we don't allow sending more than that
    readonly property int messageLimitSoft: 200 // we start showing a char counter when this no. of chars left in the message
    readonly property int messageLimitHard: 20000 // still cut-off attempts to paste beyond this limit, for app usability reasons

    property string chatInputPlaceholder: qsTr("Type something")

    property alias textInput: messageInputField

    // Background color of the surface the input sits on. Propagated to the text area so the
    // quote-block bar's cell blends with it.
    property alias backgroundColor: messageInputField.backgroundColor

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

    function setText(text) {
        textInput.clear()
        textInput.append(text)
    }

    function clear() {
        textInput.clear()
    }

    QtObject {
        id: d

        // Whether to send message using Ctrl+Return or just Enter; based on
        // OSK (virtual keyboard presence)
        // Qt.inputMethod.visible is not reliable in some cases, as a workaround android and ios keyboards
        // are checked directly as well.
        readonly property int kbdModifierToSendMessage:
            (SystemUtils.androidKeyboardVisible || SystemUtils.iosKeyboardVisible || Qt.inputMethod.visible)
                ? Qt.ControlModifier : Qt.NoModifier

        property bool emojiPopupOpened: false
        property bool stickersPopupOpened: false

        // ── formatting state driving the toolbar bold/italic/strike/quote/code buttons ──
        // The formatting at the caret (from the parsed AST and from the raw delimiters around it)
        // and across the current selection. The toolbar buttons reflect these and toggle them.
        readonly property var caretNode: messageInputField.nodeAt(messageInputField.cursorPosition)
        readonly property var caretDelim: messageInputField.delimitersAt(messageInputField.cursorPosition)
        readonly property bool hasSelection: messageInputField.selectionStart !== messageInputField.selectionEnd
        readonly property var selDelim: messageInputField.delimitersAtSelection(
                                            messageInputField.selectionStart, messageInputField.selectionEnd)

        // Adds `kind` formatting around the selection (or caret).
        function addFormatting(kind) {
            messageInputField.addFormatting(messageInputField.selectionStart,
                                            messageInputField.selectionEnd, kind)
            messageInputField.forceActiveFocus()
        }

        // Removes the active formatting: across the selection, or — with just a caret — from the AST
        // node (removeFormatting) or the local delimiter run (removeDelimitersAt). `caretKind` is the
        // specific kind to strip at the caret; nodeAt takes precedence over delimitersAt.
        function removeActiveFormatting(selectionKind, byNode, byDelimiters, caretKind) {
            if (hasSelection)
                messageInputField.removeDelimitersAtSelection(messageInputField.selectionStart,
                                                              messageInputField.selectionEnd, selectionKind)
            else if (byNode)
                messageInputField.removeFormatting(messageInputField.cursorPosition, caretKind)
            else if (byDelimiters)
                messageInputField.removeDelimitersAt(messageInputField.cursorPosition, caretKind)
            messageInputField.forceActiveFocus()
        }

        // Replaces the ":filter" shortcode being typed with the selected emoji char + a space.
        // `unicode` is the twemoji code-point file name (e.g. "1f600.svg").
        function insertEmoji(unicode) {
            const cursor = messageInputField.cursorPosition
            const at = cursor - messageInputField.emojiFilter.length - 1 // the ":"
            messageInputField.remove(at, cursor)
            // insertTextWithEmojis converts the emoji directly to an inline image in imageEmojis
            // mode, so the raw glyph never flashes before the image appears.
            messageInputField.insertTextWithEmojis(at, StatusQUtils.Emoji.getEmojiCodepoint(unicode.split(".")[0]) + " ")
        }

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
            return root.imageFeaturesEnabled && (event.key === Qt.Key_U) &&
                    (event.modifiers & Qt.ControlModifier) && !imageDialog.visible
        }
    }

    Connections {
        enabled: d.emojiPopupOpened
        target: emojiPopup

        function onEmojiSelected(text: string, atCursor: bool, hexcode: string) {
            // commit any potential preedit text first
            InputMethod.commit()

            const pos = atCursor ? messageInputField.cursorPosition : messageInputField.length
            messageInputField.insertTextWithEmojis(
                pos, StatusQUtils.Emoji.getEmojiCodepoint(hexcode.split(".")[0]) + " ")
            messageInputField.forceActiveFocus()
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
        }
    }

    function checkTextInsert() {
        if (emojiSuggestions.visible) {
            d.insertEmoji(emojiSuggestions.unicode)
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
        // Count against the wire text (mentions expanded to @0xpubkey), not the pill-placeholder text.
        const messageLength = messageInputField.textWithMentions().length
        const wasEdit = root.isEdit

        if (checkTextInsert())
            return

        if (messageLength > messageLimit) {
            // pop-up a warning message when trying to send a message over the limit
            lengthLimitTooltip.open()
            return
        }

        // Emojis are already plain unicode (no ":)" conversion needed).
        root.sendMessageRequested()
        if (!wasEdit)
            root.hideExtendedArea()
    }

    // exposed because tests use it
    function getPlainText() {
        return messageInputField.textWithMentions()
    }

    function getFormattedText(start, end) {
        // TODO(later): rich/formatted-text extraction. ChatTextArea is plain-text markdown, so
        // return the wire text (mentions as @0xpubkey) for now.
        return messageInputField.textWithMentions()
    }

    function getTextWithPublicKeys() {
        return messageInputField.textWithMentions()
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
                ? "" : StatusQUtils.StringUtils.plainText(message)

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
        enabled: root.imageFeaturesEnabled && root.visible && root.enabled
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
        usePhotoLibrary: true
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
            InputMethod.commit()

            if (index === undefined) {
                index = emojiSuggestions.listView.currentIndex
            }

            const unicode = emojiSuggestions.modelList[index].unicode
            d.insertEmoji(unicode)
        }
    }

    // Mention suggestions: filtered from the chat users model by ChatTextArea's live mentionsFilter
    // ("everyone" is added by the adaptor).
    SuggestionsFilterAdaptor {
        id: mentionsAdaptor
        sourceModel: root.usersModel
        filter: messageInputField.mentionsFilter
        usersModelIncludeAtEveryone: root.usersModelIncludeAtEveryone
    }

    SuggestionBoxPanel {
        id: suggestionsBox
        objectName: "suggestionsBox"

        model: mentionsAdaptor.model
        inputField: messageInputField

        y: -height - root.Theme.smallPadding
        width: root.width
        height: Math.min(400, implicitHeight)
        z: parent.z + 100

        visible: !shouldHide && messageInputField.enteringSuggestion

        property bool shouldHide: false

        function selectItem(index: int) {
            InputMethod.commit()

            const item = StatusQUtils.ModelUtils.get(mentionsAdaptor.model, index)
            if (!item)
                return

            messageInputField.forceActiveFocus()

            // Replace the "@filter" being typed with a mention pill + a trailing space.
            const cursor = messageInputField.cursorPosition
            const at = cursor - messageInputField.mentionsFilter.length - 1 // the "@"
            messageInputField.remove(at, cursor)
            messageInputField.insertMention(at, "@" + item.preferredDisplayName, item.pubKey)
            messageInputField.insert(messageInputField.cursorPosition, " ")
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
        Rectangle {
            anchors.fill: parent
            visible: root.isEdit
            color: Theme.palette.background
            radius: 12
        }

        Rectangle {
            id: backgroundRect

            width: parent.width
            height: 1
            visible: true
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
            spacing: 0

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
                      : qsTr("Maximum message character count is %1").arg(root.messageLimit)
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

                RowLayout {
                    id: editModeTag
                    objectName: "statusChatInputEditModeTag"

                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    Layout.topMargin: Theme.halfPadding

                    spacing: Theme.halfPadding
                    visible: root.isEdit

                    StatusIcon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        icon: "edit_pencil"
                        color: Theme.palette.directColor5
                    }

                    StatusBaseText {
                        text: qsTr("Edit")
                        color: Theme.palette.textColor
                        font.pixelSize: Theme.tertiaryTextFontSize
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StatusQ.StatusFlatRoundButton {
                        objectName: "statusChatInputEditCloseButton"
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        icon.name: "close"
                        icon.width: 18
                        icon.height: 18
                        type: StatusQ.StatusFlatRoundButton.Type.Primary
                        onClicked: root.editCancelRequested()
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
                        // Spread into a new array so assigning back triggers the property change notification
                        let urls = [...root.fileUrlsAndSources]
                        if (index < urls.length)
                            urls.splice(index, 1)
                        root.fileUrlsAndSources = urls
                        validateImages(root.fileUrlsAndSources)
                    }
                    onImageClicked: (image) => root.imageClicked(image)
                    onLinkReload: (link) => root.linkPreviewReloaded(link)
                    onLinkClicked: (link) => root.linkClicked(link)
                    onEnableLinkPreview: () => root.enableLinkPreview()
                    onEnableLinkPreviewForThisMessage: () => root.enableLinkPreviewForThisMessage()
                    onDisableLinkPreview: () => root.disableLinkPreview()
                    onDismissLinkPreviewSettings: () => root.dismissLinkPreviewSettings()
                    onDismissLinkPreview: (index) => root.dismissLinkPreview(index)
                    onRemovePaymentRequestPreview: (index) => root.removePaymentRequestPreview(index)
                }

                StatusScrollView {
                    id: inputScrollView

                    readonly property real editMaxHeight: Math.ceil(messageInputField.font.pixelSize * 1.4 * root.editInputMaxLines
                                                                    + messageInputField.topPadding
                                                                    + messageInputField.bottomPadding)

                    Layout.preferredHeight: root.isEdit ? Math.min(messageInputField.implicitHeight, editMaxHeight)
                                                        : messageInputField.implicitHeight
                    Layout.fillWidth: true
                    Layout.maximumHeight: root.isEdit ? editMaxHeight : 200

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.implicitWidth: Theme.halfPadding

                    padding: 0
                    contentWidth: availableWidth

                    ChatTextArea {
                        id: messageInputField
                        objectName: "messageInputField"

                        Keys.forwardTo: [keyEventsFilter]

                        readonly property int basePadding: Theme.padding + 12
                        readonly property int effectiveTextMargin: root.isEdit ? Theme.padding : basePadding
                        readonly property int extraHorizontalPadding: 12 // for the nav bar handle / scrollbar

                        characterLimit: root.messageLimitHard
                        imageEmojis: true

                        // When the text area is empty, we need to use padding because textMargin is ignored
                        // when calculating size. When not empty, textMargin is used because paddings are
                        // clipped by ScrollView.
                        padding: 0
                        leftPadding: (length ? -effectiveTextMargin + Theme.halfPadding : Theme.halfPadding)
                                     + extraHorizontalPadding
                        rightPadding: (length ? -effectiveTextMargin + Theme.halfPadding : Theme.halfPadding)
                                      + extraHorizontalPadding
                        topPadding: length ? 0 : basePadding
                        bottomPadding: (length ? 0 : basePadding) - Theme.padding

                        textMargin: length ? effectiveTextMargin : 0

                        onLineCountChanged: {
                            const flickable = inputScrollView.contentItem

                            if (height - (cursorRectangle.y + cursorRectangle.height) <= textMargin)
                                flickable.contentY = height - flickable.height
                        }

                        placeholderText: root.chatInputPlaceholder

                        // Emoji shortcode suggestions: ChatTextArea exposes enteringEmoji/emojiFilter
                        // (>= 2 chars); feed the twemoji suggestion popup off it.
                        onEmojiFilterChanged: {
                            if (enteringEmoji) {
                                const emojis = StatusQUtils.Emoji.getSuggestions(emojiFilter)
                                emojiSuggestions.openPopup(emojis, emojiFilter)
                            } else {
                                emojiSuggestions.close()
                            }
                        }

                        Shortcut {
                            enabled: messageInputField.activeFocus
                            sequences: ["Ctrl+Meta+Space", "Ctrl+E"]
                            onActivated: toolBar.emojiButton.click()
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
            objectName: "statusChatInputToolBar"

            padding: Theme.smallPadding

            Theme.padding: Theme.defaultPadding
            Theme.fontSizeOffset: ThemeUtils.fontSizeOffsetM

            styleButtonVisible: true
            editActionsVisible: false

            // On iOS, backspace temporarily creates a selection (selectionStart != selectionEnd)
            // around the character being removed. The binding is configured as delayed to avoid
            // briefly setting showFormatting=true and therefore unnecessarily triggering the
            // animation within the toolbar.
            Binding on showFormatting {
                delayed: true
                value: messageInputField.selectionStart !== messageInputField.selectionEnd
            }

            cameraButton.visible: false

            sendButtonVisible: true
            imageButton.visible: root.imageFeaturesEnabled
            imageButton.checked: imageDialog.visible
            imageButton.onClicked: {
                imageDialog.open()
            }

            sendButton.enabled: messageInputField.length > 0 || messageInputField.preeditText
                               || root.fileUrlsAndSources.length > 0
                               || (!!root.paymentRequestModel && root.paymentRequestModel.ModelCount.count > 0)

            sendButton.limitText: messageInputField.length >= root.messageLimit - root.messageLimitSoft
                                  ? (root.messageLimit - messageInputField.length).toString()
                                  : ""
            sendButton.iconName: root.isEdit ? "checkmark" : "send"

            sendButton.onClicked: {
                InputMethod.commit()
                root.tryFinalizeMessage()
            }

            tokenButton.visible: root.paymentRequestButtonVisible
            tokenButton.onClicked: {
                root.openPaymentRequestModal(popup => {
                    popup.closed.connect(() => {
                        tokenButton.checked = false
                    })
                })
            }

            Layout.fillWidth: true

            // Formatting toolbar (bold/italic/strike/quote/code). Each button reflects the formatting
            // at the caret / across the selection (via `d`) and toggles it on click. The ChatIcon is
            // checkable by default, which would break the `checked` binding on click, so it is turned
            // off and `checked` is driven from the query instead.
            boldButton.checkable: false
            boldButton.checked: d.hasSelection ? d.selDelim.bold
                                               : (d.caretNode.bold || d.caretDelim.bold)
            boldButton.onClicked: boldButton.checked
                ? d.removeActiveFormatting("bold", d.caretNode.bold, d.caretDelim.bold, "bold")
                : d.addFormatting("bold")

            italicButton.checkable: false
            italicButton.checked: d.hasSelection ? d.selDelim.italic
                                                 : (d.caretNode.italic || d.caretDelim.italic)
            italicButton.onClicked: italicButton.checked
                ? d.removeActiveFormatting("italic", d.caretNode.italic, d.caretDelim.italic, "italic")
                : d.addFormatting("italic")

            strikeThroughButton.checkable: false
            strikeThroughButton.checked: d.hasSelection ? d.selDelim.strikethrough
                                                        : (d.caretNode.strikethrough || d.caretDelim.strikethrough)
            strikeThroughButton.onClicked: strikeThroughButton.checked
                ? d.removeActiveFormatting("strikethrough", d.caretNode.strikethrough,
                                           d.caretDelim.strikethrough, "strikethrough")
                : d.addFormatting("strikethrough")

            quoteButton.checkable: false
            quoteButton.checked: d.hasSelection ? d.selDelim.quote : d.caretNode.quote
            quoteButton.onClicked: quoteButton.checked
                ? d.removeActiveFormatting("quote", d.caretNode.quote, false, "quote")
                : d.addFormatting("quote")

            codeButton.checkable: false
            codeButton.checked: d.hasSelection ? (d.selDelim.codeSpan || d.selDelim.codeBlock)
                                               : (d.caretNode.codeSpan || d.caretNode.codeBlock
                                                  || d.caretDelim.codeSpan || d.caretDelim.codeBlock)
            codeButton.onClicked: codeButton.checked
                ? d.removeActiveFormatting(d.selDelim.codeBlock ? "codeBlock" : "codeSpan",
                                           d.caretNode.codeSpan || d.caretNode.codeBlock,
                                           d.caretDelim.codeSpan || d.caretDelim.codeBlock,
                                           (d.caretNode.codeBlock || d.caretDelim.codeBlock) ? "codeBlock" : "codeSpan")
                : d.addFormatting("codeSpan")

            stickersButton.checked: d.stickersPopupOpened
            stickersButton.visible: root.stickersButtonVisible
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
            gifButton.visible: root.gifButtonVisible
            gifButton.onClicked: {
                gifButton.checked = true

                const properties = {
                    popupParent: toolBar.gifButton,
                    closeAfterSelection: root.closeGifPopupAfterSelection,
                    relativeX: 0
                }

                const onGifSelectedCb = url => {
                    messageInputField.text += "\n" + url
                    if (root.isEdit) {
                        messageInputField.forceActiveFocus()
                        return
                    }

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

            mentionButton.checked: !suggestionsBox.shouldHide && messageInputField.enteringSuggestion

            mentionButton.onClicked: {
                if (mentionButton.checked) {
                    suggestionsBox.shouldHide = false

                    if (!messageInputField.enteringSuggestion)
                        messageInputField.insert(messageInputField.length, "@")
                } else {
                    suggestionsBox.shouldHide = true
                }
            }
        }
    }
}
