import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Theme

import Storybook

SplitView {
    id: root

    Logs { id: logs }

    QtObject {
        id: d

        readonly property int emojiOnlyPx: Math.round(documentItem.appearance.font.pixelSize * 2.2)
        readonly property var samples: [
            everythingSegments,
            [{text: "🎉 🚀 ✅ 👩🏽‍💻 👨‍👩‍👧‍👦 🇵🇱 1️⃣"}]
        ]

        readonly property var everythingSegments: [
            { text: "Hey " },
            { text: "@Bob", href: "//0xc0ffee",
              mention: true },
            { text: ", " },
            { text: "@Alice", href: "//0xa11ce",
              mention: true },
            { text: " and " },
            { text: "@Mina", href: "//0x1234",
              mention: true },
            { text: " 👋🏽" },
            { text: "The ", newBlock: true },
            { text: "release build", bold: true },
            { text: " is " },
            { text: "red", strikethrough: true },
            { text: " green again 🎉 🚀 ✅ — see " },
            { text: "build results", href: "https://status.app/build/1234", underline: true },
            { text: " and the " },
            { text: "release notes", href: "https://status.app/releases", underline: true },
            { text: ". Run " },
            { text: "make run-statusq-tests", code: true },
            { text: " before you push." },
            { text: "You asked earlier:", newBlock: true },
            { text: "@Alice", href: "//0xa11ce", newBlock: true, quoteLevel: 1,
              mention: true },
            { text: ": is anyone looking at the " },
            { text: "nightly", italic: true },
            { text: " build? It has been red since Friday 😬 🛠️" },
            { text: "Was it the keycard tests again? 🤔", newBlock: true, quoteLevel: 2 },
            { text: "make tests-nim-linux", codeBlock: true, quoteLevel: 1 },
            { text: "It was the PIN retry. The fix:", newBlock: true },
            { text: "if (!card.ready)\n    return retry(3) // 🙈 not again", codeBlock: true },
            { text: "Thanks for the review, " },
            { text: "@Bob", href: "//0xc0ffee",
              mention: true },
            { text: "! 👩🏽‍💻 🙏🏽 Double-check the " },
            { text: "build results", href: "https://status.app/build/1234", underline: true },
            { text: " and " },
            { text: "ship it", bold: true, italic: true },
            { text: " 🚢" }
        ]

    }

    ScrollView {
        id: showcaseScroll
        SplitView.fillWidth: true
        SplitView.minimumWidth: 360
        clip: true
        contentWidth: Math.max(availableWidth, ctrlWidth.value + 32)
        background: Rectangle {
            objectName: "showcaseBackground"
            color: root.Theme.palette.background
        }

        ColumnLayout {
            width: showcaseScroll.contentWidth
            spacing: 16

            Label {
                Layout.fillWidth: true
                Layout.margins: 16
                text: "ChatTextItem"
                color: root.Theme.palette.directColor1
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                wrapMode: Text.Wrap
                color: root.Theme.palette.directColor1
                text: "Formatted text, mentions, links, emoji, quotes and code blocks. "
                      + "Drag to select across them, or click a link to highlight it."
            }
            ChatTextItem {
                appearance: ChatTextAppearance {
                    font.family: Fonts.baseFont.family
                    font.pixelSize: ctrlFontSize.value
                    lineHeight: ctrlLineHeight.value
                    color: root.Theme.palette.directColor1
                    linkColor: root.Theme.palette.primaryColor1
                    hoverHighlightColor: root.Theme.palette.primaryColor2
                    codeBackground: root.Theme.palette.baseColor4
                    codeBorderColor: root.Theme.palette.baseColor2
                    codeFontFamily: Fonts.codeFont.family
                    mentionColor: root.Theme.palette.primaryColor1
                    mentionBackground: root.Theme.palette.baseColor2
                    quoteColor: root.Theme.palette.baseColor1
                    emojiOnlyPixelSize: d.emojiOnlyPx
                    quoteBarColor: root.Theme.palette.baseColor1
                    quoteBarWidth: ctrlQuoteBarWidth.value
                    quoteSpacing: ctrlQuoteSpacing.value
                    selectionColor: root.Theme.palette.primaryColor1
                    selectionTextColor: root.Theme.palette.indirectColor1
                    editedMarkerFontSize: root.Theme.tertiaryTextFontSize
                    editedMarkerColor: root.Theme.palette.baseColor1
                }

                id: documentItem
                objectName: "chatTextItemShowcase"
                Layout.preferredWidth: ctrlWidth.value
                Layout.preferredHeight: contentHeight
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                segments: d.samples[ctrlMessage.currentIndex] || []
                selectable: ctrlSelectable.checked
                edited: ctrlEdited.checked

                onLinkActivated: link => {
                    highlightedLink = link
                    logs.logEvent("linkActivated", ["link"], [link])
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                color: root.Theme.palette.baseColor1
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
                text: "Hovered link: " + (documentItem.hoveredLink || "—")
            }
            Label {
                Layout.fillWidth: true
                Layout.margins: 16
                color: root.Theme.palette.baseColor1
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: "Selected text: " + (documentItem.selectedText || "—")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 280
        SplitView.preferredWidth: 340
        logsView.logText: logs.logText

        controls: ScrollView {
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 12

                GroupBox {
                    Layout.fillWidth: true
                    title: "Message"
                    ColumnLayout {
                        anchors.fill: parent
                        ComboBox {
                            id: ctrlMessage
                            objectName: "showcaseMessage"
                            Layout.fillWidth: true
                            model: ["All features", "Emoji only"]
                        }
                        CheckBox {
                            id: ctrlEdited
                            objectName: "showcaseEdited"
                            text: "Edited marker"
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Inline emoji follow the font line height; emoji-only messages: " + d.emojiOnlyPx + " px."
                        }
                    }
                }
                GroupBox {
                    Layout.fillWidth: true
                    title: "Layout"
                    ColumnLayout {
                        anchors.fill: parent
                        Label { text: "Width: " + ctrlWidth.value + " px" }
                        Slider {
                            id: ctrlWidth
                            objectName: "showcaseWidth"
                            Layout.fillWidth: true
                            from: 200; to: 900; stepSize: 10; value: 480
                        }
                        Label { text: "Font size: " + ctrlFontSize.value + " px" }
                        Slider {
                            id: ctrlFontSize
                            objectName: "showcaseFontSize"
                            Layout.fillWidth: true
                            from: 8; to: 40; stepSize: 1; value: root.Theme.primaryTextFontSize
                        }
                        Label { text: "Minimum line height: " + ctrlLineHeight.value + " px" }
                        Slider {
                            id: ctrlLineHeight
                            objectName: "showcaseLineHeight"
                            Layout.fillWidth: true
                            from: 14; to: 40; stepSize: 1; value: 22
                        }
                    }
                }
                GroupBox {
                    Layout.fillWidth: true
                    title: "Quotes"
                    ColumnLayout {
                        anchors.fill: parent
                        Label { text: "Bar width: " + ctrlQuoteBarWidth.value + " px" }
                        Slider {
                            id: ctrlQuoteBarWidth
                            objectName: "showcaseQuoteWidth"
                            Layout.fillWidth: true
                            from: 1; to: 8; stepSize: 1; value: 3
                        }
                        Label { text: "Spacing: " + ctrlQuoteSpacing.value + " px" }
                        Slider {
                            id: ctrlQuoteSpacing
                            objectName: "showcaseQuoteSpacing"
                            Layout.fillWidth: true
                            from: 2; to: 24; stepSize: 1; value: 8
                        }
                    }
                }
                GroupBox {
                    Layout.fillWidth: true
                    title: "Selection and links"
                    ColumnLayout {
                        anchors.fill: parent
                        CheckBox {
                            id: ctrlSelectable
                            objectName: "showcaseSelectable"
                            text: "Selectable"
                            checked: true
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Drag to select, double-click a word, triple-click a line, "
                                  + "and use Ctrl+C to copy. Quoted lines keep their > markers when copied."
                        }
                        Button {
                            objectName: "showcaseSelectAll"
                            Layout.fillWidth: true
                            focusPolicy: Qt.NoFocus
                            text: "Select all"
                            onClicked: {
                                documentItem.forceActiveFocus()
                                documentItem.selectAll()
                            }
                        }
                        Button {
                            Layout.fillWidth: true
                            enabled: !!documentItem.selectedText
                            focusPolicy: Qt.NoFocus
                            text: "Copy selection"
                            onClicked: {
                                documentItem.copySelection()
                                logs.logEvent("copied", ["text"], [documentItem.selectedText])
                            }
                        }
                        Button {
                            Layout.fillWidth: true
                            focusPolicy: Qt.NoFocus
                            text: "Clear selection"
                            onClicked: documentItem.clearSelection()
                        }
                        Button {
                            Layout.fillWidth: true
                            focusPolicy: Qt.NoFocus
                            enabled: !!documentItem.highlightedLink
                            text: "Clear link highlight"
                            onClicked: documentItem.highlightedLink = ""
                        }
                    }
                }
            }
        }
    }
}

// category: Chat
// status: good
