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
    }

    Component {
        id: headerComp

        StatusMessageHeaderPrototype {
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
        id: servicesComp
        StatusMessageHeaderServices {}
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
        name: "StatusMessageHeaderPrototype"
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
                    StatusMessageHeaderPrototype {}
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
