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

        // Markdown sources, converted the way StatusMessageReply does it.
        readonly property var samples: [
            {title: "LTR, fits", source: "See you at the **release** meeting"},
            {title: "RTL Arabic, fits", source: "مرحبا، كيف حالك اليوم؟"},
            {title: "RTL Hebrew, fits", source: "שלום, מה שלומך היום?"},
            {title: "RTL with LTR words", source: "تم إصلاح **Status** في الإصدار 2.31"},
            {title: "LTR with RTL words", source: "The greeting is مرحبا in Arabic"},
            {title: "RTL quote", source: "> هذا اقتباس من رسالة سابقة"},
            {title: "LTR, truncated", source: "This reply is long enough that the preview has to cut it off with an ellipsis at the end"},
            {title: "RTL, truncated", source: "هذا رد طويل بما يكفي بحيث يجب على المعاينة قطعه وإضافة علامة الحذف في نهايته عند العرض"}
        ]
    }

    // One sample: the item, outlined to show its bounds.
    component SampleRow: ColumnLayout {
        id: row

        property string title
        property string source

        spacing: 4
        Layout.leftMargin: 16
        Layout.rightMargin: 16

        Label {
            text: row.title
            color: root.Theme.palette.directColor1
            font.bold: true
        }

        Item {
            implicitWidth: ctrlWidth.value
            implicitHeight: item.implicitHeight

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: root.Theme.palette.baseColor2
            }

            ChatSingleLineTextItem {
                id: item
                width: parent.width
                clip: true
                edited: ctrlEdited.checked
                segments: MarkdownUtils.toChatTextSegments(row.source, {})
                appearance: ChatTextAppearance {
                    font.family: Fonts.baseFont.family
                    font.pixelSize: ctrlFontSize.value
                    color: root.Theme.palette.directColor1
                    linkColor: root.Theme.palette.primaryColor1
                    codeBackground: root.Theme.palette.baseColor4
                    codeFontFamily: Fonts.codeFont.family
                    mentionColor: root.Theme.palette.primaryColor1
                    mentionBackground: root.Theme.palette.baseColor2
                    quoteColor: root.Theme.palette.baseColor1
                    editedMarkerFontSize: root.Theme.tertiaryTextFontSize
                    editedMarkerColor: root.Theme.palette.baseColor1
                }
                onTruncatedChanged: logs.logEvent("truncatedChanged", ["title", "truncated"],
                                                  [row.title, truncated])
            }
        }
    }

    ScrollView {
        id: showcaseScroll
        SplitView.fillWidth: true
        SplitView.minimumWidth: 360
        clip: true
        contentWidth: Math.max(availableWidth, ctrlWidth.value + 32)
        background: Rectangle {
            color: root.Theme.palette.background
        }

        ColumnLayout {
            width: showcaseScroll.contentWidth
            spacing: 20

            Label {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.bottomMargin: 0
                text: "ChatSingleLineTextItem"
                color: root.Theme.palette.directColor1
                font.bold: true
            }

            Repeater {
                model: d.samples
                delegate: SampleRow {
                    required property var modelData
                    title: modelData.title
                    source: modelData.source
                }
            }

            SampleRow {
                title: "Custom"
                source: ctrlCustom.text
                Layout.bottomMargin: 16
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
                    title: "Layout"

                    ColumnLayout {
                        anchors.fill: parent

                        Label { text: "Width: " + ctrlWidth.value + " px" }
                        Slider {
                            id: ctrlWidth
                            Layout.fillWidth: true
                            from: 80; to: 900; stepSize: 10; value: 420
                        }
                        Label { text: "Font size: " + ctrlFontSize.value + " px" }
                        Slider {
                            id: ctrlFontSize
                            Layout.fillWidth: true
                            from: 8; to: 32; stepSize: 1; value: root.Theme.secondaryTextFontSize
                        }
                        CheckBox {
                            id: ctrlEdited
                            text: "Edited marker"
                        }
                    }
                }

                GroupBox {
                    Layout.fillWidth: true
                    title: "Custom message (markdown)"

                    TextArea {
                        id: ctrlCustom
                        anchors.fill: parent
                        // A wrapping text's implicit width follows its width;
                        // a fixed one keeps the GroupBox from sizing off it.
                        implicitWidth: 100
                        wrapMode: TextEdit.Wrap
                        text: "שלום **עולם** 👋"
                    }
                }
            }
        }
    }
}

// category: Chat
// status: good
