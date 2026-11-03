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

    SignalSpy {
        id: modalSpy
        signalName: "paymentRequestModalRequested"
    }

    SignalSpy {
        id: removeSpy
        signalName: "paymentRequestRemoveRequested"
    }

    Component {
        id: paymentRequestModelComponent

        ListModel {
            ListElement { receiver: "0xabc"; amount: "1.5"; tokenKey: "eth-key"; symbol: "ETH"; logoUri: "" }
        }
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
            // The send is split into 6-image messages; the composer itself
            // keeps up to the 30-image limit.
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

        // The input deduplicates by string, so "./" segments turn the same
        // few fixture files into as many distinct entries as needed.
        function distinctImagePaths(count) {
            const names = ["backup-popup", "qr-scan-success", "status-gradient-dot", "status-logo-circle",
                           "status-logo-dev-circle", "status-logo-icon", "status-logo"]
            const dir = Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/").toString().slice("file://".length)
            return Array.from({ length: count }, (_, i) =>
                dir + "./".repeat(Math.floor(i / names.length)) + names[i % names.length] + ".png")
        }

        function test_cappedComposerKeepsThirtyImagesAndShowsTheLimit() {
            const drawer = create({ text: "", imagePaths: distinctImagePaths(31) })
            const chatInput = findChild(drawer, "statusChatInput")
            tryCompare(chatInput.fileUrlsAndSources, "length", 30)
            verify(findChild(chatInput, "imageQtyValidator").visible)
        }

        function test_plainPathsAreAttachedAsFileUrls() {
            const plainPath = Qt.resolvedUrl("../../../ui/StatusQ/src/assets/png/status-logo.png")
                                .toString().slice("file://".length)
            const drawer = create({ text: "", imagePaths: [plainPath] })
            const chatInput = findChild(drawer, "statusChatInput")
            tryCompare(chatInput.fileUrlsAndSources, "length", 1)
            compare(chatInput.fileUrlsAndSources[0].toString(), "file://" + plainPath)
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

        function test_gifAndStickerButtonsHidden() {
            const drawer = create()
            const chatInput = findChild(drawer, "statusChatInput")
            verify(!chatInput.gifButtonVisible)
            verify(!chatInput.stickersButtonVisible)
        }

        function test_paymentRequestButtonFollowsFeatureFlagAndTestNetworks() {
            const drawer = create()
            const tokenButton = findChild(drawer, "statusChatInputTokenButton")
            verify(!tokenButton.visible)
            drawer.paymentRequestFeatureEnabled = true
            tryVerify(() => tokenButton.visible)
            drawer.areTestNetworksEnabled = true
            tryVerify(() => !tokenButton.visible)
        }

        function test_paymentRequestButtonAsksHostToOpenTheModal() {
            const drawer = create({ paymentRequestFeatureEnabled: true })
            modalSpy.target = drawer
            modalSpy.clear()
            const tokenButton = findChild(drawer, "statusChatInputTokenButton")
            tryVerify(() => tokenButton.visible)
            mouseClick(tokenButton)
            compare(modalSpy.count, 1)
            compare(typeof modalSpy.signalArguments[0][0], "function")
        }

        function test_paymentRequestPreviewShownAndRemovable() {
            const requests = createTemporaryObject(paymentRequestModelComponent, root)
            const drawer = create({ paymentRequestModel: requests })
            removeSpy.target = drawer
            removeSpy.clear()
            tryVerify(() => !!findChild(drawer, "paymentRequestMiniCard"))
            const card = findChild(drawer, "paymentRequestMiniCard")
            compare(card.symbol, "ETH")
            compare(card.amount, "1.5")
            card.close()
            compare(removeSpy.count, 1)
            compare(removeSpy.signalArguments[0][0], 0)
        }

        function test_paymentRequestPreviewUsesTheHostFormatter() {
            const requests = createTemporaryObject(paymentRequestModelComponent, root)
            const drawer = create({ paymentRequestModel: requests,
                                    formatBalance: (amount, key) => "formatted " + amount + " " + key })
            tryVerify(() => !!findChild(drawer, "paymentRequestMiniCard"))
            compare(findChild(drawer, "paymentRequestMiniCard").amount, "formatted 1.5 eth-key")
        }

        function test_paymentRequestAloneIsSendable() {
            const requests = createTemporaryObject(paymentRequestModelComponent, root)
            const drawer = create({ text: "", paymentRequestModel: requests })
            const sendButton = findChild(drawer, "statusChatInputSendButton")
            tryVerify(() => sendButton.enabled)
            mouseClick(sendButton)
            compare(sendSpy.count, 1)
            compare(sendSpy.signalArguments[0][1].length, 0)
        }
    }
}
