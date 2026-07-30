import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import shared.status
import shared.popups
import utils

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

import QtModelsToolkit
import SortFilterProxyModel

ColumnLayout {
    id: root

    spacing: 24

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    property int topPadding: count ? 16 : 0

    required property var permissionsModel
    required property var assetsModel
    required property var collectiblesModel
    required property var channelsModel

    // Returns token that matches provided key (key can be token or group key). Use it as a last option (may affect app performances, because it fetches all tokens from stautsgo).
    property var getTokenByKeyOrGroupKeyFromAllTokens: function(key){ return {}}

    // id, name, image, color, owner, admin properties expected
    required property QtObject communityDetails

    property bool viewOnlyCanAddReaction
    property bool showChannelOptions: false
    property bool allowIntroPanel: true

    signal editPermissionRequested(int index)
    signal duplicatePermissionRequested(int index)
    signal removePermissionRequested(int index)
    signal userRestrictionsToggled(bool checked)

    readonly property alias count: listView.count

    QtObject {
        id: d

        property int permissionIndexToRemove
    }

    Connections {
        target: root.communityDetails
        function onNameChanged(){
            resetCommunityItemModel()
        }
        function onImageChanged(){
            resetCommunityItemModel()
        }
        function onColorChanged(){
            resetCommunityItemModel()
        }
    }

    function resetCommunityItemModel() {
        communityItemModel.clear()
        communityItemModel.append({
                   text: root.communityDetails.name,
                   imageSource: root.communityDetails.image,
                   color: root.communityDetails.color
               })
    }

    ListModel {
        id: communityItemModel
        Component.onCompleted: resetCommunityItemModel()
    }

    IntroPanel {
        Layout.fillWidth: true
        Layout.maximumWidth: root.preferredContentWidth
        Layout.rightMargin: root.internalRightPadding

        visible: (root.count === 0 && root.allowIntroPanel)

        image: Assets.png("community/permissions2_3")
        title: qsTr("Permissions")
        subtitle: qsTr("You can manage your community by creating and issuing membership and access permissions")
        checkersModel: [
            qsTr("Give individual members access to private channels"),
            qsTr("Monetise your community with subscriptions and fees"),
            qsTr("Require holding a token or NFT to obtain exclusive membership rights")
        ]
    }

    StatusListView {
        id: listView

        reuseItems: true
        model: root.permissionsModel
        spacing: 24

        // It allows to unroll the list when the outer layout height is unbound
        Layout.preferredHeight: contentHeight
        Layout.topMargin: root.topPadding
        Layout.fillWidth: true
        Layout.fillHeight: true

        delegate: PermissionItem {
            width: Math.min(ListView.view.width - root.internalRightPadding,
                            root.preferredContentWidth)

            holdingsListModel: HoldingsSelectionModel {
                sourceModel: model.holdingsListModel
                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
                getTokenByKeyOrGroupKeyFromAllTokens: root.getTokenByKeyOrGroupKeyFromAllTokens
            }

            permissionType: model.permissionType
            permissionState: model.permissionState // TODO: Backend!

            LeftJoinModel {
                id: channelsSelectionModel

                leftModel: model.channelsListModel ?? null
                rightModel: root.channelsModel
                joinRole: "key"
            }

            channelsListModel: model.channelsListModel.rowCount()
                                    ? channelsSelectionModel : communityItemModel
            isPrivate: model.isPrivate

            showButtons: (model.permissionType !== PermissionTypes.Type.TokenMaster &&
                          model.permissionType !== PermissionTypes.Type.Owner) &&
                         (!!root.communityDetails && (root.communityDetails.owner ||
                                                      ((root.communityDetails.admin || root.communityDetails.tokenMaster) && model.permissionType !== PermissionTypes.Type.Admin)))

            onEditClicked: root.editPermissionRequested(model.index)
            onDuplicateClicked: root.duplicatePermissionRequested(model.index)

            onRemoveClicked: {
                d.permissionIndexToRemove = index
                declineAllDialog.open()
            }
        }
    }

    StatusBaseText {
        id: noPermissionsLabel
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.maximumWidth: root.preferredContentWidth
        Layout.rightMargin: root.internalRightPadding

        visible: (root.count === 0 && root.showChannelOptions)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: qsTr("No channel permissions")
        wrapMode: Text.Wrap
        color: Theme.palette.secondaryText
    }

    StatusIconSwitch {
        Layout.fillWidth: true
        Layout.maximumWidth: root.preferredContentWidth
        Layout.rightMargin: root.internalRightPadding

        padding: 0

        visible: root.showChannelOptions
        title: qsTr("Users with view only permissions can add reactions")
        icon: "emojis"
        checked: root.viewOnlyCanAddReaction
        onToggled: {
            root.userRestrictionsToggled(checked);
        }
    }

    ConfirmationDialog {
        id: declineAllDialog

        confirmButtonObjectName: "confirmDeletePermissionButton"
        headerSettings.title: qsTr("Sure you want to delete permission")
        confirmationText: qsTr("If you delete this permission, any of your community members who rely on this permission will lose the access this permission gives them.")

        onConfirmButtonClicked: {
            root.removePermissionRequested(d.permissionIndexToRemove)
            close()
        }
    }
}
