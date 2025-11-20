import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    /** required input property representing page size **/
    required property int pageSize
    /** required input property representing total count of items **/
    required property int totalCount
    /** required property representing current page set from outside **/
    required property int currentPage

    property bool compactMode

    /** signla to update next page **/
    signal switchPage(int pageNumber)

    QtObject {
        id: d

        // Calculate the starting index
        property int startIndex: ((paginator.currentPage - 1) * root.pageSize) + 1
        // Calculate the ending index (ensuring it doesn't exceed totalCount)
        property int endIndex: Math.min(paginator.currentPage * root.pageSize, root.totalCount)
        // Determine if there is not enough width to display both info text and paginator side by side
        readonly property bool isPortrait: infoText.contentWidth + paginator.implicitContentWidth > root.width
        // Calculate the center of the screen for paginator alignment
        readonly property int centerOfScreen: (root.width - paginator.implicitContentWidth)/2
    }

    topPadding: 20
    bottomPadding: 20

    contentItem: Flow {

        anchors.fill: parent
        flow: d.isPortrait ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 0

        StatusBaseText {
            id: infoText

            objectName: "infoText"

            width: d.isPortrait ? parent.width : contentWidth
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.additionalTextSize
            lineHeightMode: Text.FixedHeight
            lineHeight: paginator.height
            verticalAlignment: Qt.AlignVCenter
            horizontalAlignment: Qt.AlignHCenter

            text: qsTr("Showing %L1 to %L2 of %n result(s)", "", root.totalCount).arg(d.startIndex).arg(d.endIndex)
        }

        Paginator {
            id: paginator

            objectName: "paginator"

            leftPadding: d.isPortrait ?
                             d.centerOfScreen :
                             Math.max(0, d.centerOfScreen - infoText.contentWidth)

            pageSize: root.pageSize
            totalCount: root.totalCount
            currentPage: root.currentPage
            compactMode: root.compactMode
            onRequestPage: pageNumber => root.switchPage(pageNumber)
        }
    }
}
