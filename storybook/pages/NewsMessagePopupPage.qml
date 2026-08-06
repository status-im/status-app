import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Controls

import shared.popups

SplitView {
    Logs { id: logs }
    orientation: Qt.Vertical
    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            anchors.centerIn: parent
            text: "Reopen"
            onClicked: popup.open()
        }


        QtObject {
            id: notificationMock

            property string id: "1"
            property string newsTitle: "Swaps around the corner!"
            property string newsDescription: "Status Desktop's next release brings the app up-to-speed with Status Mobile. That means: SWAPS!"
            property string newsContent: "Status Desktop's next release brings the app up-to-speed with Status Mobile. That means: SWAPS! Now you can trade Ethereum, Arbitrum and Optimism tokens directly in-app. Status leverages Paraswap so you always benefit from the best prices and fastest settlements!"
            property string newsLink: "https://status.app/"
            property string newsLinkLabel: linkLabelInput.text

            // The max height of the image is 300, but we handle it
            property string newsImageUrl: hasImage.checked ? "https://picsum.photos/438/400" : ""
            property double timestamp: Date.now()
            property double previousTimestamp: 0
            property bool read: false
            property bool dismissed: false
            property bool accepted: false
        }

        NewsMessagePopup {
            id: popup
            visible: true
            notification: notificationMock
            onLinkClicked: link => logs.logEvent("NewsMessagesPopup::onLinkClicked " + link)
        }
    }
   
    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            spacing: 8

            RowLayout {
                spacing: 4

                CheckBox {
                    id: hasImage
                    text: "Has Image"
                    checked: true
                }

                StatusInput {
                    id: linkLabelInput
                    label: "linkLabel"
                    text: "Read our blog post"
                }
            }

            StatusInput {
                id: newsTitleInput
                Layout.fillWidth: true
                label: "newsTitle"
                text: notificationMock.newsTitle
                onTextChanged: notificationMock.newsTitle = newsTitleInput.text
            }

            TextArea {
                id: newsContentInput
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                placeholderText: "newsContent"
                text: notificationMock.newsContent
                wrapMode: TextArea.Wrap
                onTextChanged: notificationMock.newsContent = newsContentInput.text
            }
        }
    }
}

// category: Popups
// status: good
