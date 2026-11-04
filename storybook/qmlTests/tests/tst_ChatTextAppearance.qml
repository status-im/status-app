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
    MessageTextAppearance { id: messageAppearance; theme: root.Theme }
    Component {
        id: themeOwnerComponent
        Item {
            id: owner
            readonly property ChatTextAppearance textAppearance: MessageTextAppearance { theme: owner.Theme }
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
            compare(light.textAppearance.color, light.Theme.palette.directColor1)
            compare(dark.textAppearance.color, dark.Theme.palette.directColor1)
            const appearance = dark.textAppearance
            dark.Theme.style = Theme.Style.Light
            compare(dark.textAppearance, appearance)
            compare(dark.textAppearance.color, light.textAppearance.color)
        }

        function test_ownerDestructionRestoresNativeDefaults() {
            const owner = createTemporaryObject(themeOwnerComponent, root)
            const item = createTemporaryObject(textComponent, root, {appearance: owner.textAppearance})
            item.selectAll()
            const selected = item.selectedText
            const oldAppearance = item.appearance
            owner.destroy()
            wait(1)
            verify(!!item.appearance)
            verify(item.appearance !== oldAppearance)
            compare(item.selectedText, selected)
            verify(item.contentHeight > 0)
        }

        function test_liveThemeChangesKeepInstancesAndSelection() {
            const owner = createTemporaryObject(themeOwnerComponent, root)
            const item = createTemporaryObject(textComponent, root, {appearance: owner.textAppearance})
            const appearance = item.appearance
            item.selectAll()
            const selected = item.selectedText
            const spy = createTemporaryObject(spyComponent, root, {target: item, signalName: "segmentsChanged"})
            for (const style of [Theme.Style.Dark, Theme.Style.Light]) {
                owner.Theme.style = style
                compare(item.appearance, appearance)
                compare(item.appearance.color, owner.Theme.palette.directColor1)
                compare(item.selectedText, selected)
                compare(spy.count, 0)
            }
        }
    }
}
