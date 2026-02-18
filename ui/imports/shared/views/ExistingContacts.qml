import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import utils
import shared.status
import shared.stores
// TODO move Contact into shared to get rid of that import
import AppLayouts.Chat.controls
import AppLayouts.stores as AppLayoutStores

import SortFilterProxyModel

Item {
    id: root

    property var contactsModel
    property var membersModel
    property string communityId

    property string filterText: ""
    property bool expanded: true
    property bool showCheckbox: false
    property bool hideCommunityMembers: false
    property var pubKeys: ([])

    readonly property alias count: contactListView.count

    signal contactClicked(var contact)

    function matchesAlias(name, filter) {
        let parts = name.split(" ")
        return parts.some(p => p.startsWith(filter))
    }

    implicitWidth: contactListView.implicitWidth + contactListView.margins
    implicitHeight: visible ? Math.min(contactListView.contentHeight, (expanded ? 320 : 192)) : 0

    StatusListView {
        id: contactListView
        objectName: "ExistingContacts_ListView"
        anchors.fill: parent
        rightMargin: 0
        leftMargin: 0
        spacing: Theme.padding

        model: SortFilterProxyModel {
            sourceModel: root.contactsModel
            filters: [
                FastExpressionFilter {
                    expression: {
                        root.filterText
                        root.hideCommunityMembers
                        root.communityId

                        if (!model.isContact || model.isBlocked)
                            return false

                        const filter = root.filterText.toLowerCase()
                        const filterAccepted = root.filterText === ""
                                             || root.matchesAlias(model.alias.toLowerCase(), filter)
                                             || model.displayName.toLowerCase().includes(filter)
                                             || model.ensName.toLowerCase().includes(filter)
                                             || model.localNickname.toLowerCase().includes(filter)
                                             || model.pubKey.toLowerCase().includes(filter)

                        if (!filterAccepted)
                            return false

                        return !root.hideCommunityMembers ||
                               !root.membersModel.hasMember(model.pubKey)
                    }
                    expectedRoles: [ "isContact", "isBlocked", "alias", "displayName", "ensName", "localNickname", "pubKey" ]
                }
            ]
        }

        delegate: StatusMemberListItem {
            objectName: "statusMemberListItem-%1".arg(model.compressedPubKey)
            width: contactListView.availableWidth
            pubKey: model.isEnsVerified ? "" : model.compressedPubKey
            isContact: model.isContact
            status: model.onlineStatus
            height: visible ? implicitHeight : 0
            color: hovered ? Theme.palette.baseColor2 : "transparent"
            nickName: model.localNickname
            userName: ProfileUtils.displayName("", model.ensName, model.displayName, model.alias)
            icon.name: model.icon
            icon.width: 40
            icon.height: 40
            icon.color: Utils.colorForColorId(Theme.palette, model.colorId)

            onClicked: {
                root.contactClicked(model);
            }

            StatusCheckBox  {
                id: contactCheckbox
                objectName: "contactCheckbox-%1".arg(model.displayName)
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.halfPadding
                checked: root.pubKeys.indexOf(model.pubKey) > -1
                onClicked: {
                    root.contactClicked(model);
                }
            }
        }
    }
}
