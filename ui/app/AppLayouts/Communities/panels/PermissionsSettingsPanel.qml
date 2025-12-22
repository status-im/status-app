import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Communities.controls
import AppLayouts.Communities.layouts
import AppLayouts.Communities.views

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils
import shared.popups

import SortFilterProxyModel

StackView {
    id: root

    required property var permissionsModel
    required property var assetsModel
    required property var collectiblesModel
    required property var channelsModel

    // Returns token that matches provided key (key can be token or group key). Use it as a last option (may affect app performances, because it fetches all tokens from stautsgo).
    property var getTokenByKeyOrGroupKeyFromAllTokens: function(key){ return {}}

    property bool showChannelSelector: true
    property bool ensCommunityPermissionsEnabled
    property alias initialPage: initialItem
    property bool saveInProgress: false
    property string errorSaving: ""

    // id, name, image, color, owner properties expected
    required property var communityDetails

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    property string previousPageName: depth > 1 ? qsTr("Permissions") : ""

    signal createPermissionRequested(int permissionType, var holdings,
                                     var channels, bool isPrivate)
    signal updatePermissionRequested(string key, int permissionType,
                                     var holdings, var channels, bool isPrivate)
    signal removePermissionRequested(string key)
    signal navigateToMintTokenSettings(bool isAssetType)

    function permissionSavedSuccessfully() {
        // Go back to the permissions list after successful save
        root.pop(StackView.Immediate)
    }

    function navigateBack() {
        if (depth === 2 && currentItem.toast.active)
            currentItem.toast.notifyDirty()
        else
            pop(StackView.Immediate)
    }

    function pushEditView(properties) {
        root.push(newPermissionView, properties, StackView.Immediate);
    }

    SortFilterProxyModel {
        id: allChannelsTransformed

        sourceModel: root.channelsModel

        proxyRoles: [
            FastExpressionRole {
                name: "key"
                expression: model.itemId ?? ""
                expectedRoles: ["itemId"]
            },
            FastExpressionRole {
                name: "text"
                expression: "#" + model.name
                expectedRoles: ["name"]
            },
            FastExpressionRole {
                name: "imageSource"
                expression: model.icon
                expectedRoles: ["icon"]
            },
            FastExpressionRole {
                name: "operator"

                // Direct call for singleton enum is not handled properly by SortFilterProxyModel.
                readonly property int none: OperatorsUtils.Operators.None

                expression: none
                expectedRoles: []
            }
        ]
    }


    // Community Permissions possible view contents:
    initialItem: SettingsPage {
        id: initialItem

        title: qsTr("Permissions")

        preferredHeaderContentWidth: root.preferredContentWidth
        headerRightPadding: root.internalRightPadding

        buttons: StatusButton {
            objectName: "addNewItemButton"

            text: qsTr("Add new permission")

            Layout.fillWidth: true

            onClicked: root.push(newPermissionView, StackView.Immediate)
        }

        contentItem: PermissionsView {
            id: permissionsView

            permissionsModel: root.permissionsModel
            assetsModel: root.assetsModel
            collectiblesModel: root.collectiblesModel
            channelsModel: allChannelsTransformed

            getTokenByKeyOrGroupKeyFromAllTokens: root.getTokenByKeyOrGroupKeyFromAllTokens

            communityDetails: root.communityDetails

            preferredContentWidth: root.preferredContentWidth
            internalRightPadding: root.internalRightPadding

            onEditPermissionRequested: (index) => {
                const item = ModelUtils.get(root.permissionsModel, index)

                const properties = {
                    permissionKeyToEdit: item.key,
                    holdingsToEditModel: item.holdingsListModel,
                    channelsToEditModel: item.channelsListModel,
                    permissionTypeToEdit: item.permissionType,
                    isPrivateToEditValue: item.isPrivate
                }

                root.pushEditView(properties);
            }

            onDuplicatePermissionRequested: (index) => {
                const item = ModelUtils.get(root.permissionsModel, index)

                const properties = {
                    holdingsToEditModel: item.holdingsListModel,
                    channelsToEditModel: item.channelsListModel,
                    permissionTypeToEdit: item.permissionType,
                    isPrivateToEditValue: item.isPrivate
                }

                root.pushEditView(properties);
            }

            onRemovePermissionRequested: (index) => {
                const key = ModelUtils.get(root.permissionsModel, index, "key")
                root.removePermissionRequested(key)
            }
        }
    }

    Component {
        id: newPermissionView

        SettingsPage {
            id: newPermissionViewPage

            title: isEditState ? qsTr("Edit permission") : qsTr("New permission")

            property alias isSaveEnabled: editPermissionView.saveEnabled
            property alias isPrivateToEditValue: editPermissionView.isPrivate
            property alias permissionTypeToEdit: editPermissionView.permissionType
            property alias holdingsToEditModel: editPermissionView.selectedHoldingsModel
            property alias channelsToEditModel: editPermissionView.selectedChannelsModel

            property bool holdingsRequired: editPermissionView.dirtyValues.holdingsRequired

            property string permissionKeyToEdit
            readonly property bool isEditState: !!permissionKeyToEdit

            readonly property alias toast: settingsDirtyToastMessage

            function resetChanges() {
                editPermissionView.resetChanges();
            }
            function updatePermission() {
                editPermissionView.saveChanges();
            }
            function createPermission() {
                editPermissionView.createPermissionClicked();
            }

            contentItem: EditPermissionView {
                id: editPermissionView

                preferredContentWidth: root.preferredContentWidth
                internalRightPadding: root.internalRightPadding

                SortFilterProxyModel {
                    id: nonOwnerCollectibles
                    sourceModel: root.collectiblesModel
                    filters: [
                        ValueFilter {
                            roleName: "privilegesLevel"
                            value: Constants.TokenPrivilegesLevel.Owner
                            inverted: true
                        }
                    ]
                }

                assetsModel: root.assetsModel
                collectiblesModel: nonOwnerCollectibles
                channelsModel: allChannelsTransformed
                communityDetails: root.communityDetails
                showChannelSelector: root.showChannelSelector
                isEditState: newPermissionViewPage.isEditState
                ensCommunityPermissionsEnabled: root.ensCommunityPermissionsEnabled
                holdingsRequired: selectedHoldingsModel
                                  ? selectedHoldingsModel.count > 0 : false
                saveInProgress: root.saveInProgress
                errorSaving: root.errorSaving

                permissionDuplicated: {
                    // dependencies
                    holdingsTracker.revision
                    channelsTracker.revision
                    editPermissionView.dirtyValues.permissionType
                    editPermissionView.dirtyValues.isPrivate
                    const model = root.permissionsModel
                    const count = model.rowCount()

                    for (let i = 0; i < count; i++) {
                        const item = ModelUtils.get(model, i)

                        if (newPermissionViewPage.permissionKeyToEdit === item.key)
                            continue

                        const holdings = item.holdingsListModel
                        const channels = item.channelsListModel
                        const permissionType = item.permissionType

                        const same = (a, b) => ModelUtils.checkEqualitySet(a, b, ["key"])

                        if (holdings.rowCount() === 0)
                            if (dirtyValues.holdingsRequired)
                                continue
                            else
                                return true

                        if (holdings.rowCount() !== 0 && !dirtyValues.holdingsRequired)
                            continue

                        const channelsModel = showChannelSelector ?
                                              dirtyValues.selectedChannelsModel :
                                              selectedChannelsModel

                        if (same(dirtyValues.selectedHoldingsModel, holdings)
                                && same(channelsModel, channels)
                                && dirtyValues.permissionType === permissionType)
                            return true
                    }

                    return false
                }

                readonly property var permissionTypeLimitReachedOrExceeded: {
                    const type = dirtyValues.permissionType
                    const limit = PermissionTypes.getPermissionsCountLimit(type)

                    if (limit === -1)
                        return [false, false]

                    const model = root.permissionsModel
                    const count = model.rowCount()
                    let sameTypeCount = 0

                    for (let i = 0; i < count; i++)
                        if (type === ModelUtils.get(model, i, "permissionType"))
                            sameTypeCount++

                    return [sameTypeCount >= limit, sameTypeCount > limit]
                }

                permissionTypeLimitReached: permissionTypeLimitReachedOrExceeded[0]
                permissionTypeLimitExceeded: permissionTypeLimitReachedOrExceeded[1]

                onCreatePermissionClicked: {
                    const holdings = dirtyValues.holdingsRequired ?
                                       ModelUtils.modelToArray(
                                           dirtyValues.selectedHoldingsModel,
                                           ["key", "type", "amount", "symbol"]) : []
                    const channels = root.showChannelSelector ?
                                   ModelUtils.modelToArray(
                                       dirtyValues.selectedChannelsModel, ["key"]) :
                                   ModelUtils.modelToArray(selectedChannelsModel, ["key"])

                    root.createPermissionRequested(
                                dirtyValues.permissionType, holdings, channels,
                                dirtyValues.isPrivate)
                }

                onNavigateToMintTokenSettings: root.navigateToMintTokenSettings(isAssetType)

                function saveChanges() {
                    const holdings = dirtyValues.holdingsRequired ?
                                       ModelUtils.modelToArray(
                                           dirtyValues.selectedHoldingsModel,
                                           ["key", "type", "amount", "symbol"])
                                     : []
                    const channels = ModelUtils.modelToArray(
                                       dirtyValues.selectedChannelsModel, ["key"])

                    root.updatePermissionRequested(
                                newPermissionViewPage.permissionKeyToEdit,
                                dirtyValues.permissionType, holdings, channels,
                                dirtyValues.isPrivate)
                }

                ModelChangeTracker {
                    id: holdingsTracker

                    model: editPermissionView.dirtyValues.selectedHoldingsModel
                }

                ModelChangeTracker {
                    id: channelsTracker

                    model: editPermissionView.dirtyValues.selectedChannelsModel
                }
            }

            SettingsDirtyToastMessage {
                id: settingsDirtyToastMessage

                z: 1
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 16
                }

                saveChangesText: qsTr("Update permission")
                cancelChangesText: qsTr("Revert changes")

                saveChangesButtonEnabled: editPermissionView.saveEnabled

                onSaveChangesClicked: {
                    editPermissionView.saveChanges()
                    root.pop(StackView.Immediate)
                }

                onResetChangesClicked: editPermissionView.resetChanges()

                Component.onCompleted: {
                    // delay to avoid toast blinking on entry
                    settingsDirtyToastMessage.active = Qt.binding(
                                     () => editPermissionView.isEditState &&
                                           editPermissionView.dirty &&
                                           root.showChannelSelector)
                }
            }
        }
    }
}
