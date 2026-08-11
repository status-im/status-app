import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import utils
import shared.panels

Control {
    id: root

    property alias model: listView.model

    readonly property alias listView: listView
    property var inputField

    // While true the panel renders skeleton rows instead of relying on the
    // (still empty) model — shown until the members model is wired in.
    property bool loading: false

    signal clicked(int index)

    padding: Theme.halfPadding
    opacity: visible ? 1.0 : 0

    Behavior on opacity {
        NumberAnimation {}
    }

    background: Rectangle {
        color: Theme.palette.background
        radius: Theme.radius
    }

    layer.enabled: true
    layer.effect: DropShadow {
        width: root.width
        height: root.height
        x: root.x
        y: root.y + 10
        visible: root.visible
        source: root
        horizontalOffset: 0
        verticalOffset: 2
        radius: 10
        samples: 15
        color: "#22000000"
    }

    contentItem: StatusListView {
        id: listView
        objectName: "suggestionBoxList"

        implicitHeight: root.loading ? loadingSkeleton.implicitHeight
                                     : contentHeight

        LoadingSkeletonGroup {
            id: loadingSkeleton
            objectName: "suggestionsLoadingSkeleton"

            visible: root.loading
            width: listView.width
            implicitHeight: skeletonRows.implicitHeight

            Column {
                id: skeletonRows
                width: parent.width

                Repeater {
                    model: 3

                    Item {
                        width: skeletonRows.width
                        height: 42

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.smallPadding
                            spacing: Theme.smallPadding

                            LoadingSkeletonTile {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 32
                                radius: 16
                            }

                            LoadingSkeletonTile {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 96
                                height: 12
                                radius: 6
                            }
                        }
                    }
                }
            }
        }

        keyNavigationEnabled: true
        Keys.priority: Keys.AfterItem
        Keys.forwardTo: root.inputField
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.hide()
            } else if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) {
                event.accepted = false
            }
        }

        delegate: Rectangle {
            id: itemDelegate
            objectName: model.preferredDisplayName

            color: ListView.isCurrentItem ? Theme.palette.backgroundHover
                                          : StatusColors.transparent
            width: ListView.view.width
            height: 42
            radius: Theme.radius

            StatusUserImage {
                id: accountImage

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.smallPadding
                imageWidth: 32
                imageHeight: 32

                name: model.preferredDisplayName
                usesDefaultName: model.usesDefaultName
                userColor: Utils.colorForColorId(root.Theme.palette, model.colorId)
                image: model.icon
                interactive: false
            }

            StyledText {
                text: model.preferredDisplayName
                color: Theme.palette.textColor

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: accountImage.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.smallPadding

                elide: Text.ElideRight
            }

            StatusMouseArea {
                id: mouseArea

                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true

                onEntered: listView.currentIndex = model.index
                onClicked: root.clicked(model.index)
            }
        }
    }
}
