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

        function test_threadScopeNameIsPlainText() {
            const popup = createTemporaryObject(popupComponent, root)
            popup.open()
            const name = "<b>bold</b> & <a href='https://example.com'>link</a>"
            popup.setSearchSelection("Community", "general", "", false, "", "transparent", false, 0, name)

            const label = findChild(popup.contentItem, "searchScopeThreadText")
            verify(!!label)
            compare(label.text, name)
            compare(label.textFormat, Text.PlainText)
        }

        function test_rendersMessageTextAsStyledText() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("m1", "Messages", "**hi** Tom & Jerry\nbye")
            const popup = openWith(results)

            compare(subtitleText(popup, 0), "<b>hi</b> Tom &amp; Jerry<br/>bye")
            compare(findSubtitles(popup.contentItem)[0].textFormat, Text.StyledText)
        }

        // Styled text honours maximumLineCount and elide, so a long preview is capped at the
        // three lines StatusListItem gives its subtitle instead of growing over the row below.
        function test_aLongPreviewIsCappedAtThreeLines() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("m1", "Messages",
                                 "This is a very long search result preview that has to be "
                                 + "capped at three lines instead of growing down over the "
                                 + "results under it. " + "Some more words to run past them. "
                                   .repeat(8))
            results.appendResult("m2", "Messages", "short one")
            const popup = openWith(results)

            const subtitle = findSubtitles(popup.contentItem)[0]
            const short = findSubtitles(popup.contentItem)[1]

            compare(subtitle.maximumLineCount, 3)
            compare(subtitle.lineCount, 3, "a long preview must fill exactly its three lines")
            verify(subtitle.truncated, "and say that it was cut")
            verify(subtitle.contentHeight <= 3 * short.contentHeight + 1,
                   "so it is no taller than three short ones")
        }

        function test_mentionNamesFollowTheResolver() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("m1", "Messages", `hi @${root.aliceKey}`)
            const popup = openWith(results, { [root.aliceKey]: "Alice" })

            verify(subtitleText(popup, 0).includes(`>@Alice</font></a>`), subtitleText(popup, 0))

            popup.names = { [root.aliceKey]: "Alicia" }
            tryVerify(() => subtitleText(popup, 0).includes(`>@Alicia</font></a>`), 1000,
                      subtitleText(popup, 0))
        }

        // styled text has no stylesheet, so a mention carries its color inline; links take
        // the Text's linkColor. Both have to follow the window's theme.
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
            verify(subtitle.text.includes(`<font color="${palette.mentionColor1}">@`),
                   subtitle.text)
            compare(subtitle.linkColor, palette.primaryColor1)
        }

        function test_emptyContentHasNoSubtitle() {
            const results = createTemporaryObject(resultsComponent, root)
            results.appendResult("c1", "Chats", "")
            const popup = openWith(results)

            compare(subtitleText(popup, 0), "")
        }
    }
}
