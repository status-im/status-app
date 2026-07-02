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

    // Decoration colors
    property color codeBackgroundColor: "#e8e8e8"
    property color codeBorderColor: "#cccccc"
    property color quoteBarColor: "#4A90D9"

    // Copies the current cross-block selection to the clipboard.
    function copySelection() {
        if (root.selectedText.length > 0)
            ClipboardUtils.setText(root.selectedText)
    }

    onSelectableChanged: d.clearSelection()
    onBlocksChanged: d.clearSelection()

    // Renders one text or code region as a Label (not selectable) or a read-only TextEdit
    // (selectable). Both variants are instantiated and toggled by visibility (no Loader, to
    // keep the no-binding-loop sizing). Code regions keep their framed monospace look.
    component BlockText: Item {
        id: piece

        property string content
        property bool isCode: false
        property bool bold: false
        property bool italic: false
        property bool strikethrough: false
        property bool selectable: false

        implicitHeight: isCode ? codeFrame.implicitHeight
                               : (selectable ? richEdit.implicitHeight : richLabel.implicitHeight)

        // ── rich text (non-code) ──
        Label {
            id: richLabel
            visible: !piece.isCode && !piece.selectable
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.RichText
            font.family: root.font.family
            font.pixelSize: root.font.pixelSize
            // pre-wrap so extra/leading spaces are preserved
            text: visible ? "<span style=\"white-space:pre-wrap\">" + piece.content + "</span>" : ""
        }
        TextEdit {
            id: richEdit
            property bool selectionParticipant: true
            visible: !piece.isCode && piece.selectable
            width: parent.width
            readOnly: true
            selectByMouse: false
            persistentSelection: true
            wrapMode: Text.Wrap
            textFormat: Text.RichText
            selectionColor: root.palette.highlight
            font.family: root.font.family
            font.pixelSize: root.font.pixelSize
            text: visible ? "<span style=\"white-space:pre-wrap\">" + piece.content + "</span>" : ""
        }

        // ── code (framed monospace) ──
        Rectangle {
            id: codeFrame
            visible: piece.isCode
            width: (piece.selectable ? codeEdit.width : codeLabel.width) + 16
            implicitHeight: (piece.selectable ? codeEdit.implicitHeight
                                              : codeLabel.implicitHeight) + 16
            radius: 6
            border.width: 1
            border.color: root.codeBorderColor
            color: root.codeBackgroundColor

            Label {
                id: codeLabel
                x: 8; y: 8
                visible: piece.isCode && !piece.selectable
                width: Math.min(implicitWidth, piece.width - 16)
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.family: Fonts.codeFont.family
                font.pixelSize: root.font.pixelSize
                font.bold: piece.bold
                font.italic: piece.italic
                font.strikeout: piece.strikethrough
                text: piece.isCode ? piece.content : ""
            }
            TextEdit {
                id: codeEdit
                property bool selectionParticipant: true
                x: 8; y: 8
                visible: piece.isCode && piece.selectable
                width: Math.min(implicitWidth, piece.width - 16)
                readOnly: true
                selectByMouse: false
                persistentSelection: true
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                selectionColor: root.palette.highlight
                font.family: Fonts.codeFont.family
                font.pixelSize: root.font.pixelSize
                font.bold: piece.bold
                font.italic: piece.italic
                font.strikeout: piece.strikethrough
                text: piece.isCode ? piece.content : ""
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

            // Visibility-based (no Loader) to avoid Loader height binding loops;
            // each delegate sizes to its visible child's content.
            delegate: Item {
                id: blk

                required property var modelData
                readonly property var block: modelData

                width: blocksColumn.width
                implicitHeight: block.type === "quote" ? quoteRow.implicitHeight
                                                       : topText.implicitHeight
                height: implicitHeight

                BlockText {
                    id: topText
                    visible: blk.block.type !== "quote"
                    width: parent.width
                    selectable: root.selectable
                    isCode: blk.block.type === "code"
                    content: blk.block.type === "code" ? (blk.block.code || "")
                                                       : (blk.block.html || "")
                    bold: !!blk.block.bold
                    italic: !!blk.block.italic
                    strikethrough: !!blk.block.strikethrough
                }

                Row {
                    id: quoteRow
                    visible: blk.block.type === "quote"
                    width: parent.width
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
                        width: parent.width - 11 // bar (3) + spacing (8)
                        spacing: 8

                        Repeater {
                            model: quoteRow.visible ? blk.block.blocks : []

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

        onPressed: (mouse) => {
            d.collectEditors()
            d.anchor = d.hitTest(mouse.x, mouse.y)
            d.applySelection(d.anchor, d.anchor)
        }
        onPositionChanged: (mouse) => {
            if (d.anchor)
                d.applySelection(d.anchor, d.hitTest(mouse.x, mouse.y))
        }
    }

    Shortcut {
        sequences: [StandardKey.Copy]
        enabled: root.selectable && root.selectedText.length > 0
        onActivated: root.copySelection()
    }
}
