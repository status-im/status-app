import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

import utils

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers

Item {
    id: root

    required property string mainDisplayName
    required property bool readOnly
    required property var communitiesProxyModel
    required property var globalAssetsModel
    required property var globalCollectiblesModel

    property alias cellWidth: communitiesView.cellWidth
    property alias cellHeight: communitiesView.cellHeight

    signal copyToClipboard(string text)
    signal closeRequested()

    StatusBaseText {
        anchors.centerIn: parent
        visible: (communitiesView.count === 0)
        width: parent.width - (2 * Theme.bigPadding * 2)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: Theme.palette.directColor1
        text: qsTr("%1 has not shared any communities").arg(root.mainDisplayName)
    }

    StatusGridView {
        id: communitiesView

        anchors.fill: parent
        topMargin: Theme.bigPadding
        bottomMargin: Theme.bigPadding
        leftMargin: Theme.bigPadding

        visible: count
        model: root.communitiesProxyModel
        ScrollBar.vertical: StatusScrollBar { anchors.right: parent.right; anchors.rightMargin: width / 2 }
        delegate: StatusCommunityCard {
            id: profileDialogCommunityCard
            readonly property var permissionsList: model.permissionsModel
            readonly property bool isTokenGatedCommunity: PermissionsHelpers.isTokenGatedCommunity(permissionsList)

            cardSize: StatusCommunityCard.Size.Small
            implicitWidth: GridView.view.cellWidth - Theme.padding
            implicitHeight: GridView.view.cellHeight - Theme.padding
            titleFontSize: Theme.primaryTextFontSize
            communityId: model.id ?? ""
            loaded: !!model.id && !model.isShowcaseLoading
            asset.source: model.image ?? ""
            asset.isImage: !!model.image
            asset.width: 32
            asset.height: 32
            name: model.name ?? ""
            memberCountVisible: model.joined || !model.encrypted
            members: model.joinedMembersCount
            activeUsers: model.activeMembersCount
            banner: model.bannerImageData ?? ""
            descriptionFontSize: Theme.tertiaryTextFontSize
            descriptionFontColor: Theme.palette.baseColor1
            description: {
                switch (model.memberRole)  {
                case (Constants.memberRole.owner):
                    return qsTr("Owner");
                case (Constants.memberRole.admin):
                    return qsTr("Admin");
                case (Constants.memberRole.tokenMaster):
                    return qsTr("Token Master");
                default:
                    return qsTr("Member");
                }
            }
            communityColor: model.color ?? ""
            // Community restrictions
            bottomRowComponent: (model.joined && !root.readOnly) ?
                                    communityMembershipComponent :
                                    isTokenGatedCommunity ? permissionsRowComponent : null

            Component {
                id: communityMembershipComponent
                Item {
                    width: 125
                    height: 24
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: Theme.palette.successColor1
                        opacity: .1
                        border.color: Theme.palette.successColor1
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        StatusIcon {
                            width: 16
                            height: 16
                            color: Theme.palette.successColor1
                            icon: "tiny/checkmark"
                        }
                        StatusBaseText {
                            font.pixelSize: Theme.tertiaryTextFontSize
                            color: Theme.palette.successColor1
                            text: qsTr("You're there too")
                        }
                    }
                }
            }

            Component {
                id: permissionsRowComponent
                PermissionsRow {
                    readonly property int eligibleToJoinAs: PermissionsHelpers.isEligibleToJoinAs(profileDialogCommunityCard.permissionsList)

                    assetsModel: root.globalAssetsModel
                    collectiblesModel: root.globalCollectiblesModel
                    model: profileDialogCommunityCard.permissionsList
                    requirementsMet: eligibleToJoinAs === PermissionTypes.Type.Member
                                     || eligibleToJoinAs === PermissionTypes.Type.Admin
                                     || eligibleToJoinAs === PermissionTypes.Type.Owner
                    backgroundBorderColor: Theme.palette.baseColor2
                    backgroundRadius: 20
                    fontPixelSize: 10
                }
            }

            onClicked: {
                if (root.readOnly)
                    return
                Global.switchToCommunity(model.id)
                root.closeRequested()
            }
            onRightClicked: function (communityId, x, y) {
                if (root.readOnly)
                    return
                delegatesActionsMenu.createObject(profileDialogCommunityCard, { communityId: model.id, url: Utils.getCommunityShareLink(model.id) }).popup(x, y)
            }
        }
    }

    Component {
        id: delegatesActionsMenu
        StatusMenu {
            id: contextMenu

            property string url
            property string communityId

            StatusAction {
                text: qsTr("Visit community")
                icon.name: "arrow-right"
                onTriggered: {
                    Global.switchToCommunity(contextMenu.communityId);
                    root.closeRequested();
                }
            }

            StatusAction {
                text: qsTr("Invite People")
                icon.name: "share-ios"
                onTriggered: {
                    Global.openInviteFriendsToCommunityByIdPopup(contextMenu.communityId, null);
                }
            }

            StatusSuccessAction {
                id: copyAddressAction
                successText: qsTr("Copied")
                text: qsTr("Copy link to community")
                icon.name: "copy"
                onTriggered: {
                    root.copyToClipboard(contextMenu.url)
                }
            }

            onClosed: destroy()
        }
    }
}
