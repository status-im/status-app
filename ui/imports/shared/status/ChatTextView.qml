import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

// Renders static formatted chat text from a list of "blocks" (as produced by
// MarkdownUtils.toBlocks). Each block gets its own item so quote/code blocks can be
// decorated: text -> rich-text Label, code -> framed monospace Label, quote ->
// vertical bar + nested text/code blocks. The blocks are supplied via `blocks`;
// this component does not parse anything itself.
Control {
    id: root

    // List of block maps to render:
    //   {type:"text",  html}
    //   {type:"code",  code, bold, italic, strikethrough}
    //   {type:"quote", blocks:[ ...nested text/code blocks... ]}
    property var blocks: []

    // Decoration colors
    property color codeBackgroundColor: "#e8e8e8"
    property color codeBorderColor: "#cccccc"
    property color quoteBarColor: "#4A90D9"

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
                              : block.type === "code"  ? codeBox.implicitHeight
                                                       : textLabel.implicitHeight
                height: implicitHeight

                Label {
                    id: textLabel
                    visible: blk.block.type === "text"
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.RichText
                    font.family: root.font.family
                    font.pixelSize: root.font.pixelSize
                    // pre-wrap so extra/leading spaces are preserved
                    text: visible ? "<span style=\"white-space:pre-wrap\">"
                                    + blk.block.html + "</span>" : ""
                }

                Rectangle {
                    id: codeBox
                    visible: blk.block.type === "code"
                    width: codeLabel.width + 16
                    implicitHeight: codeLabel.implicitHeight + 16
                    radius: 6
                    border.width: 1
                    border.color: root.codeBorderColor
                    color: root.codeBackgroundColor
                }

                Label {
                    id: codeLabel
                    x: 8; y: 8
                    width: Math.min(implicitWidth, parent.width - 16)
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    font.family: Fonts.codeFont.family
                    font.pixelSize: root.font.pixelSize
                    font.bold: !!blk.block.bold
                    font.italic: !!blk.block.italic
                    font.strikeout: !!blk.block.strikethrough
                    text: codeBox.visible ? blk.block.code : ""
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

                            delegate: Item {
                                id: sub

                                required property var modelData
                                readonly property var block: modelData

                                width: quoteCol.width
                                implicitHeight: block.type === "code"
                                                ? subCode.implicitHeight
                                                : subText.implicitHeight
                                height: implicitHeight

                                Label {
                                    id: subText
                                    visible: sub.block.type !== "code"
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    textFormat: Text.RichText
                                    font.family: root.font.family
                                    font.pixelSize: root.font.pixelSize
                                    // pre-wrap preserves extra/leading spaces
                                    text: visible ? "<span style=\"white-space:pre-wrap\">"
                                                    + sub.block.html + "</span>" : ""
                                }
                                Rectangle {
                                    id: subCode
                                    visible: sub.block.type === "code"
                                    width: subCodeLabel.width + 16
                                    implicitHeight: subCodeLabel.implicitHeight + 16
                                    radius: 6
                                    border.width: 1
                                    border.color: root.codeBorderColor
                                    color: root.codeBackgroundColor
                                }

                                Label {
                                    id: subCodeLabel
                                    x: 8; y: 8
                                    width: Math.min(implicitWidth, parent.width - 16)
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                    font.family: Fonts.codeFont.family
                                    font.pixelSize: root.font.pixelSize
                                    font.bold: !!sub.block.bold
                                    font.italic: !!sub.block.italic
                                    font.strikeout: !!sub.block.strikethrough
                                    text: subCode.visible ? sub.block.code : ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
