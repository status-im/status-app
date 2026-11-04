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
            verify(part.textField instanceof ChatTextItem)
            return part
        }
        function linkSpy(part) {
            const spy = createTemporaryObject(spyComponent, root,
                {target: part, signalName: "linkActivated"})
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
            part.messageDetails.messageContent = "stale server content"
            part.messageDetails.mentionsMap = ({[root.pubKey]: "Alice"})
            part.messageDetails.unparsedText = "**Hello** @" + root.pubKey + "\n`<tag>&`"
            const field = part.textField
            field.selectAll()
            compare(part.selectedText, "Hello @Alice\n<tag>&")
            compare(field.text, "Hello @Alice\n<tag>&")
            compare(field.Accessible.name, field.text)
            compare(field.Accessible.role, Accessible.StaticText)
            verify(field.segments.some(segment => segment.bold && segment.text === "Hello"))
            verify(field.segments.some(segment => segment.code && segment.text === "<tag>&"))
            part.isEdited = true
            field.selectAll()
            compare(part.selectedText, "Hello @Alice\n<tag>& (edited)")
            compare(field.Accessible.name, "Hello @Alice\n<tag>& (edited)")
            compare(field.text, field.Accessible.name)
            part.isEdited = false
            verify(field.text.indexOf("(edited)") < 0)
        }

        function test_themeAndEmojiSettings() {
            const part = createPart()
            const field = part.textField
            compare(field.appearance.font.family, Fonts.baseFont.family)
            compare(field.appearance.font.pixelSize, Theme.primaryTextFontSize)
            compare(field.appearance.color, Theme.palette.directColor1)
            compare(field.appearance.linkColor, Theme.palette.primaryColor1)
            compare(field.appearance.hoverHighlightColor, Theme.palette.primaryColor3)
            compare(field.appearance.codeFontFamily, Fonts.codeFont.family)
            compare(field.appearance.codeBackground, Theme.palette.baseColor4)
            compare(field.appearance.codeBorderColor, Theme.palette.baseColor2)
            compare(field.appearance.quoteBarColor, Theme.palette.baseColor1)
            compare(field.appearance.editedMarkerFontSize, Theme.tertiaryTextFontSize)
            compare(field.appearance.editedMarkerColor, Theme.palette.baseColor1)
            compare(field.appearance.emojiOnlyPixelSize, Math.round(field.appearance.font.pixelSize * 2.2))
            part.messageDetails.unparsedText = "😎"
            verify(field.emojiOnly)
            part.isEdited = true
            verify(field.emojiOnly)
            part.messageDetails.unparsedText = "**😎**"
            compare(field.emojiOnly, false)
            part.messageDetails.mentionsMap = ({[root.pubKey]: "Alice"})
            part.messageDetails.unparsedText = "> quoted\n\n@" + root.pubKey
            const quoted = field.segments.find(segment => segment.quoteLevel > 0)
            const mention = field.segments.find(segment => segment.href === root.pubKey)
            verify(quoted.quoteLevel > 0)
            compare(field.appearance.quoteColor, Theme.palette.baseColor1)
            verify(mention.mention)
            compare(field.appearance.mentionColor, Theme.palette.primaryColor1)
            compare(field.appearance.mentionBackground, Theme.palette.baseColor2)
        }

        function test_themeChangesDoNotReparseSegments() {
            const part = createPart()
            const field = part.textField
            part.messageDetails.unparsedText = "> quote @" + root.pubKey
            const spy = createTemporaryObject(spyComponent, root, {target: field, signalName: "segmentsChanged"})
            field.selectAll()
            const selected = field.selectedText
            for (const style of [Theme.Style.Dark, Theme.Style.Light]) {
                part.Theme.style = style
                compare(field.appearance.quoteColor, part.Theme.palette.baseColor1)
                compare(field.appearance.mentionColor, part.Theme.palette.primaryColor1)
                compare(field.appearance.mentionBackground, part.Theme.palette.baseColor2)
                compare(field.selectedText, selected)
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
            compare(part.textField.selectable, !data.mobile)
            const spy = linkSpy(part)
            activate(part.textField, linkPoint(part.textField, hrefs[data.kind]), data.device)
            const blocked = data.disabled && (data.kind === "address" || data.kind === "ens")
            compare(spy.count, blocked ? 0 : 1)
            if (!blocked)
                compare(spy.signalArguments[0][0], data.kind === "mention" ? "//" + root.pubKey : hrefs[data.kind])
            compare(part.selectedText, "")
        }

        function test_everyoneIsNotActionable() {
            const part = createPart()
            part.messageDetails.unparsedText = "@0x00001"
            const field = part.textField
            const spy = linkSpy(part)
            compare(field.segments[0].text, "@everyone")
            compare(field.linkAt(10, 11), "")
            activate(field, Qt.point(10, 11), "mouse")
            activate(field, Qt.point(10, 11), "touch")
            compare(spy.count, 0)
            field.selectAll()
            compare(part.selectedText, "@everyone")
        }

        function test_hoverHighlightAndDisabledTooltip() {
            const part = createPart()
            part.messageDetails.unparsedText = root.address
            const field = part.textField
            const href = "//send-via-personal-chat//" + root.address
            const point = linkPoint(field, href)
            const tooltip = findChild(part, "StatusTextMessage_disabledLinkTooltip")
            verify(!!tooltip)
            mouseMove(root, 790, 790)
            mouseMove(field, point.x, point.y)
            compare(part.hoveredLink, href)
            compare(tooltip.visible, false)
            part.disabledTooltipText = "Not available"
            tryCompare(tooltip, "visible", true)
            compare(tooltip.text, "Not available")
            part.highlightedLink = href
            compare(field.highlightedLink, href)
            part.disabledTooltipText = ""
            tryCompare(tooltip, "visible", false)
            mouseMove(root, 790, 790)
            compare(part.hoveredLink, "")
            compare(field.highlightedLink, href)
        }

        function test_focusPolicyAndMobileToggle() {
            const part = createPart()
            const field = part.textField
            field.forceActiveFocus()
            field.selectAll()
            focusSink.forceActiveFocus()
            compare(part.selectedText, "")
            part.clearSelectionOnLostFocus = false
            compare(field.persistentSelection, true)
            field.forceActiveFocus()
            field.selectAll()
            focusSink.forceActiveFocus()
            compare(part.selectedText, "hello")
            part.clearSelectionOnLostFocus = true
            compare(field.persistentSelection, false)
            field.forceActiveFocus()
            focusSink.forceActiveFocus()
            compare(part.selectedText, "")
            field.forceActiveFocus()
            field.selectAll()
            part.isMobile = true
            compare(field.selectable, false)
            compare(part.selectedText, "")
            part.isMobile = false
            compare(field.selectable, true)
        }

        function test_showMoreAndAllowShowMore() {
            const part = createPart()
            part.messageDetails.unparsedText = Array(30).fill("line").join("\n")
            const field = part.textField
            const loader = findChild(part, "StatusTextMessage_showMore")
            verify(!!loader)
            tryCompare(loader, "active", true)
            tryVerify(() => !!loader.item && loader.height > 0)
            verify(field.implicitHeight > 200)
            compare(field.effectiveHeight, 200)
            const collapsedHeight = part.implicitHeight
            mouseClick(loader.item, loader.item.width / 2, loader.item.height / 2)
            compare(field.effectiveHeight, field.implicitHeight)
            verify(part.implicitHeight > collapsedHeight)
            mouseClick(loader.item, loader.item.width / 2, loader.item.height / 2)
            compare(field.effectiveHeight, 200)
            part.allowShowMore = false
            compare(loader.active, false)
            compare(field.effectiveHeight, field.implicitHeight)
            compare(part.implicitHeight, field.implicitHeight)
            part.messageDetails.unparsedText = "short"
            compare(loader.active, false)
            compare(part.implicitHeight, field.implicitHeight)
        }

        function test_emptySourceCollapsesBody() {
            const part = createPart()
            part.textField.selectAll()
            part.messageDetails.unparsedText = ""
            compare(part.selectedText, "")
            compare(part.textField.contentHeight, 0)
            compare(part.implicitHeight, 0)
            compare(part.textField.text, "")
        }

        function test_detailsReplacementClearsInteraction() {
            const part = createPart()
            part.messageDetails.unparsedText = "https://status.app"
            const field = part.textField
            const point = linkPoint(field, "https://status.app")
            field.hoverAt(point.x, point.y)
            field.forceActiveFocus()
            field.selectAll()
            const details = createTemporaryObject(detailsComponent, root,
                {unparsedText: "replacement"})
            part.messageDetails = details
            compare(part.selectedText, "")
            compare(part.hoveredLink, "")
            compare(field.text, "replacement")
            field.selectAll()
            compare(part.selectedText, "replacement")
        }

        function test_statusMessageForwardsTextStateAndPalette() {
            const message = createTemporaryObject(messageComponent, root)
            verify(!!message)
            verify(waitForPolish(message))
            const part = findChild(message, "StatusMessage_textMessage")
            verify(!!part)
            const field = part.textField
            verify(field instanceof ChatTextItem)
            compare(field.appearance.selectionColor, message.palette.highlight)
            compare(field.appearance.selectionTextColor, message.palette.highlightedText)
            message.palette.highlight = "red"
            compare(field.appearance.selectionColor, Qt.color("red"))
            field.selectAll()
            compare(message.selectedText, "hello")
            message.clearSelectionOnLostFocus = false
            compare(field.persistentSelection, true)
            message.highlightedLink = "https://status.app"
            compare(field.highlightedLink, "https://status.app")
            message.messageDetails.unparsedText = "https://status.app"
            const point = linkPoint(field, "https://status.app")
            field.hoverAt(point.x, point.y)
            compare(message.hoveredLink, "https://status.app")
            const spy = linkSpy(message)
            activate(field, point, "mouse")
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "https://status.app")
            message.isInPinnedPopup = true
            compare(part.allowShowMore, false)
            tryCompare(field, "width", part.width - Theme.xlPadding)
        }
    }
}
