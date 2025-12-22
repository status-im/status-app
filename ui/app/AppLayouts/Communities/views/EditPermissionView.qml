import QtQuick
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Utils

import utils
import shared.panels

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers
import AppLayouts.Communities.panels
import AppLayouts.Communities.popups

import QtModelsToolkit

StatusScrollView {
    id: root

    required property var assetsModel
    required property var collectiblesModel
    required property var channelsModel

    // id, name, image, color, owner properties expected
    required property var communityDetails

    readonly property bool saveEnabled: root.isFullyFilled
                     && !root.permissionDuplicated
                     && (isEditState ? !root.permissionTypeLimitExceeded : !root.permissionTypeLimitReached)

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    property bool isEditState: false

    readonly property bool dirty:
        root.holdingsRequired !== d.dirtyValues.holdingsRequired ||
        (d.dirtyValues.holdingsRequired && !holdingsModelComparator.equal) ||
        !channelsModelComparator.equal ||
        root.isPrivate !== d.dirtyValues.isPrivate ||
        root.permissionType !== d.dirtyValues.permissionType

    readonly property alias dirtyValues: d.dirtyValues

    readonly property bool isFullyFilled: (dirtyValues.selectedHoldingsModel.count > 0 || !whoHoldsSwitch.checked) &&
        dirtyValues.permissionType !== PermissionTypes.Type.None &&
        (d.isCommunityPermission || !showChannelSelector || dirtyValues.selectedChannelsModel.count > 0)

    property int permissionType: PermissionTypes.Type.None
    property bool isPrivate: false
    property bool holdingsRequired: true
    property bool showChannelSelector: true
    property bool ensCommunityPermissionsEnabled

    property bool saveInProgress: false
    property string errorSaving: ""

    // roles: type, key, name, amount, imageSource
    property var selectedHoldingsModel: ListModel {}

    // roles: itemId, text, icon, emoji, color, colorId
    property var selectedChannelsModel: ListModel {}

    property bool permissionDuplicated: false
    property bool permissionTypeLimitReached: false
    property bool permissionTypeLimitExceeded

    signal createPermissionClicked
    signal navigateToMintTokenSettings(bool isAssetType)

    function resetChanges() {
        d.loadInitValues()
    }

    ModelsComparator {
        id: holdingsModelComparator

        modelA: root.dirtyValues.selectedHoldingsModel
        modelB: root.selectedHoldingsModel

        roles: ["key", "amount"]
        mode: ModelsComparator.CompareMode.Set
    }

    ModelsComparator {
        id: channelsModelComparator

        modelA: root.dirtyValues.selectedChannelsModel
        modelB: root.selectedChannelsModel

        roles: ["key"]
        mode: ModelsComparator.CompareMode.Set
    }

    QtObject {
        id: d

        readonly property int maxHoldingsItems: 5

        readonly property int dropdownHorizontalOffset: 4
        readonly property int dropdownVerticalOffset: 1

        readonly property bool isCommunityPermission:
            PermissionTypes.isCommunityPermission(dirtyValues.permissionType)

        onIsCommunityPermissionChanged: {
            if (isCommunityPermission) {
                d.dirtyValues.selectedChannelsModel.clear()
                inSelector.wholeCommunitySelected = true
                inSelector.model = inModelCommunity
            } else {
                inSelector.model = 0
                inSelector.wholeCommunitySelected = false
                inSelector.model = channelsSelectionModel
            }
        }

        readonly property QtObject dirtyValues: QtObject {
            readonly property ListModel selectedHoldingsModel: ListModel {}
            readonly property ListModel selectedChannelsModel: ListModel {}

            property int permissionType: PermissionTypes.Type.None
            property bool isPrivate: false
            property bool holdingsRequired: true

            Binding on isPrivate {
                value: d.dirtyValues.permissionType === PermissionTypes.Type.Admin
            }

            function getHoldingIndex(key) {
                return ModelUtils.indexOf(selectedHoldingsModel, "key", key)
            }

            function getTokenKeysAndAmounts() {
                return ModelUtils.modelToArray(selectedHoldingsModel, ["type", "key", "amount"])
                    .filter(item => item.type !== Constants.TokenType.ENS)
                    .map(item => ({ key: item.key, amount: item.amount }))
            }

            function getEnsNames() {
                return ModelUtils.modelToArray(selectedHoldingsModel, ["type", "name"])
                    .filter(item => item.type === Constants.TokenType.ENS)
                    .map(item => item.name)
            }
        }

        function loadInitValues() {
            // Holdings:
            d.dirtyValues.selectedHoldingsModel.clear()
            d.dirtyValues.selectedHoldingsModel.append(
                        ModelUtils.modelToArray(root.selectedHoldingsModel,
                                                ["type", "key", "amount"]))

            // Permissions:
            d.dirtyValues.permissionType = root.permissionType

            // Channels
            d.dirtyValues.selectedChannelsModel.clear()
            d.dirtyValues.selectedChannelsModel.append(
                        ModelUtils.modelToArray(root.selectedChannelsModel, ["key"]))

            if (root.selectedChannelsModel &&
                    (root.selectedChannelsModel.rowCount()
                     || d.dirtyValues.permissionType === PermissionTypes.Type.None)) {
                inSelector.wholeCommunitySelected = false
                inSelector.model = channelsSelectionModel
            } else {
                inSelector.wholeCommunitySelected = true
                inSelector.model = inModelCommunity
            }

            // Is private permission
            d.dirtyValues.isPrivate = root.isPrivate

            // Are holdings required
            d.dirtyValues.holdingsRequired = root.holdingsRequired
        }
    }

    onPermissionTypeChanged: Qt.callLater(() => d.loadInitValues())
    contentWidth: root.availableWidth
    contentHeight: sequenceColumnLayout.height

    SequenceColumnLayout {
        id: sequenceColumnLayout

        enabled: !root.saveInProgress
        width: root.availableWidth
        title: qsTr("Anyone")

        StatusItemSelector {
            id: tokensSelector
            objectName: "tokensSelector"

            property int editedIndex: -1

            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            icon: Assets.svg("contact_verified")
            title: qsTr("Who holds")
            placeholderText: qsTr("Example: 10 SNT")
            tagLeftPadding: 2
            asset.height: 28
            asset.width: asset.height
            addButton.visible: count < d.maxHoldingsItems &&
                               whoHoldsSwitch.checked

            model: HoldingsSelectionModel {
                sourceModel: d.dirtyValues.selectedHoldingsModel

                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
            }

            label.enabled: whoHoldsSwitch.checked
            placeholderItem.visible: count === 0 && whoHoldsSwitch.checked

            Binding on model {
                when: !whoHoldsSwitch.checked
                value: 0
                restoreMode: Binding.RestoreBindingOrValue
            }

            Binding on bottomPadding {
                when: !whoHoldsSwitch.checked
                value: 0
                restoreMode: Binding.RestoreBindingOrValue
            }

            children: StatusSwitch {
                id: whoHoldsSwitch

                padding: 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 12
                anchors.topMargin: 10

                checked: d.dirtyValues.holdingsRequired
                onToggled: d.dirtyValues.holdingsRequired = checked
            }

            HoldingsDropdown {
                id: dropdown

                directParent: tokensSelector.addButton

                communityId: root.communityDetails.id

                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
                showTokenAmount: false
                ensCommunityPermissionsEnabled: root.ensCommunityPermissionsEnabled

                function addItem(type, item, amount) {
                    const key = item.key
                    const symbol = item.symbol

                    d.dirtyValues.selectedHoldingsModel.append(
                                { type, key, amount, symbol })
                }

                function prepareUpdateIndex(key) {
                    const itemIndex = tokensSelector.editedIndex
                    const existingIndex = d.dirtyValues.getHoldingIndex(key)

                    if (itemIndex !== -1 && existingIndex !== -1 && itemIndex !== existingIndex) {
                        const previousKey = d.dirtyValues.selectedHoldingsModel.get(itemIndex).key
                        d.dirtyValues.selectedHoldingsModel.remove(existingIndex)
                        return d.dirtyValues.getHoldingIndex(previousKey)
                    }

                    if (itemIndex === -1) {
                        return existingIndex
                    }

                    return itemIndex
                }

                onOpened: {
                    usedTokens = d.dirtyValues.getTokenKeysAndAmounts()
                    usedEnsNames = d.dirtyValues.getEnsNames().filter(item => item !== ensDomainName)
                }

                onAddAsset: function (key, amount) {
                    const modelItem = PermissionsHelpers.getTokenByKey(
                                        root.assetsModel, false, key)

                    addItem(Constants.TokenType.ERC20, modelItem, AmountsArithmetic.fromNumber(amount, modelItem.decimals).toFixed())
                    dropdown.close()
                }

                onAddCollectible: function (key, amount) {
                    const modelItem = PermissionsHelpers.getTokenByKey(
                                        root.collectiblesModel, true, key)

                    addItem(Constants.TokenType.ERC721, modelItem, String(amount))
                    dropdown.close()
                }

                onAddEns: {
                    d.dirtyValues.selectedHoldingsModel.append(
                                { type: Constants.TokenType.ENS, key: domain, amount: "1" })
                    dropdown.close()
                }

                onUpdateAsset: {
                    const itemIndex = prepareUpdateIndex(key)
                    const modelItem = PermissionsHelpers.getTokenByKey(root.assetsModel, false, key)

                    d.dirtyValues.selectedHoldingsModel.set(
                                itemIndex, { type: Constants.TokenType.ERC20, key, amount: AmountsArithmetic.fromNumber(amount, modelItem.decimals).toFixed() })
                    dropdown.close()
                }

                onUpdateCollectible: {
                    const itemIndex = prepareUpdateIndex(key)
                    const modelItem = PermissionsHelpers.getTokenByKey(
                                        root.collectiblesModel, true, key)

                    d.dirtyValues.selectedHoldingsModel.set(
                                itemIndex,
                                { type: Constants.TokenType.ERC721, key, amount: String(amount), symbol: modelItem.symbol })
                    dropdown.close()
                }

                onUpdateEns: {
                    d.dirtyValues.selectedHoldingsModel.set(
                                tokensSelector.editedIndex,
                                { type: Constants.TokenType.ENS, key: domain, amount: "1" })
                    dropdown.close()
                }

                onRemoveClicked: {
                    d.dirtyValues.selectedHoldingsModel.remove(tokensSelector.editedIndex)
                    dropdown.close()
                }

                onNavigateToMintTokenSettings: {
                    root.navigateToMintTokenSettings(isAssetType)
                    close()
                }
            }

            addButton.onClicked: {
                dropdown.directParent = tokensSelector.addButton
                dropdown.relativeX = tokensSelector.addButton.width + d.dropdownHorizontalOffset
                dropdown.open()

                editedIndex = -1
            }

            onItemClicked: function (item, index, mouse) {
                if (mouse.button !== Qt.LeftButton)
                    return

                dropdown.directParent = item
                dropdown.relativeX = mouse.x + d.dropdownHorizontalOffset
                dropdown.relativeY = d.dropdownVerticalOffset

                const modelItem = tokensSelector.model.get(index)

                switch(modelItem.type) {
                    case Constants.TokenType.ERC20:
                        dropdown.assetKey = modelItem.key
                        const decimals = PermissionsHelpers.getTokenByKey(root.assetsModel, false, modelItem.key).decimals
                        dropdown.assetAmount = AmountsArithmetic.toNumber(modelItem.amount, decimals)
                        break
                    case Constants.TokenType.ERC721:
                        dropdown.collectibleKey = modelItem.key
                        dropdown.collectibleAmount = modelItem.amount
                        break
                    case Constants.TokenType.ENS:
                        dropdown.ensDomainName = modelItem.key
                        break
                    default:
                        console.warn("Unsupported holdings type.")
                }

                dropdown.setActiveTab(modelItem.type)
                dropdown.openUpdateFlow()

                editedIndex = index
            }
        }

        SequenceColumnLayoutSeparator {}

        StatusFlowSelector {
            id: permissionsSelector
            objectName: "permissionsSelector"

            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            title: qsTr("Is allowed to")
            placeholderText: qsTr("Example: View and post")
            icon: Assets.svg("profile/security")

            readonly property bool empty:
                d.dirtyValues.permissionType === PermissionTypes.Type.None

            placeholderItem.visible: empty
            addButton.visible: empty

            StatusListItemTag {
                readonly property int key: d.dirtyValues.permissionType

                title: PermissionTypes.getName(key)
                visible: !permissionsSelector.empty

                asset.name: PermissionTypes.getIcon(key)
                asset.bgColor: "transparent"
                closeButtonVisible: false
                titleText.font.pixelSize: Theme.primaryTextFontSize
                leftPadding: 6

                Binding on bgColor {
                    when: root.permissionTypeLimitReached && !root.isEditState
                    value: Theme.palette.dangerColor3
                }

                Binding on titleText.color {
                    when: root.permissionTypeLimitReached && !root.isEditState
                    value: Theme.palette.dangerColor1
                }

                Binding on asset.color {
                    when: root.permissionTypeLimitReached && !root.isEditState
                    value: Theme.palette.dangerColor1
                }

                StatusMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function (mouse) {
                        permissionsDropdown.mode = PermissionsDropdown.Mode.Update
                        permissionsDropdown.directParent = parent
                        permissionsDropdown.relativeX = mouse.x + d.dropdownHorizontalOffset
                        permissionsDropdown.relativeY = d.dropdownVerticalOffset
                        permissionsDropdown.open()
                    }
                }
            }

            PermissionsDropdown {
                id: permissionsDropdown

                directParent: permissionsSelector.addButton

                // Hide community options if we are in the Channel popup or if "Anyone is allowed to" is enabled
                // since making everyone Admin doesn't make sense and anyone can join the community is the default.
                allowCommunityOptions: root.showChannelSelector && d.dirtyValues.holdingsRequired
                initialPermissionType: d.dirtyValues.permissionType
                // Only owners can assign Admin permissions
                enableAdminPermission: root.communityDetails.owner 

                onDone: function(permissionType) {
                    if (d.dirtyValues.permissionType === permissionType) {
                        permissionsDropdown.close()
                        return
                    }

                    d.dirtyValues.permissionType = permissionType
                    permissionsDropdown.close()
                }
            }

            addButton.onClicked: {
                permissionsDropdown.mode = PermissionsDropdown.Mode.Add
                permissionsDropdown.directParent = permissionsSelector.addButton
                permissionsDropdown.relativeX = permissionsSelector.addButton.width
                        + d.dropdownHorizontalOffset
                permissionsDropdown.open()
            }
        }

        SequenceColumnLayoutSeparator { visible: root.showChannelSelector }

        StatusItemSelector {
            id: inSelector

            readonly property bool editable: !d.isCommunityPermission

            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            addButton.visible: editable
            itemsClickable: editable
            visible: root.showChannelSelector
            icon: d.isCommunityPermission ? Assets.svg("communities") : Assets.svg("create-category")
            title: qsTr("In")
            placeholderText: qsTr("Example: `#general` channel")

            useLetterIdenticons: !wholeCommunitySelected || !inDropdown.communityImage

            tagLeftPadding: wholeCommunitySelected ? 2 : 6
            asset.width: wholeCommunitySelected ? 28 : 20
            asset.height: asset.width

            property bool wholeCommunitySelected: false

            function openInDropdown(parent, x, y) {
                inDropdown.directParent = parent
                inDropdown.relativeX = x
                inDropdown.relativeY = y

                const selectedChannels = []

                if (!inSelector.wholeCommunitySelected) {
                    const model = d.dirtyValues.selectedChannelsModel
                    const count = model.count

                    for (let i = 0; i < count; i++)
                        selectedChannels.push(model.get(i).key)
                }

                inDropdown.setSelectedChannels(selectedChannels)
                inDropdown.open()
            }

            ListModel {
                id: inModelCommunity

                Component.onCompleted: {
                    append({
                        imageSource: inDropdown.communityImage,
                        isIcon: false,
                        text: inDropdown.communityName,
                        operator: OperatorsUtils.Operators.None,
                        color: inDropdown.communityColor
                    })
                }
            }

            LeftJoinModel {
                id: channelsSelectionModel

                leftModel: d.dirtyValues.selectedChannelsModel
                rightModel: root.channelsModel
                joinRole: "key"
            }

            InDropdown {
                id: inDropdown

                directParent: inSelector.addButton

                model: root.channelsModel

                communityName: root.communityDetails.name
                communityImage: root.communityDetails.image
                communityColor: root.communityDetails.color

                onChannelsSelected: function (channels) {
                    d.dirtyValues.selectedChannelsModel.clear()
                    inSelector.model = 0
                    inSelector.wholeCommunitySelected = false

                    const modelData = channels.map(key => ({ key }))
                    d.dirtyValues.selectedChannelsModel.append(modelData)

                    inSelector.model = channelsSelectionModel
                    close()
                }

                onCommunitySelected: {
                    d.dirtyValues.selectedChannelsModel.clear()
                    inSelector.wholeCommunitySelected = true
                    inSelector.model = inModelCommunity
                    close()
                }
            }

            addButton.onClicked: {
                inDropdown.acceptMode = InDropdown.AcceptMode.Add
                openInDropdown(inSelector.addButton,
                               inSelector.addButton.width + d.dropdownHorizontalOffset, 0)
            }

            onItemClicked: {
                if (mouse.button !== Qt.LeftButton)
                    return

                inDropdown.acceptMode = InDropdown.AcceptMode.Update
                openInDropdown(item, mouse.x + d.dropdownHorizontalOffset,
                               d.dropdownVerticalOffset)
            }
        }

        Rectangle {
            Layout.topMargin: 24
            Layout.preferredHeight: 1
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            color: Theme.palette.baseColor2
        }

        StatusIconSwitch {
            readonly property int additionalPadding: 16

            Layout.topMargin: 12
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth - 2 * additionalPadding
            Layout.rightMargin: root.internalRightPadding + additionalPadding
            Layout.leftMargin: additionalPadding

            enabled: d.dirtyValues.permissionType !== PermissionTypes.Type.Admin
            checked: d.dirtyValues.isPrivate
            title: qsTr("Hide permission")
            subTitle: qsTr("Make this permission hidden from members who don’t meet its requirements")
            icon: "hide"
            onToggled: d.dirtyValues.isPrivate = checked
        }

        WarningPanel {
            id: duplicationPanel
            objectName: "duplicationPanel"

            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            Layout.topMargin: 50 // by desing

            text: {
                if (root.permissionTypeLimitReached)
                    return PermissionTypes.getPermissionsLimitWarning(
                                d.dirtyValues.permissionType)

                if (root.permissionDuplicated)
                    return qsTr("Permission with same properties is already active, edit properties to create a new permission.")

                return ""
            }

            visible: root.permissionDuplicated || (root.permissionTypeLimitReached && !root.isEditState)
        }

        StatusWarningBox {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            Layout.topMargin: Theme.padding
            visible: root.showChannelSelector
            icon: "desktop"
            text: qsTr("Any changes to community permissions will take effect after the control node receives and processes them")
            borderColor: Theme.palette.baseColor1
            iconColor: textColor
        }

        StatusWarningBox {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            Layout.topMargin: Theme.padding
            visible: root.errorSaving !== ""
            icon: "close-circle"
            text: qsTr("There was an error saving the permission: %1").arg(root.errorSaving)
            borderColor: Theme.palette.baseColor1
            textColor: Theme.palette.dangerColor1
            iconColor: textColor
        }

        StatusButton {
            Layout.preferredHeight: 44
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding
            Layout.topMargin: Theme.bigPadding

            visible: !root.isEditState && root.showChannelSelector
            objectName: "createPermissionButton"
            text: qsTr("Create permission")
            enabled: root.saveEnabled
            loading: root.saveInProgress

            onClicked: root.createPermissionClicked()
        }
    }
}
