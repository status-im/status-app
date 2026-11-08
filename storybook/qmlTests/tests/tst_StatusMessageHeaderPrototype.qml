import QtQuick
import QtQuick.Window
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root
    width: 1000
    height: 600
    property messageHeaderData initialHeaderData
    property messageHeaderData emptyHeaderData

    StatusMessageHeaderServices { id: sharedServices }
    StatusMessageHeaderAppearance { id: sharedAppearance; theme: root.Theme }
    Component { id: renderHostComponent; Item { width: 600; height: 240; clip: true } }
    Component { id: windowComponent; Window { width: 800; height: 600; visible: true } }
    Component { id: servicesComponent; StatusMessageHeaderServices {} }
    Component { id: appearanceComponent; StatusMessageHeaderAppearance { theme: root.Theme } }

    Component {
        id: fixture
        StatusMessageHeaderPrototype {
            services: sharedServices
            appearance: sharedAppearance
            width: 600
            headerData: ({displayName: "Alice", senderId: "alice-id", timestamp: 1700000000000})
        }
    }
    Component { id: spyComponent; SignalSpy {} }

    TestCase {
        name: "StatusMessageHeaderPrototype"
        when: windowShown

        function make(properties) {
            if (properties && "headerData" in properties) {
                root.initialHeaderData = properties.headerData
                properties = Object.assign({}, properties, {headerData: root.initialHeaderData})
            }
            const header = createTemporaryObject(fixture, root, properties || {})
            verify(header)
            verify(waitForPolish(renderer(header)))
            return header
        }
        // Build the next value away from the item, then publish it once.
        function rebind(header, changes) {
            root.initialHeaderData = header.headerData
            for (const key in changes)
                root.initialHeaderData[key] = changes[key]
            header.headerData = root.initialHeaderData
        }

        function renderer(header) {
            const item = header instanceof MessageHeaderItem ? header : findChild(header, "nativeHeaderRenderer")
            verify(item instanceof MessageHeaderItem)
            return item
        }

        function compareHeaderRendering(actual, expected) {
            // QtTest grabs a window crop, not an isolated item subtree. Use the
            // same scene position and show only one header in each capture.
            const actualVisible = actual.visible
            const expectedVisible = expected.visible
            expected.visible = false
            actual.visible = true
            const image = grabImage(actual)
            actual.visible = false
            expected.visible = true
            const reference = grabImage(expected)
            expected.visible = expectedVisible
            actual.visible = actualVisible
            verify(image.equals(reference), "Updated and fresh headers must render identically")
        }

        function test_diagnosticSnapshotAndAccessibilityAcrossRebind() {
            const header = make({headerData: {displayName: "Alice", senderId: "alice-id",
                                    secondaryName: "alice.eth", tertiaryDetail: "0123456789abcdef",
                                    isContact: true, trustIndicator: 1, timestamp: 1700000000000}})
            const item = renderer(header)
            const snapshot = JSON.parse(JSON.stringify(item.displayData))
            compare(snapshot.name, "Alice")
            compare(snapshot.secondary, "(alice.eth)")
            compare(snapshot.tertiary, "012…abcdef")
            compare(snapshot.verificationIcons.length, 1)
            compare(snapshot.separator, true)
            compare(snapshot.warning, false)
            compare(item.accessibleText, "Alice (alice.eth) 012…abcdef " + item.timestampText)

            rebind(header, {amISender: true, outgoingStatus: 4, resendError: "Offline",
                            messageOriginInfo: "#channel"})
            header.showOutgoingStatusLabel = true
            verify(waitForPolish(item))
            const rebound = item.displayData
            compare(rebound.name, qsTranslate("StatusMessageHeader", "You"))
            compare(rebound.origin, "#channel")
            compare(rebound.secondary, "")
            compare(rebound.tertiary, "")
            compare(rebound.verificationIcons.length, 0)
            compare(rebound.warning, true)
            compare(rebound.statusText, qsTranslate("StatusMessageHeader", "Failed to resend: %1").arg("Offline"))
            compare(item.accessibleText, rebound.name + " #channel " + item.timestampText + " " + rebound.statusText)
            // An explicitly copied diagnostic snapshot stays independent of later preparations.
            compare(snapshot.name, "Alice")
            compare(snapshot.secondary, "(alice.eth)")
            compare(snapshot.verificationIcons.length, 1)
        }

        function test_resizeAndHoverDoNotPublishContent() {
            const header = make({headerData: {displayName: "Alice with a long name that wraps onto multiple lines",
                                             senderId: "alice-id", timestamp: 1700000000000}})
            const item = renderer(header)
            const text = item.accessibleText
            const initialHeight = header.implicitHeight
            const content = createTemporaryObject(spyComponent, root, {target: item, signalName: "displayDataChanged"})
            const accessibility = createTemporaryObject(spyComponent, root, {target: item, signalName: "accessibleTextChanged"})
            header.width = 240
            verify(waitForPolish(item))
            verify(header.implicitHeight > initialHeight)
            compare(item.accessibleText, text)
            const rect = item.nameRect
            mouseMove(item, rect.x + rect.width / 2, rect.y + rect.height / 2)
            compare(item.hoveredPart, MessageHeaderItem.Name)
            verify(waitForPolish(item))
            mouseMove(root, root.width - 1, root.height - 1)
            verify(waitForPolish(item))
            compare(item.hoveredPart, MessageHeaderItem.None)
            compare(content.count, 0)
            compare(accessibility.count, 0)
        }

        function test_colorChangePaintsWithoutContentOrGeometryNotifications() {
            const appearance = createTemporaryObject(appearanceComponent, root)
            appearance.nameColor = "blue"
            const header = make({appearance})
            const item = renderer(header)
            const before = grabImage(item)
            const geometry = createTemporaryObject(spyComponent, root, {target: item, signalName: "layoutChanged"})
            const content = createTemporaryObject(spyComponent, root, {target: item, signalName: "displayDataChanged"})
            const accessibility = createTemporaryObject(spyComponent, root, {target: item, signalName: "accessibleTextChanged"})
            appearance.nameColor = "red"
            verify(waitForPolish(item))
            const after = grabImage(item)
            verify(!before.equals(after), "A paint-only change must reach the scene graph")
            compare(geometry.count, 0)
            compare(content.count, 0)
            compare(accessibility.count, 0)
        }

        function test_batchedInvalidationsMatchFreshHeader_data() {
            return [{tag: "incoming", data: {displayName: "A long incoming sender name to wrap",
                                             secondaryName: "alice.eth", senderId: "alice-id",
                                             isContact: true, trustIndicator: 1, timestamp: 1700000000000}},
                    {tag: "outgoing", data: {displayName: "Own message", amISender: true,
                                             outgoingStatus: 3, timestamp: 1700000000000}},
                    {tag: "rtl", data: {displayName: "مرحبا بالعالم · שלום", secondaryName: "alice.eth",
                                        messageOriginInfo: "#channel", timestamp: 1700000000000}}]
        }
        function test_batchedInvalidationsMatchFreshHeader(data) {
            const appearance = createTemporaryObject(appearanceComponent, root)
            const updated = make({appearance, displayNameClickable: false})
            rebind(updated, data.data)
            updated.width = 300
            updated.showFullTimestamp = true
            updated.showOutgoingStatusLabel = true
            appearance.nameFont = Qt.font({family: appearance.nameFont.family, pixelSize: 22, weight: Font.Medium})
            appearance.detailFont = Qt.font({family: appearance.detailFont.family, pixelSize: 14})
            appearance.nameColor = "red"
            appearance.detailColor = "green"
            verify(waitForPolish(renderer(updated)))
            const fresh = make({appearance, headerData: updated.headerData, width: 300,
                                showFullTimestamp: true, showOutgoingStatusLabel: true, displayNameClickable: false})
            const actual = renderer(updated)
            const expected = renderer(fresh)
            compare(actual.nameRect, expected.nameRect)
            compare(actual.contentWidth, expected.contentWidth)
            compare(actual.implicitWidth, expected.implicitWidth)
            compare(actual.implicitHeight, expected.implicitHeight)
            compare(actual.accessibleText, expected.accessibleText)
            compare(JSON.stringify(actual.displayData), JSON.stringify(expected.displayData))
            compareHeaderRendering(actual, expected)
        }

        function test_timestampAndSenderIdentityNotifications() {
            const header = make()
            const item = renderer(header)
            const content = createTemporaryObject(spyComponent, root, {target: item, signalName: "displayDataChanged"})
            const accessibility = createTemporaryObject(spyComponent, root, {target: item, signalName: "accessibleTextChanged"})
            header.showFullTimestamp = true
            verify(waitForPolish(item))
            compare(content.count, 0)
            compare(accessibility.count, 1)
            accessibility.clear()
            rebind(header, {senderId: "another-id", tertiaryDetail: header.headerData.tertiaryDetail})
            verify(waitForPolish(item))
            compare(item.displayData.senderId, "another-id")
            compare(content.count, 1)
            compare(accessibility.count, 0)
        }

        function hoverPart(header, part) {
            const rect = header.partRect(part)
            verify(rect.width > 0)
            mouseMove(header, rect.x + rect.width / 2, rect.y + rect.height / 2)
            compare(header.hoveredPart, part)
        }

        function test_clockMembershipAndServiceReplacement() {
            const first = createTemporaryObject(servicesComponent, root)
            const second = createTemporaryObject(servicesComponent, root)
            const header = make({services: first})
            compare(first.clockSubscriberCount, 1)
            header.showFullTimestamp = true
            compare(first.clockSubscriberCount, 0)
            header.visible = false
            header.showFullTimestamp = false
            compare(first.clockSubscriberCount, 0)
            header.visible = true
            compare(first.clockSubscriberCount, 1)
            rebind(header, {timestamp: 0})
            compare(first.clockSubscriberCount, 0)
            rebind(header, {timestamp: 1700000000000})
            compare(first.clockSubscriberCount, 1)
            header.services = second
            compare(first.clockSubscriberCount, 0)
            compare(second.clockSubscriberCount, 1)
            header.destroy()
            tryCompare(second, "clockSubscriberCount", 0)
            first.tick()
            second.tick()
        }

        function test_tooltipIsLazySharedAndUsesCurrentTarget() {
            const services = createTemporaryObject(servicesComponent, root, {tooltipDelay: 0})
            const first = make({services})
            const second = make({services, y: 80, headerData: {displayName: "Trusted Alice", isContact: true,
                                                            trustIndicator: 1, timestamp: 1700000000000}})
            compare(services.tooltipCreated, false)
            hoverPart(first, MessageHeaderItem.Timestamp)
            tryCompare(services, "tooltipOpened", true)
            compare(services.tooltipTarget, first)
            compare(services.tooltipText, first.fullTimestampText())
            const popup = services.popup.item
            hoverPart(second, MessageHeaderItem.Verification)
            tryCompare(services, "tooltipOpened", true)
            compare(services.tooltipTarget, second)
            compare(services.tooltipText, qsTranslate("StatusContactVerificationIcons", "Trusted contact"))
            compare(services.popup.item, popup)
            second.enabled = false
            tryCompare(services, "tooltipOpened", false)
            compare(services.tooltipTarget, null)
        }

        function test_pendingTooltipRebindHideAndDestruction() {
            const services = createTemporaryObject(servicesComponent, root, {tooltipDelay: 250})
            const header = make({services})
            hoverPart(header, MessageHeaderItem.Timestamp)
            compare(services.tooltipOpened, false)
            header.visible = false
            compare(services.tooltipTarget, null)
            wait(300)
            compare(services.tooltipOpened, false)
            header.visible = true
            mouseMove(root, root.width - 1, root.height - 1)
            hoverPart(header, MessageHeaderItem.Timestamp)
            rebind(header, {timestamp: 1800000000000})
            verify(waitForPolish(header))
            if (services.tooltipTarget) compare(services.tooltipText, header.fullTimestampText())
            header.destroy()
            tryCompare(services, "tooltipTarget", null)
            wait(300)
            compare(services.tooltipOpened, false)
        }

        function test_windowChangeDismissesTooltipAndUpdatesClockMembership() {
            const services = createTemporaryObject(servicesComponent, root, {tooltipDelay: 0})
            const header = make({services})
            hoverPart(header, MessageHeaderItem.Timestamp)
            tryCompare(services, "tooltipOpened", true)
            header.parent = null
            compare(services.tooltipTarget, null)
            compare(services.clockSubscriberCount, 0)
            const other = createTemporaryObject(windowComponent, root)
            header.parent = other.contentItem
            compare(services.clockSubscriberCount, 1)
            compare(services.tooltipTarget, null)
            header.parent = root
            compare(services.clockSubscriberCount, 1)
        }

        function test_serviceCanBeDestroyedBeforeItsHeaders() {
            const services = servicesComponent.createObject(root)
            const header = make({services, isMobile: true,
                                 headerData: {amISender: true, outgoingStatus: 4, timestamp: 1700000000000}})
            verify(findChild(header, "nativeResendButton"))
            hoverPart(header, MessageHeaderItem.Timestamp)
            services.destroy()
            tryCompare(header, "services", null)
            verify(waitForPolish(header))
            tryVerify(() => findChild(header, "nativeResendButton") === null)
            verify(header.implicitHeight > 0)
            header.services = sharedServices
            verify(waitForPolish(header))
            verify(findChild(header, "nativeResendButton"))
        }

        function test_rootHeightAndResendImplicitSize() {
            const header = make({height: 120, isMobile: true,
                                 headerData: {amISender: true, outgoingStatus: 4, timestamp: 1700000000000}})
            const button = findChild(header, "nativeResendButton")
            verify(button)
            compare(header.nameRect.y + header.nameRect.height / 2, (header.height - 2) / 2)
            compare(button.y + button.height / 2, header.height / 2)
            compare(button.x, header.contentWidth + 4)
            header.height = 160
            verify(waitForPolish(header))
            compare(header.nameRect.y + header.nameRect.height / 2, (header.height - 2) / 2)
            compare(button.y + button.height / 2, header.height / 2)
            const width = header.implicitWidth
            button.text = "A much longer resend label"
            verify(waitForPolish(button))
            verify(waitForPolish(header))
            tryVerify(() => header.implicitWidth > width)
            compare(button.width, button.implicitWidth)
            const spy = createTemporaryObject(spyComponent, root, {target: header, signalName: "clicked"})
            mouseClick(header, header.nameRect.x + 1, header.nameRect.y + 1)
            compare(spy.count, 1)
        }

        function test_rebuiltTextKeepsParentTransformAndClip() {
            const host = createTemporaryObject(renderHostComponent, root)
            const appearance = createTemporaryObject(appearanceComponent, root)
            appearance.nameColor = "magenta"
            appearance.detailColor = "lime"
            const header = make({appearance, x: 80, y: 80, width: 480,
                                 headerData: {amISender: true, timestamp: 1700000000000}})
            header.parent = host
            function colouredPixels(image, x0, y0, width, height) {
                let count = 0
                for (let y = y0; y < y0 + height; ++y)
                    for (let x = x0; x < x0 + width; ++x)
                        if (image.alpha(x, y) > 100 &&
                                ((image.green(x, y) > 200 && image.red(x, y) < 100 && image.blue(x, y) < 100) ||
                                 (image.red(x, y) > 200 && image.blue(x, y) > 200 && image.green(x, y) < 100)))
                            count++
                return count
            }
            function checkPosition() {
                verify(waitForPolish(header))
                const image = grabImage(host)
                verify(colouredPixels(image, 80, 80, 150, 35) > 0, "Text must stay in its translated header")
                compare(colouredPixels(image, 0, 0, 600, 50), 0, "Rebuilt glyphs must not escape to the scene origin")
            }
            checkPosition()
            header.showFullTimestamp = true
            header.width = 240
            checkPosition()
            hoverPart(header, MessageHeaderItem.Name)
            checkPosition()
        }

        function test_optionalPartTransitionsMatchFreshHeaders_data() {
            return [{tag: "narrow", width: 240}, {tag: "normal", width: 480}, {tag: "wide", width: 600}]
        }
        function test_optionalPartTransitionsMatchFreshHeaders(data) {
            const appearance = createTemporaryObject(appearanceComponent, root)
            appearance.youText = "Alice"
            const base = {displayName: "Alice", senderId: "0x0123456789abcdef", timestamp: 1700000000000}
            const header = make({appearance, headerData: base, width: data.width,
                                 displayNameClickable: false, showOutgoingStatusLabel: true})
            const variants = [{}, {isContact: true, trustIndicator: 1},
                              {isContact: true, trustIndicator: 2, secondaryName: "alice.eth"},
                              {isContact: true, secondaryName: "alice.eth", messageOriginInfo: "#general"},
                              {amISender: true, messageOriginInfo: "#origin"},
                              {amISender: true, outgoingStatus: 3},
                              {amISender: true, outgoingStatus: 4, resendError: "Offline"}, {}]
            for (const variant of variants) {
                root.initialHeaderData = Object.assign({}, base, variant)
                header.headerData = root.initialHeaderData
                const fresh = make({appearance, headerData: root.initialHeaderData, width: data.width,
                                    displayNameClickable: false, showOutgoingStatusLabel: true})
                wait(1)
                verify(waitForPolish(header))
                verify(waitForPolish(fresh))
                compare(header.nameRect, fresh.nameRect)
                compare(header.partRect(MessageHeaderItem.Timestamp), fresh.partRect(MessageHeaderItem.Timestamp))
                compare(header.contentWidth, fresh.contentWidth)
                compare(header.implicitWidth, fresh.implicitWidth)
                compare(header.implicitHeight, fresh.implicitHeight)
                compare(header.accessibleText, fresh.accessibleText)
                compare(JSON.stringify(header.displayData), JSON.stringify(fresh.displayData))
                compareHeaderRendering(header, fresh)
                fresh.destroy()
                wait(1)
            }
        }

        function test_replacedRoleWithEqualMetricsRepaintsText() {
            const appearance = createTemporaryObject(appearanceComponent, root)
            appearance.youText = "Alice"
            appearance.detailFont = Qt.font({family: appearance.detailFont.family, pixelSize: 12, kerning: false})
            const header = make({appearance, displayNameClickable: false,
                                 headerData: {displayName: "Alice", senderId: "ABCDEFGHIJ", timestamp: 1700000000000}})
            compare(header.displayData.tertiary, "ABC…EFGHIJ")
            const original = grabImage(header)
            const width = header.contentWidth
            root.initialHeaderData = {amISender: true, messageOriginInfo: "ACB…EFGHIJ", timestamp: 1700000000000}
            header.headerData = root.initialHeaderData
            verify(waitForPolish(header))
            // Same glyph advances and endpoints, but different text and role.
            // The render-node cache must not confuse their revision counters.
            compare(header.contentWidth, width)
            const updated = grabImage(header)
            verify(!original.equals(updated), "Equal metrics must not suppress a changed label")
            const fresh = make({appearance, displayNameClickable: false, headerData: root.initialHeaderData})
            compareHeaderRendering(header, fresh)
            fresh.destroy()
            wait(1)
            grabImage(header)
            // Materialise removal and recreation without an intervening frame.
            root.initialHeaderData = {displayName: "Alice", senderId: "ABCDEFGHIJ", timestamp: 1700000000000}
            header.headerData = root.initialHeaderData
            header.ensurePolished()
            root.initialHeaderData = {amISender: true, messageOriginInfo: "ABC…EFGHIJ", timestamp: 1700000000000}
            header.headerData = root.initialHeaderData
            header.ensurePolished()
            verify(!updated.equals(grabImage(header)), "Recreated roles must not reuse an old render revision")
        }

        function test_initialLayoutAndLiteralName() {
            const header = make()
            const item = renderer(header)
            verify(header.implicitHeight > 0)
            verify(item.nameRect.width > 0)
            rebind(header, {displayName: "<b>Alice</b> 👩🏽‍💻"})
            verify(waitForPolish(renderer(header)))
            compare(item.displayData.name, header.headerData.displayName)
            verify(item.nameRect.width > 0)
        }

        function test_rebindRemovesIncomingMetadata() {
            const header = make()
            rebind(header, {secondaryName: "alice.eth", tertiaryDetail: "0x1234567890abcdef", isContact: true})
            verify(waitForPolish(renderer(header)))
            const item = renderer(header)
            compare(item.displayData.verificationIcons.length, 1)
            verify(item.displayData.secondary.length > 0)
            verify(item.displayData.tertiary.length > 0)
            rebind(header, {amISender: true, outgoingStatus: StatusMessage.OutgoingStatus.Delivered})
            header.showOutgoingStatusLabel = true
            verify(waitForPolish(renderer(header)))
            compare(item.displayData.verificationIcons.length, 0)
            compare(item.displayData.secondary, "")
            compare(item.displayData.tertiary, "")
            verify(item.displayData.statusIcon.toString().length > 0)
            verify(item.displayData.statusText.length > 0)
            rebind(header, {outgoingStatus: StatusMessage.OutgoingStatus.Unknown})
            verify(waitForPolish(renderer(header)))
            compare(item.displayData.statusIcon, "")
            compare(item.displayData.statusText, "")
        }

        function test_nameClickAndDisabledClick() {
            const header = make()
            const item = renderer(header)
            const spy = createTemporaryObject(spyComponent, root, {target: header, signalName: "clicked"})
            verify(spy.valid)
            const rect = item.nameRect
            mouseClick(item, rect.x + rect.width / 2, rect.y + rect.height / 2)
            compare(spy.count, 1)
            header.displayNameClickable = false
            verify(waitForPolish(renderer(header)))
            mouseClick(item, rect.x + rect.width / 2, rect.y + rect.height / 2)
            compare(spy.count, 1)
        }

        function test_nameWrapsAndRestores() {
            const header = make()
            rebind(header, {displayName: "Alice with a long display name to wrap onto several lines"})
            verify(waitForPolish(renderer(header)))
            const initialHeight = header.implicitHeight
            header.width = 240
            verify(waitForPolish(renderer(header)))
            verify(header.implicitHeight > initialHeight)
            header.width = 600
            verify(waitForPolish(renderer(header)))
            compare(header.implicitHeight, initialHeight)
        }

        function test_fontChangeRelayouts() {
            const appearance = createTemporaryObject(appearanceComponent, root)
            verify(appearance)
            const header = make({appearance})
            const item = renderer(header)
            const originalHeight = header.implicitHeight
            appearance.nameFont = Qt.font({family: appearance.nameFont.family, pixelSize: 32, weight: Font.Medium})
            verify(waitForPolish(item))
            verify(header.implicitHeight > originalHeight)
        }

        function test_timestampMatchesLocaleUtils_data() {
            const rows = []
            for (const days of [0, 1, 2, 3, 4, 5, 6, 14, 400]) {
                for (const full of [false, true]) {
                    for (const mode of ["default", "12h", "24h"])
                        rows.push({tag: days + "-" + full + "-" + mode, days, full, mode})
                }
            }
            return rows
        }

        function test_timestampMatchesLocaleUtils(data) {
            const defaults = LocaleUtils.settings.timeFormatUsesDefaults
            const use24 = LocaleUtils.settings.timeFormatUses24Hours
            try {
                LocaleUtils.settings.timeFormatUsesDefaults = data.mode === "default"
                LocaleUtils.settings.timeFormatUses24Hours = data.mode === "24h"
                const date = new Date()
                date.setDate(date.getDate() - data.days)
                date.setHours(13, 24, 35, 0)
                const timestamp = date.getTime()
                const header = make({headerData: {displayName: "Alice", timestamp}, showFullTimestamp: data.full})
                const expected = data.full ? LocaleUtils.formatDateTime(timestamp)
                                           : LocaleUtils.formatRelativeTimestamp(timestamp)
                compare(header.timestampLabel, expected)
                compare(renderer(header).fullTimestampText(), LocaleUtils.formatDateTime(timestamp))
                renderer(header).refreshTimestamp()
                verify(waitForPolish(renderer(header)))
                compare(header.timestampLabel, expected)
            } finally {
                LocaleUtils.settings.timeFormatUsesDefaults = defaults
                LocaleUtils.settings.timeFormatUses24Hours = use24
            }
        }

        function test_timestampUsesUpdatedTranslationTemplates() {
            const appearance = createTemporaryObject(appearanceComponent, root)
            verify(appearance)
            const header = make({appearance, headerData: {displayName: "Alice", timestamp: Date.now()}})
            const item = renderer(header)
            appearance.timestampFormats = ["[today] %1", "[yesterday] %1", "%1 %2"]
            verify(waitForPolish(item))
            verify(header.timestampLabel.startsWith("[today] "))
            // Retranslation can occur without changing the timestamp/locale.
            appearance.timestampFormats = ["[updated] %1", "[yesterday] %1", "%1 %2"]
            verify(waitForPolish(item))
            verify(header.timestampLabel.startsWith("[updated] "))
        }

        function test_timestampRebindAndSettingsChange() {
            const defaults = LocaleUtils.settings.timeFormatUsesDefaults
            const use24 = LocaleUtils.settings.timeFormatUses24Hours
            try {
                const header = make()
                for (const full of [false, true]) {
                    header.showFullTimestamp = full
                    for (const timestamp of [Date.now(), 1700000000000, 0]) {
                        rebind(header, {timestamp})
                        LocaleUtils.settings.timeFormatUsesDefaults = false
                        LocaleUtils.settings.timeFormatUses24Hours = !LocaleUtils.settings.timeFormatUses24Hours
                        verify(waitForPolish(renderer(header)))
                        compare(header.timestampLabel, full ? LocaleUtils.formatDateTime(timestamp)
                                                            : LocaleUtils.formatRelativeTimestamp(timestamp))
                    }
                }
            } finally {
                LocaleUtils.settings.timeFormatUsesDefaults = defaults
                LocaleUtils.settings.timeFormatUses24Hours = use24
            }
        }

        function test_atomicSnapshotPublishesContentOnce() {
            const initial = Object.freeze({senderId: "alice-id", displayName: "Alice",
                timestamp: 1700000000000, isContact: true, secondaryName: "alice.eth"})
            const header = make({headerData: initial, showOutgoingStatusLabel: true})
            const item = renderer(header)
            const spy = createTemporaryObject(spyComponent, root, {target: item, signalName: "headerDataChanged"})
            verify(spy.valid)
            const appearanceSpy = createTemporaryObject(spyComponent, root, {target: item.appearance, signalName: "changed"})
            const next = Object.freeze({senderId: "bob-id", displayName: "Bob",
                timestamp: 1700000060000, amISender: true, outgoingStatus: StatusMessage.OutgoingStatus.Expired,
                resendError: "Offline", messageOriginInfo: "#new"})
            header.headerData = next
            compare(spy.count, 1)
            verify(waitForPolish(item))
            compare(spy.count, 1)
            compare(item.displayData.senderId, "bob-id")
            compare(item.displayData.name, qsTranslate("StatusMessageHeader", "You"))
            compare(item.displayData.secondary, "")
            compare(item.displayData.tertiary, "")
            compare(item.displayData.verificationIcons.length, 0)
            compare(item.displayData.origin, "#new")
            verify(item.displayData.statusText.indexOf("Offline") >= 0)
            verify(findChild(header, "nativeResendButton"))
            spy.clear()
            header.headerData = initial
            verify(waitForPolish(item))
            compare(spy.count, 1)
            compare(item.displayData.name, "Alice")
            compare(item.displayData.secondary, "(alice.eth)")
            compare(item.displayData.statusIcon, "")
            compare(item.displayData.statusText, "")
            verify(!header.expired)
            compare(appearanceSpy.count, 0)
        }

        function test_typedPresentationChangeKeepsSnapshot() {
            const header = make({headerData: {displayName: "Alice", senderId: "id", amISender: true,
                timestamp: 1700000000000, outgoingStatus: StatusMessage.OutgoingStatus.Expired}})
            const item = renderer(header)
            const spy = createTemporaryObject(spyComponent, root, {target: item, signalName: "headerDataChanged"})
            compare(item.displayData.statusText, "")
            header.isMobile = true
            verify(waitForPolish(item))
            verify(item.displayData.statusText.length > 0)
            verify(findChild(header, "nativeResendButton"))
            compare(spy.count, 0)
            compare(header.headerData.outgoingStatus, StatusMessage.OutgoingStatus.Expired)
        }

        function test_sharedAppearanceUpdatesBothHeaders() {
            const appearance = createTemporaryObject(appearanceComponent, root)
            verify(appearance)
            const first = make({appearance})
            const second = make({appearance})
            compare(renderer(first).appearance, renderer(second).appearance)
            const height = first.implicitHeight
            const dataSpy = createTemporaryObject(spyComponent, root, {target: renderer(first), signalName: "headerDataChanged"})
            appearance.nameFont = Qt.font({family: appearance.nameFont.family, pixelSize: 32, weight: Font.Medium})
            appearance.nameColor = "red"
            verify(waitForPolish(renderer(first)))
            verify(waitForPolish(renderer(second)))
            verify(first.implicitHeight > height)
            compare(first.implicitHeight, second.implicitHeight)
            compare(dataSpy.count, 0)
            const styleSpy = createTemporaryObject(spyComponent, root, {target: appearance, signalName: "changed"})
            first.showOutgoingStatusLabel = true
            first.displayNameClickable = false
            first.isMobile = true
            verify(waitForPolish(renderer(first)))
            compare(styleSpy.count, 0)
            compare(second.showOutgoingStatusLabel, false)
            compare(second.displayNameClickable, true)
        }

        function test_appearanceReplacementAndDestruction() {
            const appearance = appearanceComponent.createObject(root)
            verify(appearance)
            const first = make({appearance})
            const second = make({appearance})
            appearance.destroy()
            tryVerify(() => first.appearance !== appearance && second.appearance !== appearance)
            verify(first.appearance)
            compare(first.appearance, second.appearance)
            verify(waitForPolish(renderer(first)))
            verify(waitForPolish(renderer(second)))
            verify(first.implicitHeight > 0)
            first.appearance = sharedAppearance
            verify(waitForPolish(renderer(first)))
            compare(first.appearance, sharedAppearance)
            compare(first.headerData.displayName, "Alice")
        }

        function test_typedValueDefaultsCopyAndEquality() {
            const header = make({headerData: root.emptyHeaderData})
            const item = renderer(header)
            compare(header.headerData.timestamp, 0)
            compare(header.headerData.senderId, "")
            compare(header.headerData.isContact, false)
            compare(header.headerData.amISender, false)
            compare(item.displayData.name, "")
            compare(header.headerData.outgoingStatus, StatusMessage.OutgoingStatus.Unknown)
            root.initialHeaderData = header.headerData
            header.headerData = {senderId: "new-id", displayName: "New value"}
            verify(waitForPolish(item))
            compare(root.initialHeaderData.displayName, "")
            compare(header.headerData.tertiaryDetail, "new-id")
            const spy = createTemporaryObject(spyComponent, root, {target: item, signalName: "headerDataChanged"})
            header.headerData = header.headerData
            verify(waitForPolish(item))
            compare(spy.count, 0)
            header.headerData = {senderId: "id", displayName: "Empty detail", tertiaryDetail: ""}
            verify(waitForPolish(item))
            compare(header.headerData.tertiaryDetail, "")
        }

        function test_batchedRebindUsesFinalSnapshot() {
            const header = make()
            const item = renderer(header)
            rebind(header, {displayName: "Intermediate", secondaryName: "temporary.eth", isContact: true})
            rebind(header, {displayName: "Final sender", secondaryName: "", isContact: false, messageOriginInfo: "#final"})
            verify(waitForPolish(item))
            compare(item.displayData.name, "Final sender")
            compare(item.displayData.secondary, "")
            compare(item.displayData.origin, "#final")
            compare(item.displayData.tertiary, "")
            compare(item.displayData.verificationIcons.length, 0)
            verify(item.nameRect.width > 0)
            compare(header.Accessible.name.indexOf("Intermediate"), -1)
            verify(header.Accessible.name.indexOf("Final sender") >= 0)
        }

        function test_rebindCancelsPendingNameClick() {
            const header = make()
            const item = renderer(header)
            const spy = createTemporaryObject(spyComponent, root, {target: header, signalName: "clicked"})
            const rect = item.nameRect
            mousePress(item, rect.x + 1, rect.y + 1)
            rebind(header, {displayName: "Bob"})
            verify(waitForPolish(item))
            mouseRelease(item, rect.x + 1, rect.y + 1)
            compare(spy.count, 0)
        }

        function test_resendUsesRealButton() {
            const header = make({headerData: {amISender: true, outgoingStatus: StatusMessage.OutgoingStatus.Expired}})
            compare(findChild(header, "nativeResendButton"), null)
            header.isMobile = true
            verify(waitForPolish(renderer(header)))
            const button = findChild(header, "nativeResendButton")
            verify(button)
            const spy = createTemporaryObject(spyComponent, root, {target: header, signalName: "resendClicked"})
            mouseClick(button, button.width / 2, button.height / 2)
            compare(spy.count, 1)
            button.forceActiveFocus()
            keyClick(Qt.Key_Space)
            compare(spy.count, 2)
            rebind(header, {outgoingStatus: StatusMessage.OutgoingStatus.Sent})
            verify(waitForPolish(renderer(header)))
            tryVerify(() => findChild(header, "nativeResendButton") === null)
        }
    }
}
