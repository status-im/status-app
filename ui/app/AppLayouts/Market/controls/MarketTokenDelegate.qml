import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

StatusItemDelegate {
    id: root

    /** Input property representing token name **/
    property string tokenName
    /** Input property representing token symbol **/
    property string tokenSymbol
    /** Input property representing icon source for token **/
    property string iconSource
    /** Input property representing token market price **/
    property string price
    /* Input property representing color of text -
    - green: if change is positive
    - red: if change is negative */
    property string changePct24HourColor
    /* Input property representing percentage change in
    market price in the last 24 hours */
    property string changePct24Hour
    /* Input property representing volume
    in last 24 hours */
    property string volume24Hour
    /* Input property representing token market cap */
    property string marketCap
    /* Input property if token is loading */
    property bool loading
    /** Input property representing index of token list **/
    property string indexString
    /** Input property holding if token is last item in the list **/
    property bool isLastItem

    property bool compactMode: false

    QtObject {
        id: d

        property int columnNum: root.compactMode ? 2 : 5

        // Split into 2 or 5 different columns of equal width
        readonly property int columnWidth:
            (root.width - indexText.width - icon.width - Theme.xlPadding) / d.columnNum
        // Minimum width of a column
        readonly property int minColumnWidth: root.compactMode ? 80 : 130
    }

    implicitHeight: 76
    padding: 0
    cursorShape: Qt.ArrowCursor

    background: Rectangle {
        color: root.hovered ? Theme.palette.baseColor4: StatusColors.transparent

        // Divider on top
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.palette.baseColor2
            visible: index > 0
        }

        // Divider at the bottom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.palette.baseColor2
            visible: root.isLastItem
        }
    }

    contentItem: RowLayout {
        spacing: 0

            // Index
            StatusTextWithLoadingState {
                id: indexText

                objectName: "indexText"

                Layout.preferredWidth: idxMetrics.advanceWidth

                text: root.indexString
                font.pixelSize: Theme.additionalTextSize
                lineHeight: 18
                lineHeightMode: Text.FixedHeight
                horizontalAlignment: Text.AlignHCenter
                loading: root.loading
            }

            // Token Icon
            StatusRoundedImage {
                id: icon

                objectName: "icon"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.leftMargin: Theme.padding

                image.source: root.iconSource
                LoadingComponent {
                    anchors.fill: parent
                    visible: root.loading
                }
            }

            // Name + Symbol
            ColumnLayout {
                id: nameSymbolBox

                Layout.preferredWidth: d.columnWidth
                Layout.minimumWidth: d.minColumnWidth
                Layout.leftMargin: 12
                spacing: 0


                StatusTextWithLoadingState {
                    objectName: "tokenNameText"

                    Layout.fillWidth: true

                    text: root.tokenName
                    font.weight: Font.Medium
                    lineHeight: 22
                    lineHeightMode: Text.FixedHeight
                    leftPadding: 0
                    loading: root.loading
                    elide: Text.ElideRight
                }
                StatusTextWithLoadingState {
                    objectName: "tokenSymbolText"

                    Layout.fillWidth: true

                    text: root.tokenSymbol
                    customColor: Theme.palette.baseColor1
                    lineHeight: 22
                    lineHeightMode: Text.FixedHeight
                    leftPadding: 0
                    loading: root.loading
                    visible: !!text
                }
            }

            // Price
            StatusTextWithLoadingState {
                objectName: "priceText"

                Layout.preferredWidth: d.columnWidth
                Layout.minimumWidth: d.minColumnWidth

                text: root.price
                font.weight: Font.Medium
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
                horizontalAlignment: Qt.AlignRight
                leftPadding: d.columnWidth - maximumLoadingStateWidth
                loading: root.loading
            }

            // Change 24 Hour
            StatusTextWithLoadingState {
                visible: !root.compactMode
                objectName: "changePct24HrText"

                Layout.preferredWidth: d.columnWidth
                Layout.minimumWidth: d.minColumnWidth

                text: root.changePct24Hour
                customColor: root.changePct24HourColor
                font.weight: Font.Medium
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
                horizontalAlignment: Qt.AlignRight
                leftPadding: d.columnWidth - maximumLoadingStateWidth
                loading: root.loading
            }

            // 24 hour Volume
            StatusTextWithLoadingState {
                visible: !root.compactMode
                objectName: "volume24HrText"

                Layout.preferredWidth: d.columnWidth
                Layout.minimumWidth: d.minColumnWidth

                text: root.volume24Hour
                font.weight: Font.Medium
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
                horizontalAlignment: Qt.AlignRight
                leftPadding: d.columnWidth - maximumLoadingStateWidth
                loading: root.loading
            }

            // Market Cap
            StatusTextWithLoadingState {
                visible: !root.compactMode
                objectName: "marketCapText"

                Layout.preferredWidth: d.columnWidth
                Layout.minimumWidth: d.minColumnWidth

                text: root.marketCap
                font.weight: Font.Medium
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
                horizontalAlignment: Qt.AlignRight
                leftPadding: d.columnWidth - maximumLoadingStateWidth
                rightPadding: Theme.padding
                loading: root.loading
            }
    }

    TextMetrics {
        id: idxMetrics
        font: indexText.font
        text: "999" // Dummy text to calculate width
    }
}
