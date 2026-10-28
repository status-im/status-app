import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import utils

Item {
    id: root

    property url imageUrl: ""
    property url badgeIcon: ""
    property real badgeSize: 0
    property real badgeMargin: 0

    readonly property bool iconLoaded: !mainImage.isError && !mainImage.isLoading && mainImage.image.source !== ""

    implicitWidth: mainImage.implicitWidth
    implicitHeight: mainImage.implicitHeight

    Item {
        id: imageContainer

        width: parent.width
        height: width

        StatusRoundedImage {
            id: mainImage

            width: parent.width
            height: width
            visible: !isError && !isLoading && root.imageUrl != ""
            image.source: root.imageUrl
        }

        Loader {
            anchors.fill: mainImage
            active: !mainImage.visible
            sourceComponent: StatusRoundedComponent {
                id: imageWrapper
                color: Theme.palette.primaryColor3
                StatusIcon {
                    anchors.fill: imageWrapper
                    anchors.margins: imageWrapper.width / 4.5
                    color: Theme.palette.primaryColor1
                    icon: "dapp"
                }
            }
        }

        // Cut around the badge, badgeMargin wide: computed by the shader on
        // this item's layer, with no second layer for a mask
        layer.enabled: badge.visible
        layer.effect: StatusRoundedCornersEffect {
            cutoutCenter: Qt.point(badge.x + badge.width / 2, badge.y + badge.height / 2)
            cutoutRadius: badge.width / 2 + root.badgeMargin
        }
    }

    StatusRoundedImage {
        id: badge
        width: root.badgeSize
        height: width
        visible: image.source != "" && !isLoading && !isError
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        image.source: root.badgeIcon
    }
}
