import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import SortFilterProxyModel

import shared.status

Item {
    id: root

    readonly property var emph: textArea.emphasisAt(textArea.cursorPosition)
    readonly property var vemph: textArea.emphasisAtInsertion(textArea.cursorPosition)

    function randomName() {
        const n = 1 + Math.floor(Math.random() * 5)
        let s = "@"
        for (let i = 0; i < n; ++i)
            s += String.fromCharCode(65 + Math.floor(Math.random() * 26))
        return s
    }
    function randomPubKey() {
        const chars = "0123456789abcdef"
        let s = "0x"
        for (let i = 0; i < 8; ++i)
            s += chars[Math.floor(Math.random() * chars.length)]
        return s
    }

    // Replaces the "@filter" being typed with a mention pill + trailing space.
    function acceptSuggestion(name, pubKey) {
        const cursor = textArea.cursorPosition
        const at = cursor - textArea.mentionsFilter.length - 1 // the "@"
        textArea.remove(at, cursor)
        textArea.insertMention(at, "@" + name, pubKey)               // caret advances past the pill
        textArea.insert(textArea.cursorPosition, " ")
        d.dismissed = false
    }

    // Accepts the highlighted suggestion when the popup is open; otherwise lets the key
    // fall through to the editor's default handling.
    function acceptOrPassSuggestion(event) {
        if (suggestionsPopup.visible) {
            const item = suggestionsProxy.get(suggestionsList.currentIndex)
            if (item)
                acceptSuggestion(item.name, item.pubKey)
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    QtObject {
        id: d

        // True while the user has dismissed (Escape) the popup for the current @-token;
        // reset when the token changes so typing re-shows suggestions.
        property bool dismissed: false
    }

    // Sample users to mention (display name + pub key). Some share prefixes so filtering
    // is visible (e.g. typing "@al").
    ListModel {
        id: usersModel

        Component.onCompleted: {
            const names = ["Alice", "Alicia", "Alan", "Albert", "Bob", "Bobby",
                           "Charlie", "Dave", "Eve", "Frank", "Grace", "Heidi"]
            for (let i = 0; i < names.length; ++i)
                append({ name: names[i], pubKey: root.randomPubKey() })
        }
    }

    // The filtered subset shown in the popup — filtered live by the editor's mentionsFilter.
    SortFilterProxyModel {
        id: suggestionsProxy

        sourceModel: usersModel
        filters: SearchFilter {
            roleName: "name"
            searchPhrase: textArea.mentionsFilter
        }
    }

    Connections {
        target: textArea

        // A changed @-token (more typing, or moving away) re-arms the popup.
        function onMentionsFilterChanged() { d.dismissed = false }
        function onEnteringSuggestionChanged() { d.dismissed = false }
    }

    // Suggestions list shown over the caret.
    Popup {
        id: suggestionsPopup

        parent: textArea
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 1

        readonly property rect caret: {
            textArea.text; textArea.cursorPosition // reposition as the caret moves
            return textArea.positionToRectangle(textArea.cursorPosition)
        }
        x: caret.x
        y: caret.y + caret.height

        visible: textArea.enteringSuggestion && suggestionsProxy.count > 0 && !d.dismissed

        background: Rectangle {
            color: "white"
            border.color: "#cccccc"
            radius: 4
        }

        contentItem: ListView {
            id: suggestionsList

            implicitWidth: 260
            implicitHeight: Math.min(contentHeight, 6 * 40)
            clip: true
            model: suggestionsProxy

            onCountChanged: currentIndex = 0
            onVisibleChanged: currentIndex = 0

            delegate: ItemDelegate {
                width: ListView.view.width
                highlighted: ListView.isCurrentItem

                contentItem: Column {
                    spacing: 0
                    Text {
                        width: parent.width
                        font.bold: true
                        text: model.name
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        font.pixelSize: 11
                        color: "#888888"
                        text: model.pubKey
                        elide: Text.ElideMiddle
                    }
                }

                HoverHandler {
                    onHoveredChanged: if (hovered) suggestionsList.currentIndex = index
                }
                onClicked: root.acceptSuggestion(model.name, model.pubKey)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12

        SplitView {
            orientation: Qt.Vertical

            Layout.fillWidth: true
            Layout.fillHeight: true

            // Input (left) and static HTML render (right), side by side, 50% each.
            RowLayout {
                SplitView.fillHeight: true
                SplitView.minimumHeight: 160

                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        font.bold: true
                        text: "Input:"
                    }

                    ScrollView {
                        id: scrollView

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        contentWidth: availableWidth

                        ChatTextArea {
                            id: textArea

                            background: null

                            font.pixelSize: 15
                            codeBackground: "#e8e8e8"
                            quoteBarVisible: quoteBarSwitch.checked

                            // Mention-suggestions navigation is handled here (in the page),
                            // not inside ChatTextArea. These attached handlers coexist with
                            // the component's own Keys.onPressed and only act while the popup
                            // is open; otherwise the keys pass through to the editor.
                            Keys.onUpPressed: (event) => {
                                if (suggestionsPopup.visible) {
                                    // Stop at the first item (no wrap-around).
                                    suggestionsList.currentIndex =
                                        Math.max(suggestionsList.currentIndex - 1, 0)
                                    event.accepted = true
                                } else {
                                    event.accepted = false
                                }
                            }
                            Keys.onDownPressed: (event) => {
                                if (suggestionsPopup.visible) {
                                    // Stop at the last item (no wrap-around).
                                    suggestionsList.currentIndex =
                                        Math.min(suggestionsList.currentIndex + 1,
                                                 suggestionsList.count - 1)
                                    event.accepted = true
                                } else {
                                    event.accepted = false
                                }
                            }
                            Keys.onReturnPressed: (event) => root.acceptOrPassSuggestion(event)
                            Keys.onEnterPressed: (event) => root.acceptOrPassSuggestion(event)
                            Keys.onTabPressed: (event) => root.acceptOrPassSuggestion(event)
                            Keys.onEscapePressed: (event) => {
                                if (suggestionsPopup.visible) {
                                    d.dismissed = true
                                    event.accepted = true
                                } else {
                                    event.accepted = false
                                }
                            }

                            text:
`Some **bold** text there!
Some *italic* text text there!

Some in-line emoji: 😎🤪🎃

This is ~~strikethrough~~ text.

Quote with nested code:
> A quote block here
> second quoted line
> \`\`\`
> code nested in the quote
> \`\`\`

Both bold and italics goes here: ***bold italic***
And **bold** and *italic* together in a single line.

**multi-
line bold here**

**Code:**

Sometimes it's enough to use \`inline code\`.

For bigger chunks of code it's better to use triple-ticks code block:

\`\`\`
#include <iostream>
using namespace std;

int main() {
    // This statement prints "Hello World"
    cout << "Hello World";

    return 0;
}
\`\`\`

**Links:**

Plain link: https://status.im
Bold link: **https://status.im/bold**
Star in URL (no italic): https://x.com/a*b*c
Link in code (not highlighted): \`https://status.im\`

**Unclosed code fence (toggle flag above to format):**

\`\`\`
unclosed fence here (no closing triple-tick)
**bold suppressed when format unclosed code fence flag on**
`
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        font.bold: true
                        text: `Static HTML render (${selectableSwitch.checked ? "" : "not "}selectable):`
                    }

                    ScrollView {
                        id: htmlScroll

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        contentWidth: availableWidth

                        padding: 10

                        // One item per block, so quote/code blocks can be decorated.
                        ChatTextView {
                            id: chatTextView

                            width: htmlScroll.availableWidth

                            font.family: Fonts.baseFont.family
                            font.pixelSize: textArea.font.pixelSize
                            selectable: selectableSwitch.checked

                            blocks: {
                                textArea.text            // re-build on every edit
                                textArea.enlargeEmojis   // and when the emoji toggle changes
                                return MarkdownUtils.toBlocks(textArea.textDocument,
                                                              textArea.formatUnclosedCodeFence,
                                                              textArea.enlargeEmojis)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                SplitView.preferredHeight: 200
                SplitView.minimumHeight: 80

                visible: debugSwitch.checked
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    font.bold: true
                    text: "AST dump:"
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    contentWidth: availableWidth

                    TextArea {
                        readOnly: true
                        wrapMode: TextEdit.NoWrap
                        font.family: Fonts.codeFont.family
                        font.pixelSize: 13
                        text: MarkdownUtils.dumpAst(textArea.text,
                                                    textArea.formatUnclosedCodeFence,
                                                    rangesSwitch.checked)
                    }
                }
            }

            ColumnLayout {
                SplitView.preferredHeight: 160
                SplitView.minimumHeight: 80

                visible: debugSwitch.checked
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    font.bold: true
                    text: "detected links:"
                }

                ListView {
                    id: linksListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    model: textArea.linksModel

                    delegate: Text {
                        width: ListView.view.width
                        text: model.text + " @ " + model.start + " +" + model.length

                        elide: Text.ElideMiddle

                        MouseArea {
                            id: linkMouseArea

                            hoverEnabled: true

                            anchors.fill: parent
                        }

                        Rectangle {
                            parent: textArea

                            z: -1

                            visible: linkMouseArea.containsMouse

                            readonly property rect position: {
                                textArea.text
                                textArea.contentWidth

                                const start = textArea.positionToRectangle(model.start)
                                const end = textArea.positionToRectangle(model.start + model.length)

                                const rect = Qt.rect(
                                    start.x,
                                    start.y,
                                    end.x - start.x,
                                    start.height
                                )

                                return rect
                            }

                            x: position.x
                            y: position.y
                            width: position.width
                            height: position.height

                            border.color: "darkblue"
                            color: "lightblue"
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false

            MenuSeparator {
                Layout.fillWidth: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: 10

            Switch {
                text: "Format unclosed code fence"
                checked: textArea.formatUnclosedCodeFence
                onToggled: textArea.formatUnclosedCodeFence = checked
            }
            Switch {
                id: debugSwitch

                text: "Show AST dump & detected links"
            }
            Switch {
                id: rangesSwitch

                text: "AST ranges"
                checked: true
                enabled: debugSwitch.checked
            }
            Switch {
               id: quoteBarSwitch

               text: "Quote block vertical line"
               checked: true
            }
            Switch {
                text: "Enlarge emojis"
                checked: textArea.enlargeEmojis
                onToggled: textArea.enlargeEmojis = checked
            }
            Switch {
                id: selectableSwitch

                checked: true
                text: "Selectable static text"
            }
            }
            Button {
                focusPolicy: Qt.NoFocus

                text: "Add random mention"
                onClicked: {
                    const pos = textArea.cursorPosition
                    textArea.insertMention(pos, root.randomName(), root.randomPubKey())
                    textArea.insert(textArea.cursorPosition, " ")
                }
            }
            Row {
                spacing: 16
                Text { text: "In unclosed code fence:" }
                Text {
                    text: {
                        textArea.text
                        return textArea.inUnclosedCodeFence(textArea.cursorPosition) ? "true" : "false"
                    }
                }
            }

            Row {
                spacing: 16
                Text { text: "entering suggestion: " + textArea.enteringSuggestion }
                Text { text: "mentions filter: \"" + textArea.mentionsFilter + "\"" }
            }

            Row {
                spacing: 16
                Text { text: "cursor: " + textArea.cursorPosition }
                Text {
                    readonly property bool hasSelection:
                        textArea.selectionStart !== textArea.selectionEnd
                    text: hasSelection
                          ? "selection: [" + textArea.selectionStart + ", " + textArea.selectionEnd + ")"
                          : "selection: none"
                }
            }

            Row {
                spacing: 16
                Text { text: "emphasis at:\t"}
                Text { text: "bold: "          + emph.bold }
                Text { text: "italic: "        + emph.italic }
                Text { text: "strikethrough: " + emph.strikethrough }
            }
            Row {
                spacing: 16

                Text { text: "emphasis at insertion:\t"}
                Text { text: "bold: "          + vemph.bold }
                Text { text: "italic: "        + vemph.italic }
                Text { text: "strikethrough: " + vemph.strikethrough }
            }
        }
    }
}

// category: Chat
// status: good
