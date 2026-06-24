import QtQuick
import QtQml.Models
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ
import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import SortFilterProxyModel

import AppLayouts.Profile.controls
import AppLayouts.Communities.controls
import AppLayouts.Communities.views
import AppLayouts.Communities.helpers

import utils

Control {
    id: root

    required property string componentUid
    required property bool isEditMode
    required property var selectedSharedAddressesMap // Map[address, [keyUid, selected, isAirdrop]
    property var currentSharedAddressesMap // Map[address, [keyUid, selected, isAirdrop]
    required property int totalNumOfAddressesForSharing
    required property int /*PermissionTypes.Type*/ eligibleToJoinAs

    property bool requirementsCheckPending
    property bool checkingPermissionToJoinInProgress
    property bool joinPermissionsCheckCompletedWithoutErrors

    required property string communityId
    required property string communityName
    required property string communityIcon

    required property var walletAssetsModel
    required property var walletCollectiblesModel

    required property var walletAccountsModel // name, address, emoji, colorId
    required property var permissionsModel  // id, key, permissionType, holdingsListModel, channelsListModel, isPrivate, tokenCriteriaMet

    required property var assetsModel
    required property var collectiblesModel

    readonly property string title: isEditMode ? qsTr("Edit which addresses you share with %1").arg(root.communityName)
                                               : qsTr("Select addresses to share with %1").arg(root.communityName)

    readonly property var rightButtons: root.isEditMode? [d.cancelButton, d.saveButton] : [d.shareAddressesButton]

    property var getCurrencyAmount: function (balance, key){}

    signal toggleAddressSelection(string keyUid, string address)
    signal airdropAddressSelected (string address)
    signal shareSelectedAddressesClicked()
    signal close()

    padding: 0
    spacing: Theme.padding

    QtObject {
        id: d

        // internal logic
        readonly property bool hasPermissions: permissionsView.hasAnyVisiblePermission
        readonly property int selectedSharedAddressesCount: root.selectedSharedAddressesMap.size

        readonly property bool dirty: {
            if (root.currentSharedAddressesMap.size !== root.selectedSharedAddressesMap.size) {
                return true
            }
            for (const [key, value] of root.currentSharedAddressesMap) {
                const obj = root.selectedSharedAddressesMap.get(key)
                if (!obj || value.selected !== obj.selected || value.isAirdrop !== obj.isAirdrop) {
                    return true
                }
            }
            return false
        }

        property var tokenCountMap: new Map()
        function getTokenCount(address) {
            if (d.tokenCountMap.has(address))
                return d.tokenCountMap.get(address)
            return 0
        }

        // warning states
        readonly property bool lostCommunityPermission: root.isEditMode && permissionsView.lostPermissionToJoin
        readonly property bool lostChannelPermissions: root.isEditMode && permissionsView.lostChannelPermissions

        readonly property var cancelButton: StatusFlatButton {
            visible: root.isEditMode
            borderColor: Theme.palette.baseColor2
            text: qsTr("Cancel")
            onClicked: root.close()
        }

        readonly property string tooltipText: {
            if (root.requirementsCheckPending || root.checkingPermissionToJoinInProgress)
                return qsTr("Requirements check pending")

            if (!root.joinPermissionsCheckCompletedWithoutErrors)
                return qsTr("Checking permissions failed")

            return ""
        }

        readonly property var saveButton: StatusButton {
            visible: root.isEditMode
            interactive: d.dirty && !root.requirementsCheckPending && root.joinPermissionsCheckCompletedWithoutErrors
            loading: root.requirementsCheckPending
            type: d.lostCommunityPermission || d.lostChannelPermissions ? StatusBaseButton.Type.Danger : StatusBaseButton.Type.Normal
            tooltip.text: {
                if (interactive)
                    return ""

                return d.tooltipText
            }
            text: {
                if (d.lostCommunityPermission) {
                    return qsTr("Save changes & leave %1").arg(root.communityName)
                }
                if (d.lostChannelPermissions) {
                    return qsTr("Save changes & update my permissions")
                }
                if (d.selectedSharedAddressesCount === root.totalNumOfAddressesForSharing) {
                    return qsTr("Reveal all addresses")
                }
                return qsTr("Reveal %n address(s)", "", d.selectedSharedAddressesCount)
            }

            onClicked: {
                root.shareSelectedAddressesClicked()
            }
        }

        readonly property var shareAddressesButton: StatusButton {
            visible: !root.isEditMode
            interactive: !root.checkingPermissionToJoinInProgress && root.eligibleToJoinAs !== PermissionTypes.Type.None && root.joinPermissionsCheckCompletedWithoutErrors
            loading: root.checkingPermissionToJoinInProgress
            tooltip.text: {
                if (interactive)
                    return ""

                return d.tooltipText
            }
            text: {
                if (d.selectedSharedAddressesCount === root.totalNumOfAddressesForSharing) {
                    return qsTr("Share all addresses to join")
                }
                return qsTr("Share %n address(s) to join", "", d.selectedSharedAddressesCount)
            }

            onClicked: {
                root.shareSelectedAddressesClicked()
            }
        }
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // warning panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Theme.palette.dangerColor1
            visible: d.lostCommunityPermission || d.lostChannelPermissions

            StatusBaseText {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Qt.AlignHCenter
                elide: Text.ElideRight
                text: d.lostCommunityPermission ? qsTr("Selected addresses have insufficient tokens to maintain %1 membership").arg(root.communityName) :
                                                  d.lostChannelPermissions ? qsTr("By deselecting these addresses, you will lose channel permissions") :
                                                                             ""
                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
                color: Theme.palette.indirectColor1
            }
        }

        // addresses
        SharedAddressesAccountSelector {
            id: accountSelector
            hasPermissions: d.hasPermissions

            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight + topMargin + bottomMargin
            Layout.maximumHeight: hasPermissions ? permissionsView.implicitHeight > root.availableHeight / 2 ? root.availableHeight / 2 : root.availableHeight : -1
            Layout.fillHeight: !hasPermissions
            implicitHeight: contentHeight

            uniquePermissionAssetsKeys:
                PermissionsHelpers.getUniquePermissionTokenKeys(
                    root.permissionsModel, Constants.TokenType.ERC20)

            uniquePermissionCollectiblesKeys:
                PermissionsHelpers.getUniquePermissionTokenKeys(
                    root.permissionsModel, Constants.TokenType.ERC721)

            model: SortFilterProxyModel {
                sourceModel: root.walletAccountsModel
                proxyRoles: FastExpressionRole {
                    name: "tokenCount"
                    expression: {
                        d.tokenCountMap
                        return d.getTokenCount(model.address.toLowerCase())
                    }
                    expectedRoles: ["address"]
                }

                sorters: [
                    // FIXME add sort token-relevant accounts first; https://github.com/status-im/status-app/issues/14192
                    RoleSorter {
                        roleName: "tokenCount"
                        sortOrder: Qt.DescendingOrder
                    },
                    RoleSorter {
                        roleName: "name"
                    }
                ]
            }
            walletAssetsModel: root.walletAssetsModel
            walletCollectiblesModel: root.walletCollectiblesModel

            communityId: root.communityId
            communityCollectiblesModel: root.collectiblesModel

            selectedSharedAddressesMap: root.selectedSharedAddressesMap

            onToggleAddressSelection: (keyUid, address) => {
                root.toggleAddressSelection(keyUid, address)
            }

            onAirdropAddressSelected: (address) => {
                root.airdropAddressSelected(address)
            }

            getCurrencyAmount: (balance, key) => {
                return root.getCurrencyAmount(balance, key)
            }

            Component.onCompleted: {
                const tmpTokenCountMap = new Map()
                for (let i = 0; i < accountSelector.count; i++) {
                    const item = accountSelector.itemAtIndex(i)
                    if (!!item) {
                        tmpTokenCountMap.set(item.address.toLowerCase(), item.tokenCount)
                    }
                }
                d.tokenCountMap = tmpTokenCountMap
            }
        }

        // divider with top rounded corners + drop shadow
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.padding * 2
            color: permissionsView.color
            radius: Theme.padding
            border.width: 1
            border.color: Theme.palette.baseColor3
            visible: permissionsView.hasAnyVisiblePermission

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: -9
                radius: 14
                samples: 29
                color: Qt.rgba(0, 0, 0, 0.04)
            }
        }

        // permissions
        SharedAddressesPermissionsPanel {
            id: permissionsView
            isEditMode: root.isEditMode
            isDirty: d.dirty
            permissionsModel: root.permissionsModel
            assetsModel: root.assetsModel
            collectiblesModel: root.collectiblesModel
            requirementsCheckPending: root.requirementsCheckPending
            checkingPermissionToJoinInProgress: root.checkingPermissionToJoinInProgress
            joinPermissionsCheckCompletedWithoutErrors: root.joinPermissionsCheckCompletedWithoutErrors
            communityName: root.communityName
            communityIcon: root.communityIcon
            eligibleToJoinAs: root.eligibleToJoinAs

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.topMargin: -Theme.padding // compensate for the half-rounded divider above
            visible: permissionsView.hasAnyVisiblePermission
        }
    }
}
