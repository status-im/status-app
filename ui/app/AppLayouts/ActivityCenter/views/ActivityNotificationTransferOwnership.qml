import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import  AppLayouts.ActivityCenter.controls

import shared
import shared.panels
import utils

import "../panels"
import "../popups"

import AppLayouts.ActivityCenter.helpers

ActivityNotificationBase {
    id: root

    required property string communityName
    required property string communityColor
    required property int type // Possible values [OwnershipState]

    signal finaliseOwnershipClicked
    signal navigateToCommunityClicked

    function setType(notification) {
        if(notification)
            switch(notification.notificationType){

            case ActivityCenterTypes.NotificationType.OwnerTokenReceived:
                return ActivityNotificationTransferOwnership.OwnershipState.Pending

            case ActivityCenterTypes.NotificationType.OwnershipDeclined:
                return ActivityNotificationTransferOwnership.OwnershipState.Declined

            case ActivityCenterTypes.NotificationType.OwnershipReceived:
                return ActivityNotificationTransferOwnership.OwnershipState.Succeeded

            case ActivityCenterTypes.NotificationType.OwnershipFailed:
                return ActivityNotificationTransferOwnership.OwnershipState.Failed

            case ActivityCenterTypes.NotificationType.OwnershipLost:
                return ActivityNotificationTransferOwnership.OwnershipState.NoLongerControlNode

            }
        return ActivityNotificationTransferOwnership.OwnershipState.Failed
    }

    enum OwnershipState {
        Pending,
        Declined,
        Succeeded,
        Failed,
        NoLongerControlNode
    }

    QtObject {
        id: d

        property string title: ""
        property string info: ""
        property string assetColor: ""
        property string assetName: ""
        property string assetBgColor: ""
        property string ctaText: ""
        property var actionSourceComponent: undefined

        readonly property string crownAssetName: "crown"
    }

    avatarComponent: StatusSmartIdenticon {
        asset {
            width: 24
            height: width
            name: d.assetName
            color: d.assetColor
            bgWidth: 40
            bgHeight: 40
            bgColor: d.assetBgColor
        }
    }

    bodyComponent: ColumnLayout {
        spacing: 2
        width: parent.width

        NotificationBaseHeaderRow {
            Layout.fillWidth: true
            primaryText: d.title
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: d.info
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            color: Theme.palette.directColor1
        }
    }

    ctaComponent: Loader { sourceComponent: d.actionSourceComponent }

    states: [
        State {
            when: root.type === ActivityNotificationTransferOwnership.OwnershipState.Pending
            PropertyChanges {
                target: d
                title: qsTr("You received the owner token from %1").arg(root.communityName)
                info: qsTr("To finalise your ownership of the %1 Community, make your device the control node").arg(root.communityName)
                ctaText: qsTr("Finalise ownership")
                assetColor: root.communityColor
                assetBgColor: StatusColors.getColor(d.assetColor, 0.1)
                assetName: d.crownAssetName
                actionSourceComponent: ctaLinkBtnComponent
            }
        },
        State {
            when: root.type === ActivityNotificationTransferOwnership.OwnershipState.Declined
            PropertyChanges {
                target: d
                title: qsTr("You received the owner token from %1").arg(root.communityName)
                info: qsTr("To finalise your ownership of the %1 Community, make your device the control node").arg(root.communityName)
                ctaText: qsTr("Ownership Declined")
                assetColor: root.communityColor
                assetBgColor: StatusColors.getColor(d.assetColor, 0.1)
                assetName: d.crownAssetName
                actionSourceComponent: ctaTextComponent
            }
        },
        State {
            when: root.type === ActivityNotificationTransferOwnership.OwnershipState.Succeeded
            PropertyChanges {
                target: d
                title: qsTr("Your device is now the control node for %1").arg(root.communityName)
                info: qsTr("Congratulations, you are now the official owner of the %1 Community with full admin rights").arg(root.communityName)
                ctaText: qsTr("Community admin")
                assetColor: root.communityColor
                assetBgColor: StatusColors.getColor(d.assetColor, 0.1)
                assetName: d.crownAssetName
                actionSourceComponent: ctaLinkBtnComponent
            }
        },
        State {
            when: root.type === ActivityNotificationTransferOwnership.OwnershipState.Failed
            PropertyChanges {
                target: d
                title: qsTr("%1 smart contract update failed").arg(root.communityName)
                info: qsTr("You will need to retry the transaction in order to finalise your ownership of the %1 community").arg(root.communityName)
                ctaText: qsTr("Finalise ownership")
                assetColor: Theme.palette.dangerColor1
                assetBgColor: Theme.palette.dangerColor3
                assetName: "warning"
                actionSourceComponent: ctaLinkBtnComponent
            }
        },
        State {
            when: root.type === ActivityNotificationTransferOwnership.OwnershipState.NoLongerControlNode
            PropertyChanges {
                target: d
                title: qsTr("Your device is no longer the control node for %1").arg(root.communityName)
                info: qsTr("Your ownership and admin rights for %1 have been removed and transferred to the new owner").arg(root.communityName)
                ctaText: ""
                assetColor: Theme.palette.dangerColor1
                assetBgColor: Theme.palette.dangerColor3
                assetName: "crown-off"
                actionSourceComponent: undefined
            }
        }
    ]

    Component {
        id: ctaLinkBtnComponent

        StatusLinkText {
            text: d.ctaText
            color: Theme.palette.primaryColor1
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Normal
            onClicked: {
                if((root.type === ActivityNotificationTransferOwnership.OwnershipState.Pending) ||
                        (root.type === ActivityNotificationTransferOwnership.OwnershipState.Failed))
                    root.finaliseOwnershipClicked()
                else if(root.type === ActivityNotificationTransferOwnership.OwnershipState.Succeeded)
                    root.navigateToCommunityClicked()
            }
        }
    }

    Component {
        id: ctaTextComponent

        StatusBaseText {
            text: d.ctaText
            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.dangerColor1
        }
    }
}
