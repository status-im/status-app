import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import shared.controls

import utils

import AppLayouts.Profile.popups

Control {
    id: root
    
    property var socialLinksModel
    property int showcaseLimit: 20

    background: null

    signal addSocialLink(string url, string text)
    signal updateSocialLink(int index, string url, string text)
    signal removeSocialLink(int index)
    signal changePosition(int from, int to)

    QtObject {
        id: d

        function containsSocialLink(text, url) {
            return ModelUtils.contains(socialLinksModel, "text", text, Qt.CaseInsensitive) &&
                     ModelUtils.contains(socialLinksModel, "url", url, Qt.CaseInsensitive) 
        }
    }

    Component {
        id: addSocialLinkModalComponent
        AddSocialLinkModal {
            containsSocialLink: d.containsSocialLink
            onAddLinkRequested: (linkText, linkUrl, linkType, linkIcon) => root.addSocialLink(linkUrl, linkText)
        }
    }

    Component {
        id: modifySocialLinkModal
        ModifySocialLinkModal {
            containsSocialLink: d.containsSocialLink
            onUpdateLinkRequested: (index, linkText, linkUrl) => root.updateSocialLink(index, linkUrl, linkText)
            onRemoveLinkRequested: index => root.removeSocialLink(index)
        }
    }

    contentItem: ColumnLayout {
        id: layout
        spacing: Theme.halfPadding

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.padding
            StatusBaseText {
                text: qsTr("In showcase")
                color: Theme.palette.directColor1
            }
            Item { Layout.fillWidth: true }
            StatusBaseText {
                text: qsTr("%1 / %2").arg(linksView.count).arg(root.showcaseLimit)
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.tertiaryTextFontSize
            }
        }

        // empty placeholder when no links; dashed rounded rectangle
        ShapeRectangle {
            readonly property bool maxReached: linksView.count === root.showcaseLimit

            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width - 4 // the rectangular path is rendered outside
            Layout.preferredHeight: 48

            text: maxReached ? qsTr("Link limit of %1 reached").arg(root.showcaseLimit) : ""
            path.strokeColor: maxReached ? "transparent" : Theme.palette.baseColor2
            path.fillColor: maxReached ? Theme.palette.baseColor4 : "transparent"
            font.pixelSize: Theme.tertiaryTextFontSize

            StatusLinkText {
                objectName: "addMoreSocialLinks"
                anchors.centerIn: parent
                visible: !parent.maxReached
                text: qsTr("＋ Add a link")
                color: Theme.palette.primaryColor1
                font.weight: Font.Normal
                onClicked: Global.openPopup(addSocialLinkModalComponent)
            }
        }

        StatusListView {
            id: linksView

            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            Layout.bottomMargin: ProfileUtils.defaultDelegateHeight / 2

            model: root.socialLinksModel
            interactive: false
            spacing: Theme.halfPadding

            displaced: Transition {
                NumberAnimation { properties: "x,y"; easing.type: Easing.OutQuad }
            }

            delegate: DropArea {
                id: delegateRoot

                property int visualIndex: index

                width: ListView.view.width
                height: draggableDelegate.height

                keys: ["x-status-draggable-list-item-internal"]

                onEntered: function(drag) {
                    const from = drag.source.visualIndex
                    const to = draggableDelegate.visualIndex
                    if (to === from)
                        return
                    root.changePosition(from, to)
                    drag.accept()
                }

                StatusDraggableListItem {
                    id: draggableDelegate

                    readonly property string asideText: ProfileUtils.stripSocialLinkPrefix(model.url, draggableDelegate.linkType)
                    readonly property int linkType: ProfileUtils.linkTextToType(model.text)
                    readonly property string iconName: ProfileUtils.linkTypeToIcon(draggableDelegate.linkType)

                    visible: !!asideText
                    width: parent.width
                    height: visible ? ProfileUtils.defaultDelegateHeight : 0
                    topInset: 0
                    bottomInset: 0

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }

                    dragParent: linksView
                    visualIndex: delegateRoot.visualIndex
                    draggable: linksView.count > 1
                    title: ProfileUtils.linkTypeToShortText(draggableDelegate.linkType) || model.text
                    hasIcon: true
                    icon.name: draggableDelegate.iconName
                    icon.color: ProfileUtils.linkTypeColor(draggableDelegate.linkType, root.Theme.palette)
                    assetBgColor: ProfileUtils.linkTypeBgColor(draggableDelegate.linkType, root.Theme.palette)
                    actions: [
                        StatusLinkText {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Math.ceil(implicitWidth)
                            Layout.alignment: Qt.AlignRight
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.primaryTextFontSize
                            font.weight: Font.Normal
                            text: draggableDelegate.asideText
                            onClicked: Global.requestOpenLink(model.url)
                        },
                        StatusFlatRoundButton {
                            icon.name: "edit_pencil"
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            icon.width: 16
                            icon.height: 16
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: qsTr("Edit link")
                            onClicked: Global.openPopup(modifySocialLinkModal,
                                                        {linkType: draggableDelegate.linkType, icon: draggableDelegate.iconName, index: delegateRoot.visualIndex,
                                                            linkText: model.text, linkUrl: draggableDelegate.asideText})
                        }
                    ]
                }
            }
        }
    }
}
