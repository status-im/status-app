import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ.Core.Theme

import Storybook
import Models

import AppLayouts.Wallet.views
import AppLayouts.Wallet.controls

SplitView {
    orientation: Qt.Vertical
    Logs { id: logs }

    Rectangle {
        SplitView.fillHeight: true
        SplitView.fillWidth: true
        color: Theme.palette.indirectColor1

        SendModalFooter {
            id: footer
            anchors.centerIn: parent
            implicitWidth: 595

            loading: loadingCheckbox.checked
            error: errorCheckbox.checked

            onReviewSendClicked: logs.logEvent("review send clicked")

            errorTags: errorCheckbox.checked ? errorTagsModel: null
        }
    }

    ObjectModel {
        id: errorTagsModel
        RouterErrorTag {
            errorTitle: "Error 1"
            buttonText: "Add ETH"
        }
        RouterErrorTag {
            errorTitle: "Error 2"
            buttonText: "Add ETH"
            errorDetails: ModelsData.descriptions.longLoremIpsum
            expandable: true
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        Column {
            CheckBox {
                id: loadingCheckbox
                text: "loading"
            }

            CheckBox {
                id: errorCheckbox
                text: "error"
            }

            Button {
                text: "set fees values"
                onClicked: {
                    loadingCheckbox.checked = false
                    footer.estimatedTime = "~60s"
                    footer.estimatedFees = "1.45 EUR"
                }
            }
        }
    }
}

// category: Views
