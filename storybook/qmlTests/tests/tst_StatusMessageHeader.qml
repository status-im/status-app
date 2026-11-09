import QtQuick
import QtTest

import StatusQ
import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils

Item {
    id: root

    width: 640
    height: 300

    readonly property double now: Date.now()
    readonly property double day: 86400000

    StatusMessageHeaderAppearance {
        id: headerAppearance
        theme: root.Theme
    }

    StatusMessageHeaderServices {
        id: headerServices
        theme: root.Theme
    }

    Component {
        id: headerComp

        StatusMessageHeader {
            width: 600
            appearance: headerAppearance
            services: headerServices
            headerData: ({
                senderId: "0x0123456789abcdef",
                displayName: "Alice",
                timestamp: root.now,
                isContact: true
            })
        }
    }

    Component {
        id: clipHostComp
        Item { width: 600; height: 240; clip: true }
    }

    Component {
        id: servicesComp
        StatusMessageHeaderServices { theme: root.Theme }
    }

    Component {
        id: appearanceComp
        StatusMessageHeaderAppearance { theme: root.Theme }
    }

    SignalSpy { id: clickSpy; signalName: "clicked" }
    SignalSpy { id: resendSpy; signalName: "resendClicked" }
    SignalSpy { id: dataSpy; signalName: "headerDataChanged" }
    SignalSpy { id: displaySpy; signalName: "displayDataChanged" }
    SignalSpy { id: accessibleSpy; signalName: "accessibleTextChanged" }

    TestCase {
        name: "StatusMessageHeader"
        when: windowShown

        function init() {
            // Away from where headers are created: a header under the pointer
            // is hovered at once.
            mouseMove(root, root.width - 1, root.height - 1)
            for (const spy of [clickSpy, resendSpy, dataSpy, displaySpy, accessibleSpy]) {
                spy.target = null
                spy.clear()
            }
        }

        function create(props) {
            const header = createTemporaryObject(headerComp, root, props || {})
            verify(!!header)
            return header
        }

        function data(fields) {
            return Object.assign({ senderId: "0x0123456789abcdef", displayName: "Alice",
                                   timestamp: root.now }, fields)
        }

        function partKeys(header) {
            return header.displayData.parts.map(p => p.key)
        }

        function center(rect) {
            return Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2)
        }

        // --- content

        function test_rendersOneItem() {
            const header = create()
            waitForRendering(header)
            compare(header.displayName, "Alice")
            compare(header.children.length, 0, "no child items for an ordinary header: "
                    + header.children.map(c => c.objectName + "/" + c))
            verify(header.implicitHeight > 0)
            verify(header.implicitWidth > 0)
        }

        function test_youForOwnMessages() {
            const header = create({ headerData: data({ amISender: true }) })
            compare(header.displayName, qsTranslate("StatusMessageHeader", "You"))
            // No verification, secondary or tertiary parts for own messages.
            compare(partKeys(header), ["name", "secondDot", "timestamp"])
        }

        function test_incomingParts() {
            const header = create({ headerData: data({ isContact: true, secondaryName: "alice.eth" }) })
            compare(partKeys(header), ["name", "contactIcon", "secondaryName", "firstDot",
                                       "tertiaryDetail", "secondDot", "timestamp"])
            compare(header.displayData.secondaryName, "(alice.eth)")
            compare(header.displayData.tertiaryDetail, Utils.elideText("0x0123456789abcdef", 3, 6))
        }

        function test_tertiaryDetailFallsBackToSenderId() {
            const header = create({ headerData: data({ senderId: "0xabcdef0123456789" }) })
            compare(header.displayData.tertiaryDetail, "0xa…456789")
            header.headerData = data({ senderId: "0xabcdef0123456789", tertiaryDetail: "zq3shabcdefghij" })
            compare(header.displayData.tertiaryDetail, "zq3…efghij")
            // An explicitly empty detail is suppressed, as legacy does.
            header.headerData = data({ tertiaryDetail: "" })
            compare(header.displayData.tertiaryDetail, "")
            verify(partKeys(header).indexOf("tertiaryDetail") < 0)
        }

        function test_originInfoReplacesTertiaryDetail() {
            const header = create({ headerData: data({ messageOriginInfo: "Discord" }) })
            compare(header.displayData.originInfo, "Discord")
            verify(partKeys(header).indexOf("tertiaryDetail") < 0)
        }

        function test_verificationIcons_data() {
            return [
                { tag: "contact", isContact: true, trust: 0, icons: ["contactIcon"], text: "Contact" },
                { tag: "trusted contact", isContact: true, trust: 1, icons: ["trustIcon"], text: "Trusted contact" },
                { tag: "untrusted contact", isContact: true, trust: 2, icons: ["trustIcon", "contactIcon"],
                  text: "Untrusted contact" },
                { tag: "untrusted", isContact: false, trust: 2, icons: ["trustIcon"], text: "Untrusted" },
                { tag: "none", isContact: false, trust: 0, icons: [], text: "" },
            ]
        }

        function test_verificationIcons(row) {
            const header = create({ headerData: data({ isContact: row.isContact, trustIndicator: row.trust }) })
            compare(partKeys(header).filter(k => k.endsWith("Icon")), row.icons)
            compare(header.displayData.verificationText,
                    row.text ? qsTranslate("StatusContactVerificationIcons", row.text) : "")
        }

        function test_displayNameIsPlainText() {
            const header = create({ headerData: data({ displayName: "<b>bob</b> \u{1F600}" }) })
            compare(header.displayName, "<b>bob</b> \u{1F600}")
        }

        // --- publication

        function test_assignmentIsOnePublication() {
            const header = create()
            dataSpy.target = header
            header.headerData = data({ displayName: "Bob", secondaryName: "bob.eth", isContact: true })
            compare(dataSpy.count, 1)
            // An identical snapshot is ignored.
            header.headerData = data({ displayName: "Bob", secondaryName: "bob.eth", isContact: true })
            compare(dataSpy.count, 1)
            compare(header.displayName, "Bob")
        }

        function test_colorChangeKeepsDisplayData() {
            const appearance = createTemporaryObject(appearanceComp, root)
            const header = create({ appearance: appearance })
            waitForRendering(header)
            displaySpy.target = header
            accessibleSpy.target = header
            appearance.nameColor = "red"
            appearance.detailColor = "green"
            header.applyPendingChanges()
            compare(displaySpy.count, 0)
            compare(accessibleSpy.count, 0)
        }

        function test_sharedTextsRetranslate() {
            const appearance = createTemporaryObject(appearanceComp, root)
            const header = create({ appearance: appearance, headerData: data({ amISender: true }) })
            appearance.youText = "Moi"
            compare(header.displayName, "Moi")
        }

        function test_appearanceFallback() {
            const appearance = createTemporaryObject(appearanceComp, root)
            const header = create({ appearance: appearance, headerData: data({ amISender: true }) })
            appearance.youText = "Moi"
            compare(header.displayName, "Moi")
            appearance.destroy()
            wait(0)
            tryCompare(header, "displayName", "You")
        }

        function test_servicesProvideTheAppearance() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services, appearance: null,
                                    headerData: data({ amISender: true }) })
            compare(header.appearance, services.appearance)
            compare(header.displayName, qsTranslate("StatusMessageHeader", "You"))
            services.appearance.youText = "Moi"
            compare(header.displayName, "Moi")

            // Another appearance on the services is followed at once.
            const other = createTemporaryObject(appearanceComp, root)
            other.youText = "Ich"
            services.appearance = other
            compare(header.appearance, other)
            compare(header.displayName, "Ich")

            // The header's own appearance wins over the services'.
            const own = createTemporaryObject(appearanceComp, root)
            own.youText = "Yo"
            header.appearance = own
            compare(header.displayName, "Yo")
            other.youText = "Ignored"
            compare(header.displayName, "Yo")
            header.appearance = null
            compare(header.displayName, "Ignored")

            // Losing the services' appearance falls back to the defaults.
            other.destroy()
            wait(0)
            tryCompare(header, "displayName", "You")
        }

        function test_servicesAppearanceFollowsTheme() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services, appearance: null })
            compare(services.appearance.nameColor, root.Theme.palette.primaryColor1)
            compare(services.appearance.detailFont.pixelSize, root.Theme.tertiaryTextFontSize)
            const height = header.implicitHeight
            root.Theme.fontSizeOffset = 4
            header.applyPendingChanges()
            verify(header.implicitHeight > height)
            root.Theme.fontSizeOffset = undefined // reset
        }

        // --- timestamp

        function test_timestampParity_data() {
            return [
                { tag: "now", age: 0 },
                { tag: "yesterday", age: 1 },
                { tag: "this week", age: 3 },
                { tag: "this year", age: 40 },
                { tag: "older", age: 500 },
            ]
        }

        function test_timestampParity(row) {
            // Noon avoids a day boundary between both computations.
            const noon = new Date(); noon.setHours(12, 0, 0, 0)
            const ts = noon.getTime() - row.age * root.day
            const header = create({ headerData: data({ timestamp: ts }) })
            compare(header.formattedTimestamp, LocaleUtils.formatRelativeTimestamp(ts))
            compare(header.fullTimestamp(), LocaleUtils.formatDateTime(ts))
            header.showFullTimestamp = true
            compare(header.formattedTimestamp, LocaleUtils.formatDateTime(ts))
        }

        function test_timeFormatPreference() {
            const appearance = createTemporaryObject(appearanceComp, root)
            const noon = new Date(); noon.setHours(15, 4, 0, 0)
            const header = create({ appearance: appearance, headerData: data({ timestamp: noon.getTime() }) })
            appearance.timeFormatUsesDefaults = false
            appearance.timeFormatUses24Hours = true
            verify(header.formattedTimestamp.indexOf("15") >= 0, header.formattedTimestamp)
            appearance.timeFormatUses24Hours = false
            verify(header.formattedTimestamp.indexOf("3") >= 0, header.formattedTimestamp)
            verify(header.formattedTimestamp.indexOf("15") < 0, header.formattedTimestamp)
        }

        function test_clockSubscription() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services })
            compare(services.clockSubscriberCount, 1)
            header.visible = false
            compare(services.clockSubscriberCount, 0)
            header.visible = true
            compare(services.clockSubscriberCount, 1)
            header.showFullTimestamp = true
            compare(services.clockSubscriberCount, 0)
            header.showFullTimestamp = false
            header.headerData = data({ timestamp: 0 })
            header.applyPendingChanges()
            compare(services.clockSubscriberCount, 0)
            header.headerData = data()
            header.applyPendingChanges()
            compare(services.clockSubscriberCount, 1)
            header.destroy()
            wait(0)
            compare(services.clockSubscriberCount, 0)
        }

        // --- geometry

        function test_wrapsWhenNarrow() {
            const header = create({ headerData: data({ displayName: "A very long display name that wraps" }) })
            const single = header.implicitHeight
            header.width = 240
            header.applyPendingChanges()
            verify(header.implicitHeight > single, header.implicitHeight + " > " + single)
            header.width = 600
            header.applyPendingChanges()
            compare(header.implicitHeight, single)
        }

        function test_optionalPartTransitionsMatchFreshHeaders_data() {
            const rows = []
            const variants = [
                { isContact: true },
                { isContact: true, trustIndicator: 1, secondaryName: "x.eth" },
                { trustIndicator: 2, messageOriginInfo: "Discord" },
                { secondaryName: "x.eth", messageOriginInfo: "Discord" },
                {},
            ]
            for (const w of [240, 480, 600])
                rows.push({ tag: "width " + w, width: w, variants: variants })
            return rows
        }

        function test_optionalPartTransitionsMatchFreshHeaders(row) {
            const header = create({ width: row.width })
            for (const variant of row.variants) {
                header.headerData = data(variant)
                const fresh = create({ width: row.width, headerData: data(variant) })
                compare(JSON.stringify(header.displayData), JSON.stringify(fresh.displayData))
                compare(header.implicitHeight, fresh.implicitHeight)
                fresh.destroy()
            }
        }

        function test_renderedImageMatchesFreshHeader() {
            const header = create({ headerData: data({ isContact: true, trustIndicator: 2 }) })
            waitForRendering(header)
            header.headerData = data({ secondaryName: "x.eth" })
            waitForRendering(header)
            const reused = grabImage(header)
            header.visible = false
            const fresh = create({ headerData: data({ secondaryName: "x.eth" }) })
            waitForRendering(fresh)
            const image = grabImage(fresh)
            verify(image.equals(reused), "reused header renders like a fresh one")
            fresh.destroy()
        }

        function test_resizeAndHoverDoNotPublishContent() {
            const header = create({ headerData: data({ displayName: "Alice with a long name that wraps onto lines" }) })
            waitForRendering(header)
            const text = header.accessibleText
            const single = header.implicitHeight
            dataSpy.target = header
            accessibleSpy.target = header
            header.width = 240
            header.applyPendingChanges()
            verify(header.implicitHeight > single)
            compare(header.accessibleText, text)
            compare(accessibleSpy.count, 0)

            // Hover changes neither content nor geometry.
            displaySpy.target = header
            const name = center(header.partRect("name"))
            mouseMove(header, name.x, name.y)
            tryCompare(header, "nameHovered", true)
            header.applyPendingChanges()
            mouseMove(root, root.width - 1, root.height - 1)
            tryCompare(header, "nameHovered", false)
            header.applyPendingChanges()
            compare(displaySpy.count, 0)
            compare(accessibleSpy.count, 0)
            compare(dataSpy.count, 0)
        }

        function test_fontChangeRelayouts() {
            const appearance = createTemporaryObject(appearanceComp, root)
            const header = create({ appearance: appearance })
            const height = header.implicitHeight
            const width = header.partRect("name").width
            appearance.nameFont = Qt.font({ family: appearance.nameFont.family, pixelSize: 32,
                                            weight: Font.Medium })
            header.applyPendingChanges()
            verify(header.implicitHeight > height)
            verify(header.partRect("name").width > width)
        }

        // Text replaced by text of the same metrics, in the same or another
        // role, must repaint: node reuse goes by revision, not by geometry.
        function test_replacedTextWithEqualMetricsRepaints() {
            const appearance = createTemporaryObject(appearanceComp, root)
            appearance.youText = "Alice"
            appearance.detailFont = Qt.font({ family: appearance.detailFont.family, pixelSize: 12,
                                              kerning: false })
            const incoming = { displayName: "Alice", senderId: "ABCDEFGHIJ", timestamp: 1700000000000 }
            const own = { amISender: true, messageOriginInfo: "ACB…EFGHIJ", timestamp: 1700000000000 }
            const header = create({ appearance: appearance, displayNameClickable: false, headerData: incoming })
            compare(header.displayData.tertiaryDetail, "ABC…EFGHIJ")
            waitForRendering(header)
            const original = grabImage(header)

            header.headerData = own
            waitForRendering(header)
            const updated = grabImage(header)
            verify(!original.equals(updated), "a changed label must repaint")
            header.visible = false
            const fresh = create({ appearance: appearance, displayNameClickable: false, headerData: own })
            waitForRendering(fresh)
            verify(grabImage(fresh).equals(updated), "matches a fresh header")
            fresh.destroy()
            header.visible = true
            waitForRendering(header)

            // Removal and recreation of parts without a frame in between.
            header.headerData = incoming
            header.applyPendingChanges()
            header.headerData = Object.assign({}, own, { messageOriginInfo: "ABC…EFGHIJ" })
            header.applyPendingChanges()
            waitForRendering(header)
            verify(!updated.equals(grabImage(header)), "recreated parts must not reuse old nodes")
        }

        // The software renderer keeps an inherited position and clip only
        // under transform nodes; rebuilt text must stay inside its header.
        function test_rebuiltTextKeepsParentTransformAndClip() {
            const host = createTemporaryObject(clipHostComp, root)
            const appearance = createTemporaryObject(appearanceComp, root)
            appearance.nameColor = "magenta"
            appearance.detailColor = "lime"
            const header = create({ appearance: appearance, x: 80, y: 80, width: 480,
                                    headerData: data({ amISender: true, timestamp: 1700000000000 }) })
            header.parent = host
            function coloured(image, x0, y0, w, h) {
                let count = 0
                for (let y = y0; y < y0 + h; ++y)
                    for (let x = x0; x < x0 + w; ++x)
                        if (image.alpha(x, y) > 100
                                && ((image.green(x, y) > 200 && image.red(x, y) < 100 && image.blue(x, y) < 100)
                                    || (image.red(x, y) > 200 && image.blue(x, y) > 200 && image.green(x, y) < 100)))
                            ++count
                return count
            }
            function check() {
                header.applyPendingChanges()
                waitForRendering(host)
                const image = grabImage(host)
                verify(coloured(image, 80, 80, 150, 35) > 0, "text stays in its translated header")
                compare(coloured(image, 0, 0, 600, 50), 0, "rebuilt glyphs must not escape to the origin")
            }
            check()
            header.showFullTimestamp = true
            header.width = 240
            check()
            appearance.detailColor = "#00ff00"
            check()
        }

        // --- interaction

        function test_nameClick() {
            const header = create()
            waitForRendering(header)
            clickSpy.target = header
            const name = center(header.partRect("name"))
            mouseClick(header, name.x, name.y)
            compare(clickSpy.count, 1)
            compare(clickSpy.signalArguments[0][0], header)
            const ts = center(header.partRect("timestamp"))
            mouseClick(header, ts.x, ts.y)
            compare(clickSpy.count, 1)
            header.displayNameClickable = false
            mouseClick(header, name.x, name.y)
            compare(clickSpy.count, 1)
        }

        // A reused row must not report a press that began on the previous
        // message as a click on the new sender.
        function test_rebindCancelsPendingNameClick() {
            const header = create()
            waitForRendering(header)
            clickSpy.target = header
            const name = center(header.partRect("name"))
            mousePress(header, name.x, name.y)
            header.headerData = data({ displayName: "Bob" })
            header.applyPendingChanges()
            mouseRelease(header, name.x, name.y)
            compare(clickSpy.count, 0)
            mouseClick(header, name.x, name.y)
            compare(clickSpy.count, 1)
        }

        // As StatusLazyToolTip: a touch never raises a pointer tooltip. A
        // guard: where Qt delivers no hover for touch this holds regardless.
        function test_touchDoesNotOpenTooltip() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services })
            waitForRendering(header)
            const ts = center(header.partRect("timestamp"))
            const touch = touchEvent(header)
            touch.press(0, header, ts.x, ts.y).commit()
            touch.move(0, header, ts.x + 1, ts.y).commit()
            wait(50)
            compare(services.tooltipVisible, false)
            const name = center(header.partRect("name"))
            touch.move(0, header, name.x, name.y).commit()
            wait(50)
            compare(header.nameHovered, false)
            touch.release(0, header, name.x, name.y).commit()
            compare(services.tooltipVisible, false)
        }

        function test_nameHover() {
            const header = create()
            waitForRendering(header)
            const name = center(header.partRect("name"))
            mouseMove(header, name.x, name.y)
            tryCompare(header, "nameHovered", true)
            const ts = center(header.partRect("timestamp"))
            mouseMove(header, ts.x, ts.y)
            tryCompare(header, "nameHovered", false)
        }

        function test_timestampTooltip() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services })
            waitForRendering(header)
            const ts = header.partRect("timestamp")
            mouseMove(header, ts.x + ts.width / 2, ts.y + ts.height / 2)
            tryCompare(services, "tooltipVisible", true)
            compare(services.tooltipHeader, header)
            compare(services.tooltipText, LocaleUtils.formatDateTime(root.now))
            compare(services.tooltipObjectName, "timestampTooltip")
            // The anchor covers the timestamp, as the label it replaces.
            compare(services.tooltipAnchor.parent, header)
            compare(services.tooltipAnchor.x, ts.x)
            compare(services.tooltipAnchor.width, ts.width)

            // Rebinding while hovered shows the new message's time, never the old.
            const older = root.now - 3 * root.day
            header.headerData = data({ timestamp: older })
            header.applyPendingChanges()
            tryCompare(services, "tooltipText", LocaleUtils.formatDateTime(older))

            const name = center(header.partRect("name"))
            mouseMove(header, name.x, name.y)
            tryCompare(services, "tooltipVisible", false)
        }

        function test_tooltipHidesWithHeader() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services })
            waitForRendering(header)
            const ts = center(header.partRect("timestamp"))
            mouseMove(header, ts.x, ts.y)
            tryCompare(services, "tooltipVisible", true)
            header.visible = false
            compare(services.tooltipVisible, false)
            header.visible = true
            mouseMove(header, ts.x + 1, ts.y)
            tryCompare(services, "tooltipVisible", true)
            header.destroy()
            wait(0)
            compare(services.tooltipVisible, false)
            compare(services.tooltipAnchor.parent, null)
        }

        function test_verificationTooltip() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services, headerData: data({ isContact: true }) })
            waitForRendering(header)
            const icon = center(header.partRect("contactIcon"))
            mouseMove(header, icon.x, icon.y)
            tryCompare(services, "tooltipVisible", true)
            compare(services.tooltipText, qsTranslate("StatusContactVerificationIcons", "Contact"))
            compare(services.tooltipObjectName, "verificationIconsTooltip")
        }

        function test_statusLabel() {
            const header = create({ headerData: data({ amISender: true, outgoingStatus: 3 }) })
            compare(header.displayData.statusIcon, "tiny/message/delivered")
            compare(header.displayData.statusLabel, "")
            header.showOutgoingStatusLabel = true
            compare(header.displayData.statusLabel, qsTranslate("StatusMessageHeader", "Delivered"))
            header.headerData = data({ amISender: true, outgoingStatus: 5, resendError: "boom" })
            compare(header.displayData.statusIcon, "tiny/tiny-exclamation")
            compare(header.displayData.statusLabel,
                    qsTranslate("StatusMessageHeader", "Failed to resend: %1").arg("boom"))
        }

        function test_statusFlagSkippedForIncoming() {
            const header = create()
            header.applyPendingChanges()
            displaySpy.target = header
            header.showOutgoingStatusLabel = true
            header.applyPendingChanges()
            compare(displaySpy.count, 0)
        }

        function test_resendButton() {
            const header = create({ headerData: data({ amISender: true, outgoingStatus: 4 }) })
            compare(header.resendButtonItem, null)
            const plain = header.implicitWidth
            header.showOutgoingStatusLabel = true
            header.applyPendingChanges()
            const button = header.resendButtonItem
            verify(!!button)
            compare(button.parent, header)
            verify(button.visible)
            verify(button.width > 0)
            verify(header.implicitWidth > plain + button.width)
            waitForRendering(header)

            resendSpy.target = header
            mouseClick(button)
            compare(resendSpy.count, 1)
            button.forceActiveFocus()
            keyClick(Qt.Key_Space)
            compare(resendSpy.count, 2)

            header.showOutgoingStatusLabel = false
            header.applyPendingChanges()
            compare(header.resendButtonItem, null)
            verify(!button.visible)
        }

        function test_resendButtonOnMobile() {
            const header = create({ isMobile: true, headerData: data({ amISender: true, outgoingStatus: 4 }) })
            verify(!!header.resendButtonItem)
            compare(header.displayData.statusLabel, qsTranslate("StatusMessageHeader", "Sending failed"))
        }

        function test_accessibleText() {
            const header = create({ headerData: data({ isContact: true }) })
            const text = header.accessibleText
            verify(text.indexOf("Alice") === 0, text)
            verify(text.indexOf(header.formattedTimestamp) > 0, text)
            accessibleSpy.target = header
            header.headerData = data({ displayName: "Bob" })
            header.applyPendingChanges()
            compare(accessibleSpy.count, 1)
            verify(header.accessibleText.indexOf("Bob") === 0)
        }

        // --- lifecycle

        function test_servicesDestroyedFirst() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services, headerData: data({ amISender: true, outgoingStatus: 4 }) })
            header.showOutgoingStatusLabel = true
            header.applyPendingChanges()
            verify(!!header.resendButtonItem)
            services.destroy()
            wait(0)
            compare(header.services, null)
            header.headerData = data({ displayName: "Carol" })
            compare(header.displayName, "Carol")
            waitForRendering(header)
        }

        function test_windowChangeHidesTooltip() {
            const services = createTemporaryObject(servicesComp, root)
            const header = create({ services: services })
            waitForRendering(header)
            const ts = center(header.partRect("timestamp"))
            mouseMove(header, ts.x, ts.y)
            tryCompare(services, "tooltipVisible", true)
            header.parent = null
            compare(services.tooltipVisible, false)
            compare(services.clockSubscriberCount, 0)
            header.parent = root
            compare(services.clockSubscriberCount, 1)
        }

        function test_servicesAreRequired() {
            let failed = false
            try {
                const header = Qt.createQmlObject(`
                    import StatusQ.Components
                    StatusMessageHeader {}
                `, root)
                failed = !header
                if (header)
                    header.destroy()
            } catch (e) {
                failed = true
            }
            verify(failed, "creation without services must fail")
        }
    }
}
