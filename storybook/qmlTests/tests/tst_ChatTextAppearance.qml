import QtQuick
import QtTest
import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
Item {
    id: root
    width: 800
    height: 250
    Component { id: styleComponent; ChatTextAppearance { font.pixelSize: 16; lineHeight: 22 } }
    Component { id: textComponent; ChatTextItem { width: 380; segments: [{text: "hello 😎", href: "https://status.app"}] } }
    Component { id: previewComponent; ChatSingleLineTextItem { width: 100; y: 100; segments: [{text: "hello 😎 and a long ending"}] } }
    MessageTextAppearance { id: messageAppearance; theme: root.Theme }
    ReplyTextAppearance { id: replyAppearance; theme: root.Theme }
    Component {
        id: themeOwnerComponent
        Item {
            id: owner
            readonly property ChatTextAppearance textAppearance: MessageTextAppearance { theme: owner.Theme }
            readonly property ChatTextAppearance previewAppearance: ReplyTextAppearance { theme: owner.Theme }
        }
    }
    property int destructions: 0
    Component {
        id: ownerWithItemsComponent
        Item {
            id: itemsOwner
            readonly property ChatTextAppearance textAppearance: MessageTextAppearance { theme: itemsOwner.Theme }
            readonly property ChatTextAppearance previewAppearance: ReplyTextAppearance { theme: itemsOwner.Theme }
            ChatTextItem {
                width: 380
                appearance: itemsOwner.textAppearance
                segments: [{text: "hello 😎", href: "https://status.app"}]
                Component.onDestruction: ++root.destructions
            }
            ChatSingleLineTextItem {
                width: 100
                appearance: itemsOwner.previewAppearance
                segments: [{text: "hello 😎 and a long ending"}]
                Component.onDestruction: ++root.destructions
            }
        }
    }
    Component {
        id: themedComponent
        ChatTextItem {
            width: 380
            appearance: messageAppearance
            segments: [{text: "hello 😎", href: "https://status.app"}]
        }
    }
    Component { id: spyComponent; SignalSpy {} }
    TestCase {
        name: "ChatTextAppearance"
        when: windowShown

        // Restored after every test, so a failing one cannot leak its offset.
        property real initialFontSizeOffset

        function initTestCase() {
            initialFontSizeOffset = root.Theme.fontSizeOffset
        }

        function cleanup() {
            root.Theme.fontSizeOffset = initialFontSizeOffset
        }

        function test_sharedUpdates() {
            const style = createTemporaryObject(styleComponent, root)
            const a = createTemporaryObject(textComponent, root, {appearance: style})
            const b = createTemporaryObject(textComponent, root, {appearance: style, x: 400})
            const preview = createTemporaryObject(previewComponent, root, {appearance: style})
            compare(a.appearance, b.appearance)
            a.selectAll()
            a.hoverAt(2, 10)
            const selected = a.selectedText
            const hovered = a.hoveredLink
            const spy = createTemporaryObject(spyComponent, root, {target: a, signalName: "segmentsChanged"})
            const height = a.contentHeight
            style.linkColor = "red"
            style.mentionBackground = "lime"
            style.font.pixelSize = 32
            verify(a.contentHeight > height)
            compare(a.contentHeight, b.contentHeight)
            compare(a.selectedText, selected)
            compare(a.hoveredLink, hovered)
            compare(spy.count, 0)
            verify(preview.truncated)
        }
        function test_replacementAndDestruction() {
            const old = createTemporaryObject(styleComponent, root)
            const next = createTemporaryObject(styleComponent, root, {color: "red"})
            const item = createTemporaryObject(textComponent, root, {appearance: old})
            item.selectAll()
            const selected = item.selectedText
            item.appearance = next
            old.font.pixelSize = 40
            compare(item.appearance.font.pixelSize, 16)
            compare(item.selectedText, selected)
            const replaced = item.appearance
            next.destroy()
            tryVerify(() => item.appearance !== replaced)
            verify(item.appearance)
            compare(item.selectedText, selected)
            item.appearance = null
            verify(item.appearance)
        }
        // An appearance going down with its items, as when a panel declaring
        // it closes: the queued restyling is dropped with the items.
        function test_appearanceAndItemsDestroyedTogether() {
            // Any warning but Qt's one-off font alias notice.
            failOnWarning(/^(?!Populating font family aliases)/)
            root.destructions = 0
            const owner = createTemporaryObject(ownerWithItemsComponent, root)
            verify(!!owner)
            owner.destroy()
            tryCompare(root, "destructions", 2)
        }

        function test_fontOffsetUpdatesSharedInstance() {
            root.Theme.fontSizeOffset = 0
            const item = createTemporaryObject(themedComponent, root)
            const first = item.appearance
            const height = item.contentHeight
            item.selectAll()
            const selected = item.selectedText
            root.Theme.fontSizeOffset = 8
            compare(item.appearance, first)
            compare(item.appearance.font.pixelSize, root.Theme.primaryTextFontSize)
            verify(item.contentHeight > height)
            compare(item.selectedText, selected)
        }

        function test_explicitThemeScopes() {
            const light = createTemporaryObject(themeOwnerComponent, root)
            const dark = createTemporaryObject(themeOwnerComponent, root)
            light.Theme.style = Theme.Style.Light
            dark.Theme.style = Theme.Style.Dark
            verify(light.textAppearance !== dark.textAppearance)
            verify(light.previewAppearance !== light.textAppearance)
            compare(light.textAppearance.color, light.Theme.palette.directColor1)
            compare(dark.textAppearance.color, dark.Theme.palette.directColor1)
            compare(light.previewAppearance.mentionColor, light.Theme.palette.mentionColor1)
            compare(dark.previewAppearance.mentionColor, dark.Theme.palette.mentionColor1)
            const appearance = dark.textAppearance
            dark.Theme.style = Theme.Style.Light
            compare(dark.textAppearance, appearance)
            compare(dark.textAppearance.color, light.textAppearance.color)
        }

        function test_ownerDestructionRestoresNativeDefaults() {
            const owner = createTemporaryObject(themeOwnerComponent, root)
            const item = createTemporaryObject(textComponent, root, {appearance: owner.textAppearance})
            const preview = createTemporaryObject(previewComponent, root, {appearance: owner.previewAppearance})
            item.selectAll()
            const selected = item.selectedText
            const oldAppearance = item.appearance
            const oldPreviewAppearance = preview.appearance
            owner.destroy()
            tryVerify(() => item.appearance !== oldAppearance)
            tryVerify(() => preview.appearance !== oldPreviewAppearance)
            verify(!!item.appearance)
            verify(!!preview.appearance)
            compare(item.selectedText, selected)
            verify(item.contentHeight > 0)
        }

        function test_liveThemeChangesKeepInstancesAndSelection() {
            const owner = createTemporaryObject(themeOwnerComponent, root)
            const item = createTemporaryObject(textComponent, root, {appearance: owner.textAppearance})
            const preview = createTemporaryObject(previewComponent, root, {appearance: owner.previewAppearance})
            const appearance = item.appearance
            const previewStyle = preview.appearance
            item.selectAll()
            const selected = item.selectedText
            const spy = createTemporaryObject(spyComponent, root, {target: item, signalName: "segmentsChanged"})
            for (const style of [Theme.Style.Dark, Theme.Style.Light]) {
                owner.Theme.style = style
                compare(item.appearance, appearance)
                compare(preview.appearance, previewStyle)
                compare(item.appearance.color, owner.Theme.palette.directColor1)
                compare(preview.appearance.mentionBackground, owner.Theme.palette.mentionColor4)
                compare(item.selectedText, selected)
                compare(spy.count, 0)
            }
        }
    }
}
