import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Components

import AppLayouts.Wallet.controls

import utils

AbstractButton {
    id: root

    padding: 12

    property bool highlight: false
    property string title: ""
    property string subTitle: ""
    property string tagIcon: ""
    property bool loading: false
    property alias rightSideButtons: rightSideButtonsLoader.sourceComponent

    signal contextMenuRequested(real x, real y)
    signal communityTagClicked(var mouse)

    property StatusAssetSettings asset: StatusAssetSettings {
        height: 32
        width: 32
        bgRadius: bgWidth / 2
    }

    ContextMenu.onRequested: pos => root.contextMenuRequested(pos.x, pos.y)
    onPressAndHold: root.contextMenuRequested(pressX, pressY)

    background: StatusBackgroundPanel {
        shadowColor: Theme.palette.backdropColor
        shadowVisible: root.hovered || root.highlight
    }

    contentItem: Item {
        ColumnLayout {
            id: titleColumn
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.asset.height
                StatusSmartIdenticon {
                    asset: root.asset
                    active: ((root.asset.isLetterIdenticon ||
                              !!root.asset.name ||
                              !!root.asset.emoji) && !root.showLoadingIndicator)
                    loading: root.loading
                }
                Item { Layout.fillWidth: true }
                Loader {
                    id: rightSideButtonsLoader
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                }
            }

            StatusTextWithLoadingState {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                Layout.topMargin: Theme.halfPadding
                text: root.title
                elide: Text.ElideRight
                font.weight: Font.Medium
                loading: root.loading
            }

            StatusTextWithLoadingState {
                id: statusListItemSubTitle
                objectName: "statusListItemSubTitle"
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                text: root.subTitle
                font.pixelSize: Theme.tertiaryTextFontSize
                lineHeight: 16
                customColor: !root.enabled || !root.tertiaryTitle ?
                                 Theme.palette.baseColor1 : Theme.palette.directColor1
                visible: !!root.subTitle
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                loading: root.loading
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }

            ManageTokensCommunityTag {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                horizontalPadding: 2
                verticalPadding: 0
                spacing: 0
                visible: !!root.tagIcon
                communityImage: root.tagIcon
                asset.width: 20
                asset.height: 20
                StatusMouseArea {
                    anchors.fill: parent
                    onClicked: mouse => root.communityTagClicked(mouse)
                }
            }
        }
    }
}
