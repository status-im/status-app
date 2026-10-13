import QtQuick

import StatusQ

import AppLayouts.Communities.controls

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ.Core.Utils as StatusQUtils

import utils


/// Helper component for editing channel permissions
/// This component will create the necessary temporary models to be used until the changes are saved

QtObject {
    id: root

    // Input properties

    // Model containing all channels
    required property var channelsModel
    // Model containing all permissions for the current community
    required property var permissionsModel

    // Channel ID
    required property string channelId
    // Channel name
    required property string name
    // Channel color
    required property string color
    // Channel emoji
    required property string emoji
    // Specify whether the channel is being edited or created
    required property bool newChannelMode


    // Output properties

    // The edited channel permissions model
    readonly property alias channelPermissionsModel: d.channelPermissionsModel
    // Live model of channels contaning the temporarely edited channel
    readonly property alias liveChannelsModel: d.liveChannelsModel

    readonly property alias dirtyPermissions: d.channelPermissionsModel.dirty


    // Input functions

    // Function creating a new permission based on the given arguments
    function appendPermission(holdings, channels, permissionType, isPrivate) {
        d.appendPermission(holdings, channels, permissionType, isPrivate)
    }

    // Function editing a permission based on the given arguments
    function editPermission(key, permissionType, holdings, channels, isPrivate) {
        d.editPermission(key, permissionType, holdings, channels, isPrivate)
    }

    // Function removing a permission by index
    function removePermission(index) {
        return channelPermissionsModel.remove(index, 1);
    }


    // Output functions

    // Function returning the list of added permissions
    // The returned list contains the permissions that were added since the last reset
    // Each item contains a map of role names and data value pairs as defined in the model
    function getAddedPermissions() {
        return d.flattenPermissions(channelPermissionsModel.getInsertedItems())
    }

    // Function returning the list of removed permissions
    // The returned list contains the permissions that were removed since the last reset
    // This list contains the permissions that are no longer available in the root.channelPermissionsModel, but are still available in the root.permissionsModel
    // Each item contains a map of role names and data value pairs as defined in the model
    function getRemovedPermissions() {
        return d.flattenPermissions(channelPermissionsModel.getRemovedItems())
    }

    // Function returning the list of edited permissions
    // The returned list contains the permissions that were edited since the last reset
    // Each item contains a map of role names and data value pairs as defined in the model
    function getEditedPermissions() {
        return d.flattenPermissions(channelPermissionsModel.getEditedItems())
    }

    // This function resets the temporary models
    // The dirtyPermissions property will be set to false
    function reset() {
        d.reset()
    }

    //internals
    readonly property QtObject d: QtObject {
        id: d
        
        signal resetDone()

        function reset() {
            channelPermissionsModel.revert();
            liveChannelsModel.revert();
            d.resetDone();
        }

        function appendPermission(holdings, channels, permissionType, isPrivate) {
            var permissionsModelData = {
                    id: Utils.uuid(),
                    key: Utils.uuid(),
                    holdingsListModel: d.newHoldingsModel(holdings),
                    channelsListModel: d.newChannelsModel(channels),
                    "permissionType": permissionType,
                    "isPrivate": isPrivate
                };

            d.channelPermissionsModel.append(permissionsModelData)
        }

        function editPermission(key, permissionType, holdings, channels, isPrivate) {
            const index = StatusQUtils.ModelUtils.indexOf(d.channelPermissionsModel, "key", key)
            if (index === -1)
                return

            const permissionItem = d.channelPermissionsModel.get(index)

            d.channelPermissionsModel.set(index, {
                "permissionType": permissionType,
                "channelsListModel": d.newEditedChannelsModel(channels, permissionItem.channelsListModel),
                "holdingsListModel": d.newEditedHoldingsModel(holdings, permissionItem.holdingsListModel),
                "isPrivate": isPrivate
            })
        }

        // Creates a new channel model to be used in the permissions model
        // Expected roles: "key"
        function newChannelsModel(channelsArray) {
            var channelsModel = selfDestroyingModel.createObject(d.channelPermissionsModel);

            for (var i = 0; i < channelsArray.length; i++) {
                channelsModel.append({ key: channelsArray[i].key })
            }

            return channelsModel;
        }

        // Creates a new writable channel model on top of base model to be used in the permissions model
        function newEditedChannelsModel(channelsArray, baseModel) {
            var channelsModel = selfDestroyingWritableModel.createObject(d.channelPermissionsModel, {sourceModel: baseModel});

            const count = channelsModel.rowCount()
            for (var i = 0; i < count; i++) {
                const ok = channelsModel.remove(0)

                console.assert(ok
                    , "Failed to remove channel")
            }

            for (var i = 0; i < channelsArray.length; i++) {
                const ok = channelsModel.append({
                    key: channelsArray[i].key,
                })

                console.assert(ok, "Failed to append channel");
            }

            return channelsModel;
        }

        // Creates a new holdings model to be used in the permissions model
        function newHoldingsModel(holdingsArray, sourceModel) {
            var holdingsModel = selfDestroyingModel.createObject(d.channelPermissionsModel);
            for (var i = 0; i < holdingsArray.length; i++) {
                holdingsModel.append(holdingsArray[i]);
            }
            
            return holdingsModel;
        }

        function newEditedHoldingsModel(holdingsArray, baseModel) {
            var holdingsModel = selfDestroyingWritableModel.createObject(d.channelPermissionsModel, {sourceModel: baseModel});

            const count = holdingsModel.rowCount()
            for (var i = 0; i < count; i++) {
                const ok = holdingsModel.remove(0)
                console.assert(ok, "Failed to remove holding")
            }

            for (var i = 0; i < holdingsArray.length; i++) {
                const ok = holdingsModel.append(holdingsArray[i])
                console.assert(ok, "Failed to append holding");
            }
            
            return holdingsModel;
        }

        function flattenPermissions(permissionsItems) {
            for (var i = 0; i < permissionsItems.length; i++) {
                permissionsItems[i].holdingsListModel = StatusQUtils.ModelUtils.modelToArray(permissionsItems[i].holdingsListModel)
                permissionsItems[i].channelsListModel = StatusQUtils.ModelUtils.modelToArray(permissionsItems[i].channelsListModel)
            }

            return permissionsItems
        }


        property Connections chatIdConnections: Connections {
            target: root
            enabled: root.newChannelMode

            property string previousChannelId: ""

            Component.onCompleted: previousChannelId = root.channelId

            /// go through all the channels and replace the old channel id with the new one
            function onChannelIdChanged() {
                if (previousChannelId === root.channelId)
                    return;

                if (previousChannelId == "") {
                    previousChannelId = root.channelId;
                    return;
                }

                for (var i = 0; i < liveChannelsModel.rowCount(); i++) {
                    if (liveChannelsModel.get(i).itemId === previousChannelId) {
                        liveChannelsModel.set(i, { itemId: root.channelId })
                        break;
                    }
                }

                for (var i = 0; i < channelPermissionsModel.rowCount(); i++) {
                    const currentItem = channelPermissionsModel.get(i)
                    const channelsListModel = currentItem.channelsListModel
                    
                    for (var j = 0; j < channelsListModel.rowCount(); j++) {
                        if (channelsListModel.get(j).key === previousChannelId) {
                            channelsListModel.set(j, { key: root.channelId })
                            break;
                        }
                    }
                }
                previousChannelId = root.channelId;
            }
        }
        
        readonly property var filteredPermissionsModel: SortFilterProxyModel {
            sourceModel: root.permissionsModel

            filters: [
                FastExpressionFilter {
                    function filterPredicate(id, permissionType) {
                        return !PermissionTypes.isCommunityPermission(permissionType)
                    }
                    expression: {
                        return filterPredicate(model.id, model.permissionType)
                    }
                    expectedRoles: [ "id", "permissionType" ]
                }
            ]
        }

        // Channel permissions model containing the temporarely edited permissions
        property WritableProxyModel channelPermissionsModel: WritableProxyModel {
            sourceModel: d.filteredPermissionsModel
        }

        // Channels model containing the temporarely edited channel
        property WritableProxyModel liveChannelsModel: WritableProxyModel {
            id: newChannelModel

            function updateCurrentChannelProperty(nameAndValue) {
                const index = StatusQUtils.ModelUtils.indexOf(newChannelModel, "itemId", root.channelId)
                if (index !== -1) {
                    newChannelModel.set(index, nameAndValue)                    
                }
            }

            Component.onCompleted: {
                if (!root.newChannelMode)
                    return;

                console.assert(newChannelModel.append({
                    itemId: root.channelId,
                    name: root.name,
                    emoji: root.emoji,
                    color: root.color,
                    isThread: false
                }), "Failed to add channel to channelsModel")
            }

            property Connections channelConnections: Connections {
                target: root
                function onColorChanged() {
                    newChannelModel.updateCurrentChannelProperty({"color": root.color})
                }
                function onNameChanged() {
                    newChannelModel.updateCurrentChannelProperty({"name": root.name})
                }
                function onEmojiChanged() {
                    newChannelModel.updateCurrentChannelProperty({"emoji": root.emoji})
                }
            }

            sourceModel: root.channelsModel
        }

        // Used for dynamic model creation using Component.createObject
        property Component selfDestroyingModel: Component {
            ListModel {
                id: model

                Component.onCompleted: d.resetDone.connect(model.destroy)
                Component.onDestruction: d.resetDone.disconnect(model.destroy)
            }
        }

        property Component selfDestroyingWritableModel: Component {
            WritableProxyModel {
                id: model

                Component.onCompleted: d.resetDone.connect(model.destroy)
                Component.onDestruction: d.resetDone.disconnect(model.destroy)
            }
        }
    }
}
