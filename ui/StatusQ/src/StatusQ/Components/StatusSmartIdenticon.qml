import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

Loader {
    id: root

    property string name: ""
    property int dZ: 100

    // Badge color properties must be set if badge.visible = true
    property alias badge: statusBadge

    property alias bridgeBadge: bridgeBadge

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 40
        height: 40
        bgWidth: root.width
        bgHeight: root.height
        bgRadius: bgWidth / 2
    }

    sourceComponent: {
        if (root.loading) return loadingComp
        if (root.asset.isLetterIdenticon || root.asset.name === "") return letterIdenticon
        if (root.asset.isImage) return roundedImage
        return roundedIcon
    }

    property bool loading: false
    property bool hoverEnabled: false
    readonly property bool hovered: (sourceComponent === roundedIcon && item) ?
                     item.hovered : false

    signal clicked(var mouse)

    Component {
        id: roundedImage

        Item {
            width: root.asset.width
            height: root.asset.height

            StatusRoundedImage {
                id: statusRoundImage
                objectName: "statusRoundImage"
                width: parent.width
                height: parent.height
                image.source: root.asset.isImage ? root.asset.name : ""
                showLoadingIndicator: true
                border.width: root.asset.imgIsIdenticon ? 1 : 0
                border.color: Theme.palette.directColor7
                color: root.asset.imgIsIdenticon ?
                           Theme.palette.statusRoundedImage.backgroundColor :
                           root.asset.bgColor
                image.fillMode: Image.PreserveAspectCrop
            }

            Loader {
                anchors.centerIn: parent
                active: root.asset.imgStatus === Image.Error ||
                        statusRoundImage.image.status === Image.Error
                sourceComponent: letterIdenticon
                onLoaded: {
                    item.color = Theme.palette.miscColor5
                    item.width = root.asset.width
                    item.height = root.asset.height
                }
            }
        }
    }

    Component {
        id: roundedIcon

        StatusRoundIcon {
            objectName: "statusRoundIcon"
            asset.bgRadius: root.asset.bgRadius
            asset.bgWidth: root.asset.bgWidth
            asset.bgHeight: root.asset.bgHeight
            asset.bgColor: root.asset.bgColor
            asset.width: root.asset.width
            asset.height: root.asset.height
            asset.name: root.asset.name
            asset.rotation: root.asset.rotation
            asset.color: root.asset.color
            asset.bgBorderWidth: root.asset.bgBorderWidth
            asset.bgBorderColor: root.asset.bgBorderColor

            readonly property alias hovered: mouseArea.containsMouse

            StatusMouseArea {
                id: mouseArea

                anchors.fill: parent
                enabled: hoverEnabled
                hoverEnabled: root.hoverEnabled
                cursorShape: !loading && root.hoverEnabled ? Qt.PointingHandCursor : undefined
                onClicked: root.clicked(mouse)
            }
        }
    }

    Component {
        id: letterIdenticon
        StatusLetterIdenticon {
            objectName: "statusSmartIdenticonLetter"
            width: root.asset.width
            height: root.asset.height
            radius: asset.bgRadius || width/2
            letterIdenticonColor: root.asset.color
            name: root.name
            emoji: root.asset.emoji
            emojiSize: root.asset.emojiSize
            letterSize: root.asset.letterSize
            charactersLen: root.asset.charactersLen
            useAcronymForLetterIdenticon: root.asset.useAcronymForLetterIdenticon
            backgroundWithAlpha: root.asset.letterIdenticonBgWithAlpha
            border.width: root.asset.bgBorderWidth
            border.color: root.asset.bgBorderColor
        }
    }

    // State component
    StatusBadge {
        id: statusBadge
        visible: false
        anchors.bottom: root.bottom
        anchors.right: root.right
        anchors.rightMargin: -border.width
        anchors.bottomMargin: -border.width
        border.width: 3
        height: 15
        width: 15
        z: root.dZ
    }

    StatusRoundedImage {
        id: bridgeBadge
        visible: false
        anchors.bottom: root.bottom
        anchors.right: root.right
        anchors.rightMargin: -border.width
        anchors.bottomMargin: -border.width
        implicitHeight: 20
        implicitWidth: 20
        border.width: 3
        border.color: Theme.palette.statusBadge.foregroundColor
        z: root.dZ
    }

    Component {
        id: loadingComp
        LoadingComponent {
            anchors.centerIn: parent
            radius: width/2
            height: root.asset.isImage ? root.asset.height : root.asset.bgHeight
            width: root.asset.isImage ? root.asset.width : root.asset.bgWidth
        }
    }
}
