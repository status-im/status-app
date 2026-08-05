import QtQuick
import QtTest

import StatusQ.Core.Utils as SQUtils

import utils

import mainui

Item {
    id: root

    width: 500
    height: 600

    // Self-contained 1x1 PNGs standing in for the cached file paths the share
    // intake delivers (no filesystem dependency, no Image load warnings).
    // Distinct pixels because the chat input deduplicates identical entries.
    readonly property string redImage:
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
    readonly property string greenImage:
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC"
    readonly property string blueImage:
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC"

    Component {
        id: testComponent

        SharePreviewPanel {
            anchors.fill: parent
            destinationName: "Design crew"
            text: "Look at this https://example.com/article"
        }
    }

    SignalSpy {
        id: sendRequestedSpy
        signalName: "sendRequested"
    }

    SignalSpy {
        id: backRequestedSpy
        signalName: "backRequested"
    }

    SignalSpy {
        id: cancelRequestedSpy
        signalName: "cancelRequested"
    }

    TestCase {
        name: "SharePreviewPanelTest"
        when: windowShown

        function init() {
            sendRequestedSpy.clear()
            backRequestedSpy.clear()
            cancelRequestedSpy.clear()
        }

        function createPreview(properties = {}) {
            const preview = createTemporaryObject(testComponent, root, properties)
            sendRequestedSpy.target = preview
            backRequestedSpy.target = preview
            cancelRequestedSpy.target = preview
            waitForRendering(preview)
            return preview
        }

        // The chat input emits rich text; compare via its plain-text form,
        // like the send pipeline does.
        function plainText(text) {
            return SQUtils.StringUtils.plainText(text)
        }

        function test_prefillsChatInputWithSharedText() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            compare(chatInput.getPlainText(),
                    "Look at this https://example.com/article")
        }

        function test_sendEmitsEditedText() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(chatInput)
            verify(sendButton)
            verify(sendButton.enabled)

            chatInput.setText("Edited before sending")
            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(plainText(sendRequestedSpy.signalArguments[0][0]),
                    "Edited before sending")
            compare(sendRequestedSpy.signalArguments[0][1].length, 0)
        }

        function test_sendNotEmittedOnBlankText() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(chatInput)
            verify(sendButton)

            chatInput.setText("   ")
            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 0)
        }

        function test_sendDisabledOnEmptyInput() {
            const preview = createPreview({ text: "" })
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(sendButton)

            verify(!sendButton.enabled)
        }

        function test_backEmitsIntent() {
            const preview = createPreview()
            const backButton = findChild(preview, "sharePreviewBackButton")
            verify(backButton)

            mouseClick(backButton)

            compare(backRequestedSpy.count, 1)
            compare(sendRequestedSpy.count, 0)
        }

        function test_cancelEmitsIntent() {
            const preview = createPreview()
            const cancelButton = findChild(preview, "sharePreviewCancelButton")
            verify(cancelButton)

            mouseClick(cancelButton)

            compare(cancelRequestedSpy.count, 1)
            compare(sendRequestedSpy.count, 0)
        }

        function test_sharedImagesAttachedToInput() {
            const preview = createPreview({
                imagePaths: [root.redImage, root.greenImage, root.blueImage]
            })
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            compare(chatInput.fileUrlsAndSources.length, 3)
            verify(chatInput.isImage)
        }

        function test_noImagesAttachedForTextShare() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            compare(chatInput.fileUrlsAndSources.length, 0)
            verify(!chatInput.isImage)
        }

        function test_sendEnabledWithImagesAndBlankCaption() {
            const preview = createPreview({
                text: "",
                imagePaths: [root.redImage]
            })
            const chatInput = findChild(preview, "statusChatInput")
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(chatInput)
            verify(sendButton)
            verify(sendButton.enabled)

            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(plainText(sendRequestedSpy.signalArguments[0][0]).trim(), "")
            compare(sendRequestedSpy.signalArguments[0][1].length, 1)
            compare(sendRequestedSpy.signalArguments[0][1][0], root.redImage)
        }

        function test_sendConvertsSingleSlashFileUrlToPlainPath() {
            // Real file needed: the image validator sniffs content.
            const absPath = Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/qr-scan-success.png")
                              .toString().slice("file://".length)
            const preview = createPreview({ text: "" })
            const chatInput = findChild(preview, "statusChatInput")
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(chatInput)

            chatInput.selectImageString("file:" + absPath)
            compare(chatInput.fileUrlsAndSources.length, 1)

            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(sendRequestedSpy.signalArguments[0][1][0], absPath)
        }

        function test_sendWithImagesEmitsEditedCaption() {
            const preview = createPreview({
                imagePaths: [root.redImage, root.greenImage]
            })
            const chatInput = findChild(preview, "statusChatInput")
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(chatInput)
            verify(sendButton)

            chatInput.setText("Gallery caption")
            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(plainText(sendRequestedSpy.signalArguments[0][0]),
                    "Gallery caption")
            compare(sendRequestedSpy.signalArguments[0][1].length, 2)
        }

        function test_sendCarriesOnlyRemainingImagesAfterRemoval() {
            const preview = createPreview({
                imagePaths: [root.redImage, root.greenImage]
            })
            const chatInput = findChild(preview, "statusChatInput")
            const sendButton = findChild(preview, "statusChatInputSendButton")
            verify(chatInput)
            verify(sendButton)
            compare(chatInput.fileUrlsAndSources.length, 2)

            // Mirrors what the input's per-image close button does; the click
            // handling itself belongs to StatusChatInput's own tests.
            const urls = [...chatInput.fileUrlsAndSources]
            urls.splice(0, 1)
            chatInput.fileUrlsAndSources = urls

            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(sendRequestedSpy.signalArguments[0][1].length, 1)
            compare(sendRequestedSpy.signalArguments[0][1][0], root.greenImage)
        }

        function test_hostPropertyWritesReapplySharedPayload() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            preview.text = "Replacement share"
            preview.imagePaths = [root.blueImage]

            compare(chatInput.getPlainText(), "Replacement share")
            compare(chatInput.fileUrlsAndSources.length, 1)
        }

        function test_headerShowsDestinationIdentity() {
            const preview = createPreview({
                destinationName: "design",
                destinationColor: "#ff0000",
                destinationEmoji: "⚽",
                destinationChatType: Constants.chatType.communityChat,
                destinationSectionName: "Design DAO"
            })
            const infoButton = findChild(preview, "sharePreviewChatInfoButton")
            verify(infoButton)

            compare(infoButton.title, "design")
            compare(infoButton.subTitle, "Design DAO")
            compare(infoButton.asset.color.toString(), "#ff0000")
            compare(infoButton.asset.emoji, "⚽")
        }

        function test_headerHidesSectionSubtitleForNonCommunityChat() {
            const preview = createPreview({
                destinationName: "Alice",
                destinationChatType: Constants.chatType.oneToOne,
                destinationSectionName: "Messages"
            })
            const infoButton = findChild(preview, "sharePreviewChatInfoButton")
            verify(infoButton)

            compare(infoButton.subTitle, "")
        }

        function test_inputFillsHeightBelowHeader() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            // The input reaches the panel's bottom (no dead spacer above a
            // bottom-anchored input)...
            const inputBottom = chatInput.mapToItem(preview, 0,
                                                    chatInput.height).y
            fuzzyCompare(inputBottom, preview.height, 1)

            // ...and stretches over the whole space below the header instead
            // of keeping its compact in-chat height
            verify(chatInput.height > preview.height / 2)
        }

        function test_inputAutoFocusedWhenShown() {
            const preview = createPreview()
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            tryVerify(() => chatInput.textInput.activeFocus)

            // Leaving and re-entering the preview step (the share flow hosts
            // the panel in a StackLayout, which toggles visibility) focuses
            // the input again — even after another step's control took the
            // focus in between, like the picker's search box does
            preview.visible = false
            root.forceActiveFocus()
            verify(!chatInput.textInput.activeFocus)
            preview.visible = true
            tryVerify(() => chatInput.textInput.activeFocus)
        }

        function test_resetReappliesUnchangedSharedPayload() {
            const preview = createPreview({
                imagePaths: [root.redImage]
            })
            const chatInput = findChild(preview, "statusChatInput")
            verify(chatInput)

            // The user edits the text and detaches the image, then a new share
            // with the identical payload restarts the flow (last-wins).
            chatInput.setText("Edited by the user")
            chatInput.fileUrlsAndSources = []

            preview.reset()

            compare(chatInput.getPlainText(),
                    "Look at this https://example.com/article")
            compare(chatInput.fileUrlsAndSources.length, 1)
        }
    }
}
