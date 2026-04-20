import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

Control {
    id: root

    // [{primary:string, secondary:string, image:string}]
    required property var newsModel

    background: Rectangle {
        color: Theme.palette.neutral95
        radius: 20
    }

    verticalPadding: Theme.padding
    horizontalPadding: Theme.xlPadding * 2

    contentItem: ColumnLayout {
        id: newsPage
        readonly property string primaryText: root.newsModel.get(pageIndicator.currentIndex).primary
        readonly property string secondaryText: root.newsModel.get(pageIndicator.currentIndex).secondary

        Image {
            Layout.fillWidth: true
            Layout.maximumWidth: 460
            Layout.fillHeight: true
            Layout.maximumHeight: 582
            Layout.alignment: Qt.AlignHCenter
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            source: Assets.png(root.newsModel.get(pageIndicator.currentIndex).image)
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: newsPage.primaryText
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.DemiBold
            color: StatusColors.white
            wrapMode: Text.WordWrap
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: newsPage.secondaryText
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.additionalTextSize
            color: StatusColors.white
            wrapMode: Text.WordWrap
        }

        StatusLoadingPageIndicator {
            id: pageIndicator

            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            Layout.topMargin: Theme.smallPadding
            Layout.maximumWidth: parent.width

            count: root.newsModel.count
        }
    }
}
