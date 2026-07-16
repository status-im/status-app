import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils

// Renders static formatted chat text from a list of "blocks" (as produced by
// MarkdownUtils.toBlocks). Each block gets its own item so quote/code blocks can be
// decorated: text -> rich-text, code -> framed monospace, quote -> vertical bar + nested
// text/code blocks. The blocks are supplied via `blocks`; this component does not parse
// anything itself.
//
// When `selectable` is true, each region is a read-only TextEdit and a single selection can
// be dragged across blocks (desktop). Otherwise regions are plain Labels (mobile-optimised).
Control {
    id: root

    // List of block maps to render:
    //   {type:"text",  html}
    //   {type:"code",  code, bold, italic, strikethrough}
    //   {type:"quote", blocks:[ ...nested text/code blocks... ]}
    property var blocks: []

    // When true, text/code regions become read-only TextEdits and support a mouse selection
    // that spans blocks; when false, they are plain (non-selectable) Labels.
    property bool selectable: false

    // When true, a small, dimmed "(edited)" marker is appended after the last block.
    property bool edited: false
    property int editedMarkerFontSize: Theme.tertiaryTextFontSize

    // Combined selected text across all blocks ("" when nothing is selected).
    readonly property alias selectedText: d.selectedText

    // Emitted when the user clicks a mention pill (its pub key) or a link (its url) in the text.
    signal mentionClicked(string pubKey)
    signal linkClicked(string url)

    // Decoration colors
    property color codeBackgroundColor: Theme.palette.baseColor4
    property color codeBorderColor: Theme.palette.baseColor2
    property color quoteBarColor: Theme.palette.baseColor1
    property color quoteTextColor: Theme.palette.baseColor1
    property color linkColor: Theme.palette.primaryColor1
    property color mentionTextColor: Theme.palette.mentionColor1
    property color mentionBackgroundColor: Theme.palette.mentionColor4
    property color linkHoverColor: Theme.palette.primaryColor3

    // Copies the current cross-block selection to the clipboard.
    function copySelection() {
        if (root.selectedText.length > 0)
            ClipboardUtils.setText(root.selectedText)
    }

    onSelectableChanged: d.clearSelection()
    onBlocksChanged: d.clearSelection()
    onEditedChanged: d.clearSelection()

    // Renders one text or code region, instantiating exactly one child (via Loader): a Label
    // (not selectable) or a read-only TextEdit (selectable), plain or framed for code. Widths
    // flow down from `width` (set by the parent); heights flow up via implicitHeight.
    component BlockText: Loader {
        id: block

        property string content
        property bool isCode: false
        property bool bold: false
        property bool italic: false
        property bool strikethrough: false
        property bool selectable: false
        property color textColor: Theme.palette.directColor1

        sourceComponent: isCode ? (selectable ? codeEditComp : codeLabelComp)
                                : (selectable ? richEditComp : richLabelComp)

        // ── rich text (non-code) ──
        Component {
            id: richLabelComp
            Text {
                width: block.width
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                color: block.textColor
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize
                text: `<style>${d.baseStyle}</style>` + d.spanWrap(content)

                onLinkActivated: (link) => d.activateLink(link)
            }
        }
        Component {
            id: richEditComp
            TextEdit {
                id: textEdit

                property bool selectionParticipant: true
                property string hoveredLinkInternal

                readonly property string style:
                    d.baseStyle +
                    " a[href=\"" + hoveredLink + "\"] { background-color: " +
                    root.linkHoverColor + " }"
                property string effectiveStyle

                // keep selection if only style changes, otherwise selection is lost
                // on style change, including link hover
                onStyleChanged: {
                    const selStart = selectionStart
                    const selEnd = selectionEnd

                    effectiveStyle = `<style>${style}</style>`
                    select(selStart, selEnd)
                }

                width: block.width
                readOnly: true
                selectByMouse: false
                persistentSelection: true
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                selectionColor: root.palette.highlight
                color: block.textColor
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize

                text: effectiveStyle + d.spanWrap(content)
            }
        }

        // ── code (framed monospace) — a full-width Item wrapping the hugging frame ──
        Component {
            id: codeLabelComp

            Item {
                implicitHeight: inner.implicitHeight

                Label {
                    id: inner

                    padding: d.padding

                    background: Rectangle {
                        radius: 6
                        border.width: 1
                        border.color: root.codeBorderColor
                        color: root.codeBackgroundColor
                    }

                    width: Math.min(implicitWidth, parent.width)
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: block.textColor
                    font.family: Fonts.codeFont.family
                    font.pixelSize: root.font.pixelSize
                    font.bold: block.bold
                    font.italic: block.italic
                    font.strikeout: block.strikethrough
                    text: block.content
                }
            }
        }
        Component {
            id: codeEditComp
            Item {
                implicitHeight: inner.implicitHeight

                Rectangle {
                    width: inner.width
                    height: inner.implicitHeight
                    radius: 6
                    border.width: 1
                    border.color: root.codeBorderColor
                    color: root.codeBackgroundColor
                }

                TextEdit {
                    id: inner

                    property bool selectionParticipant: true

                    padding: d.padding
                    width: Math.min(implicitWidth, parent.width)

                    readOnly: true
                    selectByMouse: false
                    persistentSelection: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    selectionColor: root.palette.highlight
                    color: block.textColor
                    font.family: Fonts.codeFont.family
                    font.pixelSize: root.font.pixelSize
                    font.bold: block.bold
                    font.italic: block.italic
                    font.strikeout: block.strikethrough
                    text: block.content
                }
            }
        }
    }

    QtObject {
        id: d

        readonly property int padding: 8
        readonly property int quoteBarWidth: 3

        // The blocks actually rendered: `blocks` plus, when `edited`, a small "(edited)" marker
        // appended to the last text block (or as its own trailing text block).
        readonly property var renderBlocks: {
            if (!root.edited || root.blocks.length === 0)
                return root.blocks

            const marker = StringUtils.editedMarker(Theme.palette.baseColor1, root.editedMarkerFontSize)

            const out = root.blocks.slice() // shallow copy so `blocks` is not mutated
            const last = out[out.length - 1]
            if (last.type === "text")
                out[out.length - 1] = { type: "text", html: (last.html || "") + marker }
            else
                out.push({ type: "text", html: marker })
            return out
        }

        // Rich-text CSS rules for the non-code renderers
        readonly property string baseStyle:
            `code { background-color: ${root.codeBackgroundColor}`
            + `; font-family: '${Fonts.codeFont.family}' }`
            + ` a { color: ${root.linkColor} }`
            + ` a.mention { color: ${root.mentionTextColor}`
            + `; background-color: ${root.mentionBackgroundColor}`
            + `; text-decoration: none }`

        // prevent skipping whitespaces
        function spanWrap(content) {
            return `<span style=white-space:pre-wrap>${content}</span>`
        }

        property string selectedText: ""
        property var editors: []        // participant TextEdits, document order
        property var anchor: null       // { editor, pos }

        function clearSelection() {
            for (let i = 0; i < editors.length; ++i)
                if (editors[i])
                    editors[i].deselect()
            editors = []
            anchor = null
            selectedText = ""
        }

        // Recursively collect visible selection-participant editors, sorted by scene position.
        function collectEditors() {
            const out = []
            const walk = (item) => {
                const kids = item.children
                for (let i = 0; i < kids.length; ++i) {
                    const c = kids[i]
                    if (c.selectionParticipant === true && c.visible)
                        out.push(c)
                    walk(c)
                }
            }
            walk(root.contentItem)
            out.sort((a, b) => {
                const pa = a.mapToItem(root.contentItem, 0, 0)
                const pb = b.mapToItem(root.contentItem, 0, 0)
                return (pa.y - pb.y) || (pa.x - pb.x)
            })
            editors = out
        }

        // Maps a point (in contentItem coords) to { editor, pos }.
        function hitTest(x, y) {
            if (editors.length === 0)
                return null

            let nearest = editors[0]
            let nearestDist = Infinity
            for (let i = 0; i < editors.length; ++i) {
                const e = editors[i]
                const p = e.mapFromItem(root.contentItem, x, y)
                if (p.x >= 0 && p.x <= e.width && p.y >= 0 && p.y <= e.height)
                    return { editor: e, pos: e.positionAt(p.x, p.y) }
                const dy = p.y < 0 ? -p.y : (p.y > e.height ? p.y - e.height : 0)
                if (dy < nearestDist) {
                    nearestDist = dy
                    nearest = e
                }
            }
            // Outside every editor: clamp to the nearest one's top/bottom edge.
            const p = nearest.mapFromItem(root.contentItem, x, y)
            const pos = p.y < 0 ? 0
                      : (p.y > nearest.height ? nearest.length
                                              : nearest.positionAt(p.x, p.y))
            return { editor: nearest, pos: pos }
        }

        function indexOfEditor(e) {
            for (let i = 0; i < editors.length; ++i)
                if (editors[i] === e)
                    return i
            return -1
        }

        // Routes an activated <a href> to the right intent: links carry a URL scheme, while
        // mention hrefs are pub keys.
        function activateLink(href) {
            if (!href)
                return
            if (href.indexOf("://") >= 0)
                root.linkClicked(href)
            else
                root.mentionClicked(href)
        }

        // Selectable mode: the overlay swallows clicks, so resolve the link ourselves by finding
        // the editor under (x, y) (in contentItem coords) and asking it for the link there.
        function activateLinkAt(x, y) {
            for (let i = 0; i < editors.length; ++i) {
                const editor = editors[i]
                const point = editor.mapFromItem(root.contentItem, x, y)
                if (editor.contains(point)) {
                    const link = editor.linkAt(point.x, point.y)
                    if (link)
                        activateLink(link)
                    return
                }
            }
        }

        function applySelection(a, b) {
            if (!a || !b)
                return

            let fromIdx = indexOfEditor(a.editor), fromPos = a.pos
            let toIdx = indexOfEditor(b.editor), toPos = b.pos
            if (toIdx < fromIdx || (toIdx === fromIdx && toPos < fromPos)) {
                const ti = fromIdx, tp = fromPos
                fromIdx = toIdx; fromPos = toPos
                toIdx = ti; toPos = tp
            }

            for (let i = 0; i < editors.length; ++i) {
                const e = editors[i]
                if (i < fromIdx || i > toIdx)
                    e.deselect()
                else if (fromIdx === toIdx)
                    e.select(fromPos, toPos)
                else if (i === fromIdx)
                    e.select(fromPos, e.length)
                else if (i === toIdx)
                    e.select(0, toPos)
                else
                    e.select(0, e.length)
            }

            const parts = []
            for (let i = 0; i < editors.length; ++i) {
                const s = editors[i].selectedText.split("\u2028").join("\n")
                if (s.length > 0)
                    parts.push(s)
            }
            selectedText = parts.join("\n")
        }
    }

    contentItem: ColumnLayout {
        id: blocksColumn

        spacing: d.padding

        Repeater {
            model: d.renderBlocks

            // One Loader per block builds only the matching renderer (text/code or quote).
            delegate: Loader {
                id: blk

                required property var modelData
                readonly property var block: modelData

                Layout.fillWidth: true
                sourceComponent: blk.block.type === "quote" ? quoteComp : textComp

                Component {
                    id: textComp

                    BlockText {
                        width: blk.width
                        selectable: root.selectable
                        isCode: blk.block.type === "code"
                        content: blk.block.type === "code" ? (blk.block.code || "")
                                                           : (blk.block.html || "")
                        bold: !!blk.block.bold
                        italic: !!blk.block.italic
                        strikethrough: !!blk.block.strikethrough
                    }
                }

                Component {
                    id: quoteComp

                    RowLayout {
                        spacing: d.padding

                        Rectangle {
                            Layout.preferredWidth: d.quoteBarWidth
                            Layout.fillHeight: true
                            color: root.quoteBarColor

                            radius: width / 2
                        }
                        ColumnLayout {
                            id: quoteCol

                            Layout.fillWidth: true
                            spacing: d.padding

                            Repeater {
                                model: blk.block.blocks

                                delegate: BlockText {
                                    required property var modelData

                                    Layout.fillWidth: true

                                    selectable: root.selectable
                                    isCode: modelData.type === "code"
                                    content: modelData.type === "code" ? (modelData.code || "")
                                                                       : (modelData.html || "")
                                    bold: !!modelData.bold
                                    italic: !!modelData.italic
                                    strikethrough: !!modelData.strikethrough
                                    textColor: root.quoteTextColor // dim quoted text
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Cross-block selection: one overlay (over the whole content) drives the per-editor
    // selection from a single press+drag. It is a child of the Control (not the Column), so
    // it can fill the content area.
    MouseArea {
        anchors.fill: root.contentItem
        z: 100
        enabled: root.selectable
        visible: root.selectable
        cursorShape: Qt.IBeamCursor
        preventStealing: true

        property real pressX: 0
        property real pressY: 0
        property bool moved: false

        onPressed: (mouse) => {
            pressX = mouse.x
            pressY = mouse.y
            moved = false
            d.collectEditors()
            d.anchor = d.hitTest(mouse.x, mouse.y)
            d.applySelection(d.anchor, d.anchor)
        }
        onPositionChanged: (mouse) => {
            if (Math.abs(mouse.x - pressX) > 3 || Math.abs(mouse.y - pressY) > 3)
                moved = true
            if (d.anchor)
                d.applySelection(d.anchor, d.hitTest(mouse.x, mouse.y))
        }
        // A click (no drag) on a link activates it; a drag selects text instead.
        onReleased: (mouse) => {
            if (!moved)
                d.activateLinkAt(mouse.x, mouse.y)
        }
    }

    Shortcut {
        sequences: [StandardKey.Copy]
        enabled: root.selectable && root.selectedText.length > 0
        onActivated: root.copySelection()
    }
}
