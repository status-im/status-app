import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Market.controls

SplitView {
    orientation: Qt.Vertical

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        MarketFooter {
            width: parent.width
            anchors.centerIn: parent
            pageSize: Number(pageSizeInput.text)
            totalCount: Number(tokenCountInput.text)
            currentPage: 1
            onSwitchPage: pageNumber => console.warn("switch page to ", pageNumber)
        }
    }

    ColumnLayout {
        SplitView.fillWidth: true
        Label {
            text: "Total Tokens Count"
        }
        TextField {
            id: tokenCountInput
            Layout.preferredWidth: 100
            validator: IntValidator { bottom: 0 }
            text: "2671"
        }

        Label {
            text: "Page Size"
        }
        TextField {
            id: pageSizeInput
            Layout.preferredWidth: 100
            validator: IntValidator { bottom: 0 }
            text: "100"
        }
    }
}

// category: Views

// https://www.figma.com/design/mh7hMVynZjL3eiV7e5oEyk/Trading?node-id=243-268215&m=dev
