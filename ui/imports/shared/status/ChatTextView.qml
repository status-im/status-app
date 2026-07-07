import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core.Theme

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

    // Combined selected text across all blocks ("" when nothing is selected).
    readonly property alias selectedText: d.selectedText

    // Emitted when the user clicks a mention pill (its pub key) or a link (its url) in the text.
    signal mentionClicked(string pubKey)
    signal linkClicked(string url)

    // Decoration colors
    property color codeBackgroundColor: Theme.palette.baseColor4
    property color codeBorderColor: Theme.palette.baseColor2
    property color quoteBarColor: Theme.palette.baseColor1
    property color linkColor: Theme.palette.primaryColor1
    property color mentionBackgroundColor: Theme.palette.mentionColor4

    // Copies the current cross-block selection to the clipboard.
    function copySelection() {
        if (root.selectedText.length > 0)
            ClipboardUtils.setText(root.selectedText)
    }

    onSelectableChanged: d.clearSelection()
    onBlocksChanged: d.clearSelection()

    // Renders one text or code region, instantiating exactly one child (via Loader): a Label
    // (not selectable) or a read-only TextEdit (selectable), plain or framed for code. Widths
    // flow down from `width` (set by the parent); heights flow up via implicitHeight.
    component BlockText: Loader {
        id: piece

        property string content
        property bool isCode: false
        property bool bold: false
        property bool italic: false
        property bool strikethrough: false
        property bool selectable: false

        // Rich-text HTML for the non-code renderers: a code-background CSS rule (so inline
        // `code` spans match the code frames / editor) plus the pre-wrapped content.
        readonly property string richText:
            "<style>code { background-color: " + root.codeBackgroundColor + " }"
            + " a { color: " + root.linkColor + " }"
            + " a.mention { background-color: " + root.mentionBackgroundColor + " }</style>"
            + "<span style=\"white-space:pre-wrap\">" + content + "</span>"

        sourceComponent: isCode ? (selectable ? codeEditComp : codeLabelComp)
                                : (selectable ? richEditComp : richLabelComp)

        // ── rich text (non-code) ──
        Component {
            id: richLabelComp
            Label {
                width: piece.width
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                color: Theme.palette.directColor1
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize
                // pre-wrap so extra/leading spaces are preserved
                text: piece.richText
                // Connecting this enables Text's built-in link click handling (non-selectable mode).
                onLinkActivated: (link) => d.activateLink(link)
            }
        }
        Component {
            id: richEditComp
            TextEdit {
                property bool selectionParticipant: true
                width: piece.width
                readOnly: true
                selectByMouse: false
                persistentSelection: true
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                selectionColor: root.palette.highlight
                color: Theme.palette.directColor1
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize
                text: piece.richText
            }
        }

        // ── code (framed monospace) — a full-width Item wrapping the hugging frame ──
        Component {
            id: codeLabelComp
            Item {
                implicitHeight: frame.implicitHeight
                Rectangle {
                    id: frame
                    width: inner.width + 16
                    implicitHeight: inner.implicitHeight + 16
                    radius: 6
                    border.width: 1
                    border.color: root.codeBorderColor
                    color: root.codeBackgroundColor

                    Label {
                        id: inner
                        x: 8; y: 8
                        width: Math.min(implicitWidth, piece.width - 16)
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.family: Fonts.codeFont.family
                        font.pixelSize: root.font.pixelSize
                        font.bold: piece.bold
                        font.italic: piece.italic
                        font.strikeout: piece.strikethrough
                        text: piece.content
                    }
                }
            }
        }
        Component {
            id: codeEditComp
            Item {
                implicitHeight: frame.implicitHeight
                Rectangle {
                    id: frame
                    width: inner.width + 16
                    implicitHeight: inner.implicitHeight + 16
                    radius: 6
                    border.width: 1
                    border.color: root.codeBorderColor
                    color: root.codeBackgroundColor

                    TextEdit {
                        id: inner
                        property bool selectionParticipant: true
                        x: 8; y: 8
                        width: Math.min(implicitWidth, piece.width - 16)
                        readOnly: true
                        selectByMouse: false
                        persistentSelection: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        selectionColor: root.palette.highlight
                        color: Theme.palette.directColor1
                        font.family: Fonts.codeFont.family
                        font.pixelSize: root.font.pixelSize
                        font.bold: piece.bold
                        font.italic: piece.italic
                        font.strikeout: piece.strikethrough
                        text: piece.content
                    }
                }
            }
        }
    }

    QtObject {
        id: d

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

    contentItem: Column {
        id: blocksColumn

        spacing: 8

        Repeater {
            model: root.blocks

            // One Loader per block builds only the matching renderer (text/code or quote).
            delegate: Item {
                id: blk

                required property var modelData
                readonly property var block: modelData

                width: blocksColumn.width
                implicitHeight: blockLoader.implicitHeight
                height: implicitHeight

                Loader {
                    id: blockLoader
                    width: parent.width
                    sourceComponent: blk.block.type === "quote" ? quoteComp : textComp
                }

                Component {
                    id: textComp
                    BlockText {
                        width: blockLoader.width
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
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 3
                            height: quoteCol.height
                            color: root.quoteBarColor

                            bottomLeftRadius: 3
                            topLeftRadius: 3
                        }
                        Column {
                            id: quoteCol
                            width: blockLoader.width - 11 // bar (3) + spacing (8)
                            spacing: 8

                            Repeater {
                                model: blk.block.blocks

                                delegate: BlockText {
                                    required property var modelData

                                    width: quoteCol.width
                                    selectable: root.selectable
                                    isCode: modelData.type === "code"
                                    content: modelData.type === "code" ? (modelData.code || "")
                                                                       : (modelData.html || "")
                                    bold: !!modelData.bold
                                    italic: !!modelData.italic
                                    strikethrough: !!modelData.strikethrough
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
