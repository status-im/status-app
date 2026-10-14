import QtQuick
import QtTest

import StatusQ.Core.Theme
import StatusQ.Popups

Item {
    id: root

    width: 800
    height: 800

    // mention wire format: "@0x" + 130 lowercase hex chars
    readonly property string aliceKey: "0x04" + "a".repeat(128)

    Component {
        id: resultsComponent

        ListModel {
            function appendResult(itemId, sectionName, content) {
                append({
                    itemId, sectionName, content,
                    time: "1700000000000", titleId: "0x1", title: "Alice", image: "", color: "red",
                    badgePrimaryText: "", badgeSecondaryText: "", badgeImage: "", badgeIconColor: "",
                    badgeIsLetterIdenticon: false, isUserIcon: true, colorId: 1
                })
            }
        }
    }

    Component {
        id: popupComponent

        StatusSearchPopup {
            // pubKey -> name, read by resolveMentionsFn the way MentionResolver reads its model
            property var names: ({})

            resolveMentionsFn: text => {
                const result = {}
                for (const key in names)
                    if (text.includes("@" + key))
                        result[key] = names[key]
                return result
            }
        }
    }

    TestCase {
        name: "StatusSearchPopup"
        when: windowShown

        // the window's theme before a test changed it
        property int initialStyle: -1

        function init() {
            // StatusInput's padding Binding reads the property it writes in its `when`
            ignoreWarning(/StatusInput\.qml:\d+:\d+: QML Binding: Binding loop detected for property "when"/)
        }

        function cleanup() {
            if (initialStyle !== -1)
                root.Window.window.Theme.style = initialStyle
            initialStyle = -1
        }

        function findSubtitles(item, out = []) {
            if (item.objectName === "statusListItemSubTitle")
                out.push(item)
            for (const child of item.children ?? [])
                findSubtitles(child, out)
            return out
        }

        function openWith(results, names = {}) {
            const popup = createTemporaryObject(popupComponent, root, { searchResults: results, names })
            popup.open()
            popup.contentItem.searchText = "search term"
            tryVerify(() => findSubtitles(popup.contentItem).length === results.count)
            return popup
        }

        function subtitleText(popup, index) {
            return findSubtitles(popup.contentItem)[index].text
        }

        function test_rendersMessageTextAsSingleLineHtml() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("m1", "Messages", "**hi** Tom & Jerry\nbye")
            const popup = openWith(results)

            const text = subtitleText(popup, 0)
            verify(text.startsWith("<style>"), text)
            verify(text.endsWith("</style><b>hi</b> Tom &amp; Jerry bye"), text)
            compare(findSubtitles(popup.contentItem)[0].textFormat, Text.RichText)
        }

        function test_mentionNamesFollowTheResolver() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("m1", "Messages", `hi @${root.aliceKey}`)
            const popup = openWith(results, { [root.aliceKey]: "Alice" })

            verify(subtitleText(popup, 0).includes(`class="mention">@Alice</a>`), subtitleText(popup, 0))

            popup.names = { [root.aliceKey]: "Alicia" }
            tryVerify(() => subtitleText(popup, 0).includes(`class="mention">@Alicia</a>`), 1000,
                      subtitleText(popup, 0))
        }

        // rich text ignores Text.linkColor: without a stylesheet a mention shows in Qt's
        // default blue, whatever the theme
        function test_mentionsUseTheThemeColors_data() {
            return [
                { tag: "light", style: Theme.Style.Light },
                { tag: "dark", style: Theme.Style.Dark }
            ]
        }

        function test_mentionsUseTheThemeColors(data) {
            // as main.qml does: the window carries the app theme and popups inherit it
            initialStyle = root.Window.window.Theme.style
            root.Window.window.Theme.style = data.style

            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("m1", "Messages", `hi @${root.aliceKey}`)
            const popup = openWith(results)
            const subtitle = findSubtitles(popup.contentItem)[0]

            const palette = subtitle.Theme.palette
            compare(subtitle.Theme.style, data.style)
            verify(subtitle.text.includes(`a.mention { color: ${palette.mentionColor1}; `
                                          + `background-color: ${palette.mentionColor4}; `), subtitle.text)
            verify(subtitle.text.includes(` a { color: ${palette.primaryColor1} }`), subtitle.text)
        }

        function test_emptyContentHasNoSubtitle() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("c1", "Chats", "")
            const popup = openWith(results)

            compare(subtitleText(popup, 0), "")
        }
    }
}
