import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import StatusQ.Core.Theme
import shared.controls.chat

SplitView {

    Logs { id: logs }
    orientation: Qt.Vertical

    SplitView {

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Pane {
            SplitView.fillWidth: true
            Rectangle {
                id: wrapper
                anchors.fill: parent
                color: Theme.palette.statusChatInput.secondaryBackgroundColor

                ChatInputLinksPreviewArea {
                    id: chatInputLinkPreviewsArea
                    anchors.centerIn: parent
                    width: parent.width
                    imagePreviewArray: ["https://picsum.photos/200/300?random=1", "https://picsum.photos/200/300?random=1"]
                    linkPreviewModel: showLinkPreviewSettings ? emptyModel : mockedLinkPreviewModel
                    paymentRequestModel: mockedPaymentRequestModel
                    showLinkPreviewSettings: !linkPreviewEnabledSwitch.checked
                    visible: hasContent

                    onImageRemoved: (index) =>  logs.logEvent("ChatInputLinksPreviewArea::onImageRemoved: " + index)
                    onImageClicked: (chatImage) => logs.logEvent("ChatInputLinksPreviewArea::onImageClicked: " + chatImage)
                    onLinkReload: (link) => logs.logEvent("ChatInputLinksPreviewArea::onLinkReload: " + link)
                    onLinkClicked: (link) => logs.logEvent("ChatInputLinksPreviewArea::onLinkClicked: " + link)

                    onEnableLinkPreview: () => {
                                         linkPreviewEnabledSwitch.checked = true
                                         logs.logEvent("ChatInputLinksPreviewArea::onEnableLinkPreview")
                                        }
                    onEnableLinkPreviewForThisMessage: () => logs.logEvent("ChatInputLinksPreviewArea::onEnableLinkPreviewForThisMessage")
                    onDisableLinkPreview: () => logs.logEvent("ChatInputLinksPreviewArea::onDisableLinkPreview")
                    onDismissLinkPreviewSettings: () => logs.logEvent("ChatInputLinksPreviewArea::onDismissLinkPreviewSettings")
                    onDismissLinkPreview: (index) => logs.logEvent("ChatInputLinksPreviewArea::onDismissLinkPreview: " + index)
                }
            }
        }

        Pane {
            SplitView.preferredWidth: 300
            SplitView.fillHeight: true
            ColumnLayout {
                Label {
                    text: "Links preview enabled"
                }
                Switch {
                    id: linkPreviewEnabledSwitch
                }
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText
    }

    ListModel {
        id: emptyModel
    }

    LinkPreviewModel {
        id: mockedLinkPreviewModel
    }

    PaymentRequestModel {
        id: mockedPaymentRequestModel
    }
}

// category: Panels

// https://www.figma.com/file/Mr3rqxxgKJ2zMQ06UAKiWL/💬-Chat⎜Desktop?type=design&node-id=22341-184809&mode=design&t=VWBVK4DOUxr1BmTp-0
