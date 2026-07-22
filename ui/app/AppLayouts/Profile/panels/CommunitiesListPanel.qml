import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

import utils
import shared.controls.chat.menuItems

import QtModelsToolkit

StatusListView {
    id: root

    property var fnIsMyCommunityRequestPending: function(communityId) {}
    property bool compactMode

    signal inviteFriends(var communityData)
    signal closeCommunityClicked(string communityId)
    signal leaveCommunityClicked(string community, string communityId, string outroMessage)
    signal setCommunityMutedClicked(string communityId, int mutedType)
    signal setActiveCommunityClicked(string communityId)
    signal showCommunityMembershipSetupDialog(string communityId, string name,
                                              string introMessage, string imageSrc, int accessType)
    signal cancelMembershipRequest(string communityId)

    interactive: false
    implicitHeight: contentItem.childrenRect.height
    spacing: 0

    delegate: StatusListItem {
        id: listItem

        width: ListView.view.width
        title: model.name
        statusListItemTitle.font.pixelSize: Theme.secondaryAdditionalTextSize
        statusListItemTitle.font.bold: true
        statusListItemIcon.anchors.verticalCenter: undefined
        statusListItemIcon.anchors.top: statusListItemTitleArea.top
        subTitle: model.description
        tertiaryTitle: qsTr("%n member(s)", "", model.joinedMembersCount)
        statusListItemTertiaryTitle.font.weight: Font.Medium
        statusListItemTertiaryTitle.font.pixelSize: Theme.fontSize(12)
        asset.name: model.image
        asset.isLetterIdenticon: !model.image
        asset.bgColor: model.color || Theme.palette.primaryColor1
        asset.width: 40
        asset.height: 40

        onClicked: root.setActiveCommunityClicked(model.id)

        readonly property bool isSpectator: model.spectated && !model.joined
        readonly property bool isOwner: model.memberRole === Constants.memberRole.owner
        readonly property bool isAdmin: model.memberRole === Constants.memberRole.admin
        readonly property bool isTokenMaster: model.memberRole === Constants.memberRole.tokenMaster
        property bool isInvitationPending: root.fnIsMyCommunityRequestPending(model.id)

        components: [
            StatusFlatButton {
                anchors.verticalCenter: parent.verticalCenter
                size: StatusBaseButton.Size.Small
                icon.name: "notification-muted"
                icon.color: Theme.palette.baseColor1
                visible: model.muted
                tooltip.text: qsTr("Unmute Community")
                onClicked: root.setCommunityMutedClicked(model.id, Constants.MutingVariations.Unmuted)
            },
            Loader {
                sourceComponent: StatusFlatButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: StatusBaseButton.Size.Small
                    text: listItem.isInvitationPending ? qsTr("Membership Request Sent") : qsTr("View & Join Community")
                    onClicked: root.showCommunityMembershipSetupDialog(model.id, model.name, model.introMessage, model.image, model.access)
                }
                active: listItem.isSpectator && !root.compactMode
                width: active ? implicitWidth : 0
            },
            StatusFlatButton {
                anchors.verticalCenter: parent.verticalCenter
                size: StatusBaseButton.Size.Small
                icon.name: "more"
                icon.color: Theme.palette.directColor1

                property var menu: null
                highlighted: menu?.opened ?? false
                onClicked: {
                    menu = moreMenuComponent.createObject(this, {listItem, model})
                    menu.popup(-menu.width + width, height)
                }
            }
        ]
    }

    Component  {
        id: moreMenuComponent
        StatusMenu {
            id: moreMenu
            onClosed: destroy()

            property var listItem
            property var model

            StatusAction {
                text: listItem.isInvitationPending ? qsTr("Membership Request Sent") : qsTr("View & Join Community")
                enabled: listItem.isSpectator && root.compactMode
                onTriggered: {
                    moreMenu.close()
                    root.showCommunityMembershipSetupDialog(model.id, model.name, model.introMessage, model.image, model.access)
                }
            }
            StatusAction {
                text: qsTr("Community Admin")
                icon.name: "settings"
                enabled: listItem.isOwner || listItem.isAdmin || listItem.isTokenMaster
                onTriggered: {
                    moreMenu.close()
                    Global.switchToCommunity(model.id)
                    Global.switchToCommunitySettings(model.id)
                }
            }
            StatusAction {
                text: qsTr("Unmute Community")
                enabled: model.muted
                icon.name: "notification"
                onTriggered: {
                    moreMenu.close()
                    root.setCommunityMutedClicked(model.id, Constants.MutingVariations.Unmuted)
                }
            }
            MuteChatMenuItem {
                enabled: (model.joined || (listItem.isSpectator && !listItem.isInvitationPending)) && !model.muted
                title: qsTr("Mute Community")
                onMuteTriggered: function(interval) {
                    moreMenu.close()
                    root.setCommunityMutedClicked(model.id, interval)
                }
            }
            StatusAction {
                text: qsTr("Invite People")
                icon.name: "invite-users"
                onTriggered: {
                    moreMenu.close()
                    root.inviteFriends(model)
                }
                objectName: "invitePeople"
            }
            StatusAction {
                text: qsTr("Edit Shared Addresses")
                icon.name: "wallet"
                enabled: {
                    if (listItem.isOwner || listItem.isSpectator)
                        return false
                    return true
                }
                onTriggered: {
                    moreMenu.close()
                    Global.openEditSharedAddressesFlow(model.id)
                }
            }
            StatusMenuSeparator {
                visible: leaveMenuItem.enabled
            }
            StatusAction {
                id: leaveMenuItem
                objectName: "CommunitiesListPanel_leaveCommunityPopupButton"
                text: {
                    if (listItem.isInvitationPending)
                        return qsTr("Cancel Membership Request")
                    return listItem.isSpectator ? qsTr("Close Community") : qsTr("Leave Community")
                }
                icon.name: {
                    if (listItem.isInvitationPending)
                        return "arrow-left"
                    return listItem.isSpectator ? "close-circle" : "arrow-left"
                }
                type: StatusAction.Type.Danger
                enabled: !listItem.isOwner
                onTriggered: {
                    moreMenu.close()
                    if (listItem.isInvitationPending) {
                        root.cancelMembershipRequest(model.id)
                        listItem.isInvitationPending = root.fnIsMyCommunityRequestPending(model.id)
                    } else if (listItem.isSpectator)
                        root.closeCommunityClicked(model.id)
                    else
                        root.leaveCommunityClicked(model.name, model.id, model.outroMessage)
                }
            }
        }
    }
}
