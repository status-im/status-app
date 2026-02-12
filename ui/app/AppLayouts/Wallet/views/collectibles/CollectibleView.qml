import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import AppLayouts.Communities.panels
import AppLayouts.Wallet.controls

import utils

AbstractButton {
    id: root

    objectName: "collectibleViewControl"

    enabled: !isLoading

    property string title: ""
    property string unknownTitle: "..."
    property string subTitle: ""
    property alias subTitleColor: subTitleItem.customColor
    property color backgroundColor: "transparent"
    property url mediaUrl : ""
    property string mediaType: ""
    property url fallbackImageUrl : ""
    property bool isLoading: false
    property bool navigationIconVisible: false
    property string communityId: ""
    property string communityName
    property string communityImage
    property int balance: 1

    // Special Owner and TMaster token properties
    readonly property bool isCommunityCollectible: communityId !== ""
    property bool showCommunityBadge: isCommunityCollectible
    property int privilegesLevel: Constants.TokenPrivilegesLevel.Community
    readonly property bool isPrivilegedToken: (privilegesLevel === Constants.TokenPrivilegesLevel.Owner) ||
                                              (privilegesLevel === Constants.TokenPrivilegesLevel.TMaster)
    property color ornamentColor // Relevant color for these special tokens (community color)

    QtObject {
        id: d

        readonly property bool unknownCommunityName: root.communityName.startsWith("0x") && root.communityId === root.communityName
    }

    signal contextMenuRequested(real x, real y)
    signal switchToCommunityRequested(string communityId)

    background: Rectangle {
        radius: Theme.radius
        color: Theme.palette.baseColor2
        visible: !root.isLoading && root.hovered
    }

    ContextMenu.onRequested: function(pos) {
        if (root.isLoading)
            return
        root.contextMenuRequested(pos.x, pos.y)
    }
    onPressAndHold: {
        if (root.isLoading)
            return
        root.contextMenuRequested(pressX, pressY)
    }

    HoverHandler {
        cursorShape: !root.isLoading ? Qt.PointingHandCursor : undefined
    }

    property Component balanceTag: Component {
        CollectibleBalanceTag {
            visible: !root.isLoading && (root.balance > 1)
            balance: root.balance
        }
    }   

    contentItem: ColumnLayout {
        spacing: 0

        CollectibleMedia {
            id: image

            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Theme.halfPadding
            Layout.fillWidth: true
            Layout.preferredHeight: width

            backgroundColor: root.isLoading ? "transparent" : root.backgroundColor
            visible: !specialCollectible.visible
            mediaUrl: root.mediaUrl
            mediaType: root.mediaType
            fallbackImageUrl: root.fallbackImageUrl
            showLoadingIndicator: true
            isCollectibleLoading: root.isLoading
            fillMode: Image.PreserveAspectCrop

            Loader {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.halfPadding
                sourceComponent: root.balanceTag
            }
        }

        PrivilegedTokenArtworkPanel {
            id: specialCollectible

            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Theme.halfPadding
            Layout.fillWidth: true
            Layout.preferredHeight: width

            visible: root.isCommunityCollectible && root.isPrivilegedToken
            size: PrivilegedTokenArtworkPanel.Size.Medium
            artwork: visible ? root.fallbackImageUrl : ""
            color: root.ornamentColor
            fillMode: Image.PreserveAspectCrop
            isOwner: root.privilegesLevel === Constants.TokenPrivilegesLevel.Owner

            Loader {
                anchors.fill: parent
                active: root.isLoading
                sourceComponent: LoadingComponent {radius: image.radius}
            }

            Loader {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.halfPadding
                sourceComponent: root.balanceTag
            }
        }

        RowLayout {
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: Layout.leftMargin
            Layout.fillWidth: !root.isLoading
            Layout.preferredWidth: root.isLoading ? 134 : width

            StatusTextWithLoadingState {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                customColor: Theme.palette.directColor1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                text: root.isLoading ? Constants.dummyText : root.title || root.unknownTitle
                loading: root.isLoading
            }

            StatusIcon {
                visible: root.navigationIconVisible
                icon: "next"
                color: Theme.palette.baseColor1
            }
        }

        StatusTextWithLoadingState {
            id: subTitleItem

            Layout.topMargin: 4
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: Layout.leftMargin
            Layout.fillWidth: !root.isLoading
            Layout.preferredWidth: root.isLoading ? 88 : width
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Theme.additionalTextSize
            customColor: Theme.palette.baseColor1
            elide: Text.ElideRight
            text: root.isLoading ? Constants.dummyText : root.subTitle
            loading: root.isLoading
            visible: text && !root.communityName
        }

        ManageTokensCommunityTag {
            Layout.topMargin: Theme.halfPadding
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: Theme.halfPadding
            Layout.maximumWidth: parent.width - Layout.leftMargin - Layout.rightMargin
            communityName: root.communityName
            communityId: root.communityId
            communityImage: root.communityImage
            visible: root.showCommunityBadge
            enabled: !root.isLoading
            
            TapHandler {
                enabled: !d.unknownCommunityName
                acceptedButtons: Qt.LeftButton
                onSingleTapped: root.switchToCommunityRequested(root.communityId)
            }
        }

        // Filler
        Item {
            Layout.fillHeight: true
        }
    }
}
