import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Popups

import shared.controls.delegates
import utils

Item {
    id: root

    required property string mainDisplayName
    required property var socialLinksModel

    property alias cellWidth: webView.cellWidth
    property alias cellHeight: webView.cellHeight

    signal copyToClipboard(string text)


    StatusBaseText {
        anchors.centerIn: parent
        visible: (webView.count === 0)
        width: parent.width - (2 * Theme.bigPadding * 2)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: Theme.palette.directColor1
        text: qsTr("%1 has not shared any links").arg(root.mainDisplayName)
    }

    StatusGridView {
        id: webView

        anchors.fill: parent
        topMargin: Theme.bigPadding
        bottomMargin: Theme.bigPadding
        leftMargin: Theme.bigPadding

        visible: count

        model: root.socialLinksModel
        ScrollBar.vertical: StatusScrollBar { anchors.right: parent.right; anchors.rightMargin: width / 2 }
        delegate: InfoCard {
            id: socialLinksInfoDelegate
            readonly property int linkType: ProfileUtils.linkTextToType(model.text)
            width: GridView.view.cellWidth - Theme.padding
            height: GridView.view.cellHeight - Theme.padding
            title: !!ProfileUtils.linkTypeToText(linkType) ? ProfileUtils.linkTypeToText(linkType) : model.text
            asset.bgColor: ProfileUtils.linkTypeBgColor(linkType, root.Theme.palette)
            asset.name: ProfileUtils.linkTypeToIcon(linkType)
            asset.color: ProfileUtils.linkTypeColor(linkType, root.Theme.palette)
            asset.width: 20
            asset.height: 20
            asset.bgWidth: 32
            asset.bgHeight: 32
            asset.isImage: false
            subTitle: model.url
            onContextMenuRequested: (x, y) => delegatesActionsMenu.createObject(socialLinksInfoDelegate, { url: model.url }).popup(x,y)
            rightSideButtons: RowLayout {
                StatusFlatRoundButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    type: StatusFlatRoundButton.Type.Secondary
                    icon.name: "external"
                    icon.width: 16
                    icon.height: 16
                    radius: width/2
                    highlighted: true
                    visible: socialLinksInfoDelegate.hovered
                    icon.color: socialLinksInfoDelegate.hovered && !hovered ? Theme.palette.baseColor1 : Theme.palette.directColor1

                    onClicked: {
                        Global.requestOpenLink(model.url)
                    }
                }
            }
        }
    }

    Item {
        width: 279
        height: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        visible: (webView.count > 0)
        Rectangle {
            anchors.fill: parent
            color: Theme.palette.background
            radius: 30
            border.color: Theme.palette.baseColor2
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.halfPadding
            spacing: 4

            StatusIcon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                icon: "info"
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                font.pixelSize: Theme.additionalTextSize
                text: qsTr("Social handles and links are unverified")
                elide: Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Component {
        id: delegatesActionsMenu
        StatusMenu {
            id: contextMenu

            property string url

            onClosed: destroy()

            StatusSuccessAction {
                successText: qsTr("Copied")
                text: qsTr("Copy link")
                icon.name: "copy"
                onTriggered: {
                    root.copyToClipboard(contextMenu.url);
                }
            }
        }
    }
}
