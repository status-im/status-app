import QtQuick
import QtTest

import utils

import StatusQ.Core.Utils as SQUtils

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

        ShareComposer {
            width: 360
            text: "Look at this https://example.com/article"
        }
    }

    SignalSpy {
        id: sendSpy
        signalName: "sendRequested"
    }

    TestCase {
        name: "ShareComposer"
        when: windowShown

        function init() {
            sendSpy.clear()
        }

        function create(properties = {}) {
            const drawer = createTemporaryObject(testComponent, root, properties)
            sendSpy.target = drawer
            waitForRendering(drawer)
            return drawer
        }

        // The chat input emits rich text; compare via its plain-text form,
        // like the send pipeline does.
        function plainText(text) {
            return SQUtils.StringUtils.plainText(text)
        }

        function test_prefillsChatInputWithSharedText() {
            const drawer = create()
            compare(findChild(drawer, "statusChatInput").getPlainText(),
                    "Look at this https://example.com/article")
        }

        function test_sendEmitsEditedTextAndRemainingImages() {
            const drawer = create({ imagePaths: [root.redImage, root.greenImage] })
            const chatInput = findChild(drawer, "statusChatInput")
            tryCompare(chatInput.fileUrlsAndSources, "length", 2)
            chatInput.setText("Edited")
            mouseClick(findChild(drawer, "statusChatInputSendButton"))
            compare(sendSpy.count, 1)
            compare(plainText(sendSpy.signalArguments[0][0]), "Edited")
            compare(sendSpy.signalArguments[0][1].length, 2)
        }

        function test_sendBlockedOnBlankTextWithoutImages() {
            const drawer = create()
            const chatInput = findChild(drawer, "statusChatInput")
            chatInput.setText("   ")
            chatInput.tryFinalizeMessage()
            compare(sendSpy.count, 0)
        }

        function test_imagesWithBlankCaptionCanBeSent() {
            const drawer = create({ text: "", imagePaths: [root.blueImage] })
            const chatInput = findChild(drawer, "statusChatInput")
            tryCompare(chatInput.fileUrlsAndSources, "length", 1)
            mouseClick(findChild(drawer, "statusChatInputSendButton"))
            compare(sendSpy.count, 1)
        }

        function test_sendConvertsSingleSlashFileUrlToPlainPath() {
            // Real file needed: the image validator sniffs content.
            const absPath = Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/qr-scan-success.png")
                              .toString().slice("file://".length)
            const drawer = create({ text: "" })
            const chatInput = findChild(drawer, "statusChatInput")
            chatInput.selectImageString("file:" + absPath)
            compare(chatInput.fileUrlsAndSources.length, 1)
            mouseClick(findChild(drawer, "statusChatInputSendButton"))
            compare(sendSpy.count, 1)
            compare(sendSpy.signalArguments[0][1][0], absPath)
        }

        function test_moreThanSixImagesStayAttached() {
            // The share fan-out splits sends into 6-image messages, so the
            // composer must not cap attachments like the in-chat input does.
            const names = ["backup-popup", "qr-scan-success", "status-gradient-dot", "status-logo-circle",
                           "status-logo-dev-circle", "status-logo-icon", "status-logo"]
            const paths = names.map(n => Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/" + n + ".png")
                                          .toString().slice("file://".length))
            const drawer = create({ text: "", imagePaths: paths })
            const chatInput = findChild(drawer, "statusChatInput")
            tryCompare(chatInput.fileUrlsAndSources, "length", 7)
            mouseClick(findChild(drawer, "statusChatInputSendButton"))
            compare(sendSpy.count, 1)
            compare(sendSpy.signalArguments[0][1].length, 7)
        }

        function test_cappedComposerKeepsOnlyMaxUploadFilesImages() {
            const names = ["backup-popup", "qr-scan-success", "status-gradient-dot", "status-logo-circle",
                           "status-logo-dev-circle", "status-logo-icon", "status-logo"]
            const paths = names.map(n => Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/" + n + ".png")
                                          .toString().slice("file://".length))
            const drawer = create({ text: "", imagePaths: paths, unlimitedImages: false })
            const chatInput = findChild(drawer, "statusChatInput")
            compare(chatInput.maxImages, Constants.maxUploadFiles)
            tryCompare(chatInput.fileUrlsAndSources, "length", Constants.maxUploadFiles)
        }

        function test_sendEnabledFalseDisablesSendButton() {
            const drawer = create({ sendEnabled: false })
            const sendButton = findChild(drawer, "statusChatInputSendButton")
            verify(!sendButton.enabled)
            drawer.sendEnabled = true
            tryVerify(() => sendButton.enabled)
        }

        function test_resetReappliesPayload() {
            const drawer = create()
            const chatInput = findChild(drawer, "statusChatInput")
            chatInput.setText("typed over")
            drawer.reset()
            compare(chatInput.getPlainText(), "Look at this https://example.com/article")
        }

        function test_gifStickerAndPaymentButtonsHidden() {
            const drawer = create()
            const chatInput = findChild(drawer, "statusChatInput")
            verify(!chatInput.gifButtonVisible)
            verify(!chatInput.stickersButtonVisible)
            verify(!chatInput.paymentRequestButtonVisible)
        }
    }
}
