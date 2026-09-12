import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

import utils

StatusListView {
    id: root

    required property var selectedSharedAddressesMap // Map[address, [selected, isAirdrop]]

    property var walletAssetsModel
    property bool hasPermissions

    property var uniquePermissionAssetsKeys
    property var uniquePermissionCollectiblesKeys

    property var walletCollectiblesModel
    property var communityCollectiblesModel
    property string communityId

    property var getCurrencyAmount: function (balance, key){}

    signal toggleAddressSelection(string keyUid, string address)
    signal airdropAddressSelected (string address)

    leftMargin: d.absLeftMargin
    topMargin: Theme.padding
    rightMargin: Theme.padding
    bottomMargin: Theme.padding


    ModelChangeTracker {
        id: communityCollectiblesModelTracker

        model: communityCollectiblesModel

        onRevisionChanged: {
            const collectibles = ModelUtils.modelToArray(
                                   communityCollectiblesModel,
                                   ["key", "name", "symbol", "icon", "communityId"])
                .filter(e => e.communityId === communityId)

            const keysToNames = {}

            for (const c of collectibles)
                keysToNames[c.key] = {
                    name: c.name,
                    symbol: c.symbol,
                    icon: c.icon
                }

            d.collectiblesMetadata
                    = uniquePermissionCollectiblesKeys.map(k => keysToNames[k])
            d.collectiblesNames = d.collectiblesMetadata.map(c => c.name)

            const namesToSymbols = {}
            d.collectiblesMetadata.forEach(c => namesToSymbols[c.name] = c.symbol)
            d.collectiblesNamesToSymbols = namesToSymbols

            const namesToImages = {}
            d.collectiblesMetadata.forEach(c => namesToImages[c.name] = c.icon)
            d.collectiblesNamesToImages = namesToImages
        }

        Component.onCompleted: revisionChanged()
    }

    ModelChangeTracker {
        id: filteredWalletCollectiblesTracker

        model: filteredWalletCollectibles
    }

    QtObject {
        id: d

        property var collectiblesMetadata: []
        property var collectiblesNames: []
        property var collectiblesNamesToSymbols: ({})
        property var collectiblesNamesToImages: ({})

        readonly property int selectedSharedAddressesCount: root.selectedSharedAddressesMap.size

        // UI
        readonly property int absLeftMargin: 12

        readonly property ButtonGroup airdropGroup: ButtonGroup {
            exclusive: true
        }

        readonly property ButtonGroup addressesGroup: ButtonGroup {
            exclusive: false
        }

        function getTotalBalance(balances, decimals) {
            let totalBalance = 0
            for(let i = 0; i < balances.count; i++) {
                let balancePerAddressPerChain = ModelUtils.get(balances, i)
                totalBalance += AmountsArithmetic.toNumber(balancePerAddressPerChain.balance, decimals)
            }
            return totalBalance
        }
    }

    SortFilterProxyModel {
        id: filteredWalletCollectibles

        sourceModel: walletCollectiblesModel

        filters: [
            ValueFilter {
                roleName: "communityId"
                value: root.communityId
            },
            FastExpressionFilter {
                expression: d.collectiblesNames.includes(model.name)
                expectedRoles: ["name"]
            }
        ]
    }

    ListModel {
        id: walletAccountCollectiblesModel

        readonly property var data: {
            filteredWalletCollectiblesTracker.revision
            const usedCollectibles = ModelUtils.modelToArray(filteredWalletCollectibles)

            const collectiblesGroupingMap = {}

            for (const c of usedCollectibles) {
                const key = `${c.name}_${c.ownership[0].accountAddress}`

                if (!collectiblesGroupingMap[key])
                    collectiblesGroupingMap[key] = []

                collectiblesGroupingMap[key].push(c)
            }

            const collectiblesGrouped = Object.values(collectiblesGroupingMap).map(e => {
                const firstEntry = e[0]

                return {
                    symbol: d.collectiblesNamesToSymbols[firstEntry.name] || "",
                    enabledNetworkBalance: e.length,
                    account: firstEntry.ownership[0].accountAddress,
                    imageUrl: d.collectiblesNamesToImages[firstEntry.name] || ""
                }
            })

            return collectiblesGrouped
        }

        onDataChanged: {
            clear()
            append(data)
        }
    }

    spacing: Theme.halfPadding
    delegate: StatusListItem {
        readonly property string address: model.address.toLowerCase()
        readonly property int tokenCount: tagsCount

        id: listItem
        width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
        statusListItemTitle.font.weight: Font.Medium
        title: model.name
        tertiaryTitle: root.hasPermissions && !tagsCount ? qsTr("No relevant tokens") : ""

        ObjectProxyModel {
            id: filteredBalances

            sourceModel: root.walletAssetsModel

            delegate: SortFilterProxyModel {
                readonly property SortFilterProxyModel balances: this

                sourceModel: model.balances
                filters: RegExpFilter {
                    roleName: "account"
                    pattern: listItem.address
                    syntax: RegExpFilter.FixedString
                    caseSensitivity: Qt.CaseInsensitive
                }
            }

            expectedRoles: "balances"
            exposedRoles: "balances"
        }

        SortFilterProxyModel {
            id: accountCollectiblesModel

            sourceModel: walletAccountCollectiblesModel

            filters: RegExpFilter {
                roleName: "account"
                pattern: listItem.address
                syntax: RegExpFilter.FixedString
                caseSensitivity: Qt.CaseInsensitive
            }
        }

        ConcatModel {
            id: concatModel

            markerRoleName: "type"

            sources: [
                SourceModel {
                    model: walletAccountAssetsModel
                    markerRoleValue: Constants.TokenType.ERC20
                },
                SourceModel {
                    model: accountCollectiblesModel
                    markerRoleValue: Constants.TokenType.ERC721
                }
            ]
        }

        tagsModel: SortFilterProxyModel {
            sourceModel: concatModel

            filters: ValueFilter {
                roleName: "enabledNetworkBalance"
                value: 0
                inverted: true
            }

            sorters: [
                RoleSorter {
                    roleName: "symbol"
                }
            ]
        }

        SortFilterProxyModel {
            id: walletAccountAssetsModel

            sourceModel: filteredBalances

            function filterPredicate(groupKey) {
                return root.uniquePermissionAssetsKeys.includes(groupKey)
            }

            proxyRoles: [
                FastExpressionRole {
                    name: "enabledNetworkBalance"
                    expression: d.getTotalBalance(model.balances, model.decimals)
                    expectedRoles: ["balances", "decimals"]
                },
                FastExpressionRole {
                    name: "imageUrl"

                    function getIcon(symbol) {
                        return Constants.tokenIcon(symbol.toUpperCase())
                    }

                    // Singletons cannot be used directly in sfpm's expressions
                    expression: getIcon(model.symbol)
                    expectedRoles: ["symbol"]
                }
            ]

            filters: FastExpressionFilter {
                expression: walletAccountAssetsModel.filterPredicate(model.groupKey)
                expectedRoles: ["groupKey"]
            }
        }

        tagsSpacing: Theme.padding

        tagsDelegate: Row {
            spacing: 4
            StatusRoundedImage {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                image.source: model.imageUrl
            }
            StatusBaseText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.tertiaryTextFontSize

                readonly property int type: model.type

                text: {
                    if (type === Constants.TokenType.ERC20)
                        return LocaleUtils.currencyAmountToLocaleString(
                                    root.getCurrencyAmount(model.enabledNetworkBalance,
                                                           model.tokenKey))

                    return LocaleUtils.numberToLocaleString(model.enabledNetworkBalance)
                            + " " + model.symbol
                }
            }
        }

        asset.color: !!model.color ? model.color : ""
        asset.emoji: model.emoji
        asset.name: !model.emoji ? "filled-account": ""
        asset.letterSize: 14
        asset.isLetterIdenticon: !!model.emoji
        asset.isImage: asset.isLetterIdenticon

        components: [
            StatusFlatButton {
                ButtonGroup.group: d.airdropGroup
                anchors.verticalCenter: parent.verticalCenter
                icon.name: "airdrop"
                icon.color: checked ? Theme.palette.primaryColor1 : disabledTextColor
                checkable: true
                checked: {
                    const obj = root.selectedSharedAddressesMap.get(listItem.address)
                    if (!!obj) {
                        return obj.isAirdrop
                    }
                    return false
                }
                enabled: shareAddressCheckbox.checked && d.selectedSharedAddressesCount > 1 // last cannot be unchecked
                visible: shareAddressCheckbox.checked
                opacity: enabled ? 1.0 : 0.3

                onToggled: root.airdropAddressSelected(listItem.address)

                StatusToolTip {
                    text: qsTr("Use this address for any Community airdrops")
                    visible: parent.hovered
                    delay: 500
                }
            },
            StatusCheckBox {
                id: shareAddressCheckbox

                ButtonGroup.group: d.addressesGroup
                anchors.verticalCenter: parent.verticalCenter
                checkable: true
                checked: root.selectedSharedAddressesMap.has(listItem.address)
                enabled: !(d.selectedSharedAddressesCount === 1 && checked) // last cannot be unchecked

                onToggled: root.toggleAddressSelection(model.keyUid, listItem.address)
            }
        ]
    }
}
