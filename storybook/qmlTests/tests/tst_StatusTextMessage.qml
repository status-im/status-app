import QtQuick
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import "../../../ui/StatusQ/src/StatusQ/Components/private/statusMessage" as MessageParts

Item {
    id: root
    width: 800
    height: 800
    readonly property string pubKey: "0x" + "c".repeat(130)
    readonly property string address: "0x" + "a".repeat(40)
    Item { id: focusSink; x: 750; width: 10; height: 10 }

    Component {
        id: partComponent
        MessageParts.StatusTextMessage {
            id: part
            appearance: MessageTextAppearance { theme: part.Theme }
            width: 480
            messageDetails: StatusMessageDetails { unparsedText: "hello" }
        }
    }
    Component {
        id: messageComponent
        StatusMessage {
            id: message
            textAppearance: MessageTextAppearance {
                theme: message.Theme
                selectionPalette: message.palette
            }
            previewAppearance: ReplyTextAppearance {
                theme: message.Theme
                selectionPalette: message.palette
            }
            width: 600
            showHeader: false
            messageDetails: StatusMessageDetails {
                contentType: StatusMessage.ContentType.Text
                unparsedText: "hello"
            }
        }
    }
    Component { id: detailsComponent; StatusMessageDetails {} }
    Component { id: spyComponent; SignalSpy {} }

    TestCase {
        name: "StatusTextMessage"
        when: windowShown

        function createPart(properties) {
            const part = createTemporaryObject(partComponent, root, properties || {})
            verify(!!part)
            verify(waitForPolish(part))
            verify(part instanceof ChatTextItem)
            return part
        }
        function linkSpy(target, signalName) {
            const spy = createTemporaryObject(spyComponent, root,
                {target: target, signalName: signalName || "messageLinkActivated"})
            verify(!!spy && spy.valid)
            return spy
        }
        function linkPoint(field, href) {
            for (let y = 5; y < field.contentHeight; y += 5) {
                for (let x = 2; x < field.width; x += 3) {
                    if (field.linkAt(x, y) === href)
                        return Qt.point(x, y)
                }
            }
            fail("No rendered anchor for " + href)
            return Qt.point(0, 0)
        }
        function activate(field, point, device) {
            if (device === "touch") {
                const touch = touchEvent(field)
                touch.press(0, field, point.x, point.y).commit()
                touch.release(0, field, point.x, point.y).commit()
            } else {
                mouseClick(field, point.x, point.y)
            }
        }

        function test_sourceAccessibilityAndEditedMarker() {
            const part = createPart()
            // CI may have accessibility inactive. Attach explicitly before
            // content updates so the test exercises accessible-name updates.
            part.Accessible.role = Accessible.StaticText
            part.messageDetails.messageContent = "stale server content"
            part.messageDetails.mentionsMap = ({[root.pubKey]: "Alice"})
            part.messageDetails.unparsedText = "**Hello** @" + root.pubKey + "\n`<tag>&`"
            part.selectAll()
            compare(part.selectedText, "Hello @Alice\n<tag>&")
            compare(part.text, "Hello @Alice\n<tag>&")
            compare(part.Accessible.name, part.text)
            verify(part.segments.some(segment => segment.bold && segment.text === "Hello"))
            verify(part.segments.some(segment => segment.code && segment.text === "<tag>&"))
            part.isEdited = true
            part.selectAll()
            compare(part.selectedText, "Hello @Alice\n<tag>& (edited)")
            compare(part.Accessible.name, "Hello @Alice\n<tag>& (edited)")
            compare(part.text, part.Accessible.name)
            part.isEdited = false
            verify(part.text.indexOf("(edited)") < 0)
        }

        function test_themeAndEmojiSettings() {
            const part = createPart()
            compare(part.appearance.font.family, Fonts.baseFont.family)
            compare(part.appearance.font.pixelSize, Theme.primaryTextFontSize)
            compare(part.appearance.color, Theme.palette.directColor1)
            compare(part.appearance.linkColor, Theme.palette.primaryColor1)
            compare(part.appearance.hoverHighlightColor, Theme.palette.primaryColor3)
            compare(part.appearance.codeFontFamily, Fonts.codeFont.family)
            compare(part.appearance.codeBackground, Theme.palette.baseColor4)
            compare(part.appearance.codeBorderColor, Theme.palette.baseColor2)
            compare(part.appearance.quoteBarColor, Theme.palette.baseColor1)
            compare(part.appearance.editedMarkerFontSize, Theme.tertiaryTextFontSize)
            compare(part.appearance.editedMarkerColor, Theme.palette.baseColor1)
            compare(part.appearance.emojiOnlyPixelSize, Math.round(part.appearance.font.pixelSize * 2.2))
            part.messageDetails.unparsedText = "😎"
            verify(part.emojiOnly)
            part.isEdited = true
            verify(part.emojiOnly)
            part.messageDetails.unparsedText = "**😎**"
            compare(part.emojiOnly, false)
            part.messageDetails.mentionsMap = ({[root.pubKey]: "Alice"})
            part.messageDetails.unparsedText = "> quoted\n\n@" + root.pubKey
            const quoted = part.segments.find(segment => segment.quoteLevel > 0)
            const mention = part.segments.find(segment => segment.href === root.pubKey)
            verify(quoted.quoteLevel > 0)
            compare(part.appearance.quoteColor, Theme.palette.baseColor1)
            verify(mention.mention)
            compare(part.appearance.mentionColor, Theme.palette.primaryColor1)
            compare(part.appearance.mentionBackground, Theme.palette.baseColor2)
        }

        function test_themeChangesDoNotReparseSegments() {
            const part = createPart()
            part.messageDetails.unparsedText = "> quote @" + root.pubKey
            const spy = createTemporaryObject(spyComponent, root, {target: part, signalName: "segmentsChanged"})
            part.selectAll()
            const selected = part.selectedText
            for (const style of [Theme.Style.Dark, Theme.Style.Light]) {
                part.Theme.style = style
                compare(part.appearance.quoteColor, part.Theme.palette.baseColor1)
                compare(part.appearance.mentionColor, part.Theme.palette.primaryColor1)
                compare(part.appearance.mentionBackground, part.Theme.palette.baseColor2)
                compare(part.selectedText, selected)
                compare(spy.count, 0)
            }
        }

        function test_activation_data() {
            const cases = []
            for (const mobile of [false, true]) {
                for (const device of ["mouse", "touch"]) {
                    for (const disabled of [false, true]) {
                        for (const kind of ["url", "mention", "address", "ens"]) {
                            cases.push({tag: [mobile, device, disabled, kind].join("-"),
                                mobile: mobile, device: device, disabled: disabled, kind: kind})
                        }
                    }
                }
            }
            return cases
        }
        function test_activation(data) {
            const part = createPart({isMobile: data.mobile,
                                    disabledTooltipText: data.disabled ? "Not available" : ""})
            const sources = {url: "https://status.app", mention: "@" + root.pubKey,
                             address: root.address, ens: "alice.eth"}
            const hrefs = {url: "https://status.app", mention: root.pubKey,
                           address: "//send-via-personal-chat//" + root.address,
                           ens: "//send-via-personal-chat//alice.eth"}
            part.messageDetails.mentionsMap = ({[root.pubKey]: "Alice"})
            part.messageDetails.unparsedText = sources[data.kind]
            compare(part.selectable, !data.mobile)
            const spy = linkSpy(part)
            activate(part, linkPoint(part, hrefs[data.kind]), data.device)
            const blocked = data.disabled && (data.kind === "address" || data.kind === "ens")
            compare(spy.count, blocked ? 0 : 1)
            if (!blocked)
                compare(spy.signalArguments[0][0], data.kind === "mention" ? "//" + root.pubKey : hrefs[data.kind])
            compare(part.selectedText, "")
        }

        function test_everyoneIsNotActionable() {
            const part = createPart()
            part.messageDetails.unparsedText = "@0x00001"
            const spy = linkSpy(part)
            compare(part.segments[0].text, "@everyone")
            compare(part.linkAt(10, 11), "")
            activate(part, Qt.point(10, 11), "mouse")
            activate(part, Qt.point(10, 11), "touch")
            compare(spy.count, 0)
            part.selectAll()
            compare(part.selectedText, "@everyone")
        }

        function test_hoverHighlightAndDisabledTooltip() {
            mouseMove(root, 790, 790)
            const part = createPart()
            part.messageDetails.unparsedText = root.address
            const href = "//send-via-personal-chat//" + root.address
            const point = linkPoint(part, href)
            const loader = findChild(part, "StatusTextMessage_disabledLinkTooltipLoader")
            verify(!!loader)
            compare(loader.item, null)
            compare(findChild(part, "StatusTextMessage_disabledLinkTooltip"), null)
            mouseMove(part, point.x, point.y)
            compare(part.hoveredLink, href)
            compare(loader.item, null)
            part.disabledTooltipText = "Not available"
            tryVerify(() => !!loader.item)
            const tooltip = loader.item
            compare(findChild(part, "StatusTextMessage_disabledLinkTooltip"), tooltip)
            compare(tooltip.parent, part)
            compare(tooltip.delay, 100)
            compare(tooltip.opened, false)
            tryCompare(tooltip, "visible", true)
            tryCompare(tooltip, "opened", true)
            compare(tooltip.text, "Not available")
            part.highlightedLink = href
            compare(part.highlightedLink, href)
            part.disabledTooltipText = ""
            tryCompare(tooltip, "visible", false)
            mouseMove(root, 790, 790)
            compare(part.hoveredLink, "")
            compare(part.highlightedLink, href)
            compare(loader.item, tooltip)
            part.disabledTooltipText = "Another reason"
            compare(tooltip.visible, false)
            mouseMove(part, point.x, point.y)
            tryCompare(tooltip, "opened", true)
            compare(loader.item, tooltip)
            compare(tooltip.text, "Another reason")
            mouseMove(root, 790, 790)
            tryCompare(tooltip, "visible", false)
        }

        function test_disabledTooltipOnlyForWalletLinks_data() {
            return [
                {tag: "plain", source: "hello", href: "", wallet: false},
                {tag: "url", source: "https://status.app", href: "https://status.app", wallet: false},
                {tag: "mention", source: "@" + root.pubKey, href: root.pubKey, wallet: false},
                {tag: "address", source: root.address, href: "//send-via-personal-chat//" + root.address,
                 wallet: true},
                {tag: "ens", source: "alice.eth", href: "//send-via-personal-chat//alice.eth", wallet: true}
            ]
        }
        function test_disabledTooltipOnlyForWalletLinks(data) {
            mouseMove(root, 790, 790)
            const part = createPart({disabledTooltipText: "Not available"})
            part.messageDetails.mentionsMap = ({[root.pubKey]: "Alice"})
            part.messageDetails.unparsedText = data.source
            const loader = findChild(part, "StatusTextMessage_disabledLinkTooltipLoader")
            compare(loader.item, null)
            const point = data.href ? linkPoint(part, data.href) : Qt.point(5, 11)
            mouseMove(part, point.x, point.y)
            if (data.wallet) {
                tryVerify(() => !!loader.item && loader.item.opened)
                compare(loader.item.text, "Not available")
                mouseMove(part, part.width - 5, point.y)
                tryCompare(loader.item, "visible", false)
            } else {
                wait(150)
                compare(loader.item, null)
            }
            mouseMove(root, 790, 790)
        }

        function test_touchDoesNotCreateDisabledTooltip() {
            mouseMove(root, 790, 790)
            const part = createPart({isMobile: true, disabledTooltipText: "Not available"})
            part.messageDetails.unparsedText = root.address
            const loader = findChild(part, "StatusTextMessage_disabledLinkTooltipLoader")
            const spy = linkSpy(part)
            activate(part, linkPoint(part, "//send-via-personal-chat//" + root.address), "touch")
            compare(spy.count, 0)
            wait(150)
            compare(loader.item, null)
        }

        function test_focusPolicyAndMobileToggle() {
            const part = createPart()
            part.forceActiveFocus()
            part.selectAll()
            focusSink.forceActiveFocus()
            compare(part.selectedText, "")
            part.clearSelectionOnLostFocus = false
            compare(part.persistentSelection, true)
            part.forceActiveFocus()
            part.selectAll()
            focusSink.forceActiveFocus()
            compare(part.selectedText, "hello")
            part.clearSelectionOnLostFocus = true
            compare(part.persistentSelection, false)
            part.forceActiveFocus()
            focusSink.forceActiveFocus()
            compare(part.selectedText, "")
            part.forceActiveFocus()
            part.selectAll()
            part.isMobile = true
            compare(part.selectable, false)
            compare(part.selectedText, "")
            part.isMobile = false
            compare(part.selectable, true)
        }

        function test_longMessageShownInFull() {
            const part = createPart()
            part.messageDetails.unparsedText = Array(30).fill("line").join("\n")
            verify(part.implicitHeight > 200)
            compare(findChild(part, "StatusTextMessage_showMore"), null)
            compare(part.height, part.implicitHeight)
            compare(part.implicitHeight, part.implicitHeight)
            compare(part.clip, false)
            compare(part.layer.enabled, false)
            part.messageDetails.unparsedText = "short"
            compare(part.height, part.implicitHeight)
            compare(part.implicitHeight, part.implicitHeight)
        }

        function test_emptySourceCollapsesBody() {
            const part = createPart()
            part.selectAll()
            part.messageDetails.unparsedText = ""
            compare(part.selectedText, "")
            compare(part.contentHeight, 0)
            compare(part.implicitHeight, 0)
            compare(part.text, "")
        }

        function test_detailsReplacementClearsInteraction() {
            const part = createPart()
            part.messageDetails.unparsedText = "https://status.app"
            const point = linkPoint(part, "https://status.app")
            part.hoverAt(point.x, point.y)
            part.forceActiveFocus()
            part.selectAll()
            const details = createTemporaryObject(detailsComponent, root,
                {unparsedText: "replacement"})
            part.messageDetails = details
            compare(part.selectedText, "")
            compare(part.hoveredLink, "")
            compare(part.text, "replacement")
            part.selectAll()
            compare(part.selectedText, "replacement")
        }

        function test_statusMessageForwardsTextStateAndPalette() {
            const message = createTemporaryObject(messageComponent, root)
            verify(!!message)
            verify(waitForPolish(message))
            const part = findChild(message, "StatusTextMessage_chatText")
            verify(!!part)
            verify(part instanceof ChatTextItem)
            compare(part.appearance.selectionColor, message.palette.highlight)
            compare(part.appearance.selectionTextColor, message.palette.highlightedText)
            message.palette.highlight = "red"
            compare(part.appearance.selectionColor, Qt.color("red"))
            part.selectAll()
            compare(message.selectedText, "hello")
            message.clearSelectionOnLostFocus = false
            compare(part.persistentSelection, true)
            message.highlightedLink = "https://status.app"
            compare(part.highlightedLink, "https://status.app")
            message.messageDetails.unparsedText = "https://status.app"
            // The Loader sizes the text from the message layout on its next polish.
            tryVerify(() => part.height > 0 && part.height === part.implicitHeight)
            const point = linkPoint(part, "https://status.app")
            part.hoverAt(point.x, point.y)
            compare(message.hoveredLink, "https://status.app")
            const spy = linkSpy(message, "linkActivated")
            activate(part, point, "mouse")
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "https://status.app")
            const fullWidth = part.width
            message.isInPinnedPopup = true
            tryCompare(part, "width", fullWidth - Theme.xlPadding)
        }
    }
}
