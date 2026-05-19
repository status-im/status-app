import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.ActivityCenter.controls
import Models
import Storybook

import StatusQ.Core.Theme
import StatusQ.Components

import utils

SplitView {
    id: root

    Logs { id: logs }

    QtObject {
        id: d

        readonly property var oneAttachment: ["https://picsum.photos/320/240?10"]
        readonly property var threeAttachments: [
            "https://picsum.photos/320/240?1",
            "https://picsum.photos/320/240?2",
            "https://picsum.photos/320/240?9"
        ]
        readonly property var sevenAttachments: [
            "https://picsum.photos/320/240?3",
            "https://picsum.photos/320/240?4",
            "https://picsum.photos/320/240?5",
            "https://picsum.photos/320/240?6",
            "https://picsum.photos/320/240?7",
            "https://picsum.photos/320/240?8",
            "https://picsum.photos/320/240?1"
        ]
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        ColumnLayout {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            NotificationContentBlock {
                Layout.alignment: Qt.AlignHCenter
                Tracer {
                    visible: baseEditor.showTracer
                }
                Layout.preferredWidth: baseEditor.cardWidth
                preImageSource: contentBlockEditor.preImageVisible ? "https://picsum.photos/320/240?6" : ""
                preImageRadius: contentBlockEditor.preImageWithRadius ? 8 : 0
                contentText: contentBlockEditor.content
                contentMaxChars: contentBlockEditor.maxCharsContent
                attachments: contentBlockEditor.oneAttachment ? d.oneAttachment :
                                                                contentBlockEditor.threeAttachments ? d.threeAttachments :
                                                                                                      contentBlockEditor.sevenAttachments ? d.sevenAttachments : []
                imageClickable: contentBlockEditor.areImagesClickable
                imageCursorShape: contentBlockEditor.changeImageCursorShape ? Qt.PointingHandCursor : Qt.ArrowCursor

                onImageClicked: (image, mouse, imageSource, pos) => logs.logEvent("NotificationContentBlock::onImageClicked: " + imageSource)
                onLinkActivated: href => logs.logEvent("NotificationContentBlock::onLinkActivated --> Link clicked: " + href)
            }
        }
        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 160
            logsView.logText: logs.logText
        }
    }

    ScrollView {
        id: scroll
        SplitView.minimumWidth: 350
        SplitView.preferredWidth: 350
        clip: true

        Pane {
            ColumnLayout {
                width: scroll.width

                NotificationCardBaseEditor {
                    id: baseEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                    minCardWidth: 236
                }

                NotificationContentBlockEditor {
                    id: contentBlockEditor
                    Layout.rightMargin: 8
                    Layout.fillWidth: true
                }
            }
        }
    }
}
// category: Activity Center
// status: good
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=1912-363062&m=dev
