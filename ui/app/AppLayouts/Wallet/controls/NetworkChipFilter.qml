import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import utils

Flow {
    id: root

    /** networks catalog; roles: chainId, chainName, iconUrl **/
    property var flatNetworksModel

    /** currently selected chain; -1 means "All". Input only - the host owns the
        selection and is free to reject one (e.g. single-chain hosts ignore "All") **/
    property int selectedChainId: -1

    signal chainSelected(int chainId)

    spacing: Theme.halfPadding

    component Chip: AbstractButton {
        id: chip

        implicitHeight: 36
        implicitWidth: Math.max(36, implicitContentWidth + leftPadding + rightPadding)
        horizontalPadding: 6
        verticalPadding: 6

        background: Rectangle {
            radius: Theme.radius
            color: chip.checked ? Theme.palette.primaryColor3
                 : chip.hovered ? Theme.palette.baseColor2
                 : Theme.palette.baseColor4
            border.width: chip.checked ? 1 : 0
            border.color: Theme.palette.primaryColor1

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    Chip {
        objectName: "chainChip_all"
        checked: root.selectedChainId === -1
        horizontalPadding: 12
        contentItem: StatusBaseText {
            text: qsTr("All")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: parent.checked ? Theme.palette.primaryColor1 : Theme.palette.directColor1
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
        }
        onClicked: root.chainSelected(-1)
    }

    Repeater {
        model: root.flatNetworksModel

        delegate: Chip {
            required property var model

            objectName: "chainChip_" + model.chainId
            checked: root.selectedChainId === model.chainId
            contentItem: StatusRoundedImage {
                implicitWidth: 24
                implicitHeight: 24
                image.source: model.iconUrl ? Assets.svg(model.iconUrl) : ""
            }
            onClicked: root.chainSelected(model.chainId)
        }
    }
}
