import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import utils
import shared.panels

Rectangle {
    property url collectibleIconSource: "CryptoKitties"
    property string collectibleName: "CryptoKitties"
    property bool isLoading: true
    property bool hovered: false
    property var toggleCollectible: function () {}
    property int collectiblesQty: 6

    id: collectibleHeader
    height: 64
    width: parent.width
    color: hovered ? Theme.palette.backgroundHover : StatusColors.transparent
    border.width: 0
    radius: Theme.radius

    Image {
        id: collectibleIconImage
        source: collectibleHeader.collectibleIconSource
        width: 40
        height: 40
        anchors.left: parent.left
        anchors.leftMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter
        cache: false
    }

    StyledText {
        id: collectibleName
        text: collectibleHeader.collectibleName
        anchors.left: collectibleIconImage.right
        anchors.leftMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Theme.secondaryAdditionalTextSize
    }

    StyledText {
        visible: collectiblesQty >= Constants.maxTokens
        text: qsTr("Maximum number of collectibles to display reached")
        font.pixelSize: Theme.secondaryAdditionalTextSize
        color: Theme.palette.secondaryText
        anchors.left: collectibleName.right
        anchors.leftMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter

    }

    Loader {
        active: true
        sourceComponent: collectibleHeader.isLoading ? loadingComponent : handleComponent
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        anchors.verticalCenter: parent.verticalCenter
    }

    Component {
        id: loadingComponent

        StatusLoadingIndicator {}
    }

    Component {
        id: handleComponent

        Item {
            id: element1
            width: childrenRect.width
            height: numberCollectibleText.height

            StyledText {
                id: numberCollectibleText
                color: Theme.palette.secondaryText
                text: !!error ? "-" : collectibleHeader.collectiblesQty
                font.pixelSize: Theme.primaryTextFontSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusIcon {
                id: caretImg
                anchors.verticalCenter: parent.verticalCenter
                source: Assets.svg("caret")
                width: 11
                anchors.left: numberCollectibleText.right
                anchors.leftMargin: Theme.padding
                fillMode: Image.PreserveAspectFit
                color: StatusColors.black
            }
        }
    }

    StatusMouseArea {
        enabled: !collectibleHeader.isLoading
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: {
            collectibleHeader.hovered = true
        }
        onExited: {
            collectibleHeader.hovered = false
        }
        onClicked: {
            collectibleHeader.toggleCollectible()
        }
    }
}
