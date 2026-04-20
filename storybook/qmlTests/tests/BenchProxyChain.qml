// Stripped clone of ui/imports/shared/views/AssetsViewAdaptor.qml's proxy
// stack.  Uses ONLY the roles both the OLD and NEW grouped_account_assets
// models expose: `key` (parent) and the nested `balances` model with
// `account`, `chainId`, `balance` roles.
//
// Mirrors the real chain's SHAPE (ObjectProxyModel + nested
// SortFilterProxyModel + FunctionAggregator + outer SortFilterProxyModel)
// so the benchmark exercises the same proxy reaction path that real wallet
// updates take.

import QtQuick
import QtModelsToolkit
import SortFilterProxyModel
import StatusQ
import StatusQ.Core.Utils

Item {
    id: root

    // Inputs
    required property var sourceModel
    property var chains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]   // accept any chainId
    property var accounts: ["0xacct0", "0xacct1", "0xacct2", "0xacct3", "0xacct4",
                            "0xacct5", "0xacct6", "0xacct7", "0xacct8", "0xacct9",
                            "0xacct10", "0xacct11", "0xacct12", "0xacct13", "0xacct14",
                            "0xacct15", "0xacct16", "0xacct17", "0xacct18", "0xacct19"]

    // Output (filtered by visible)
    readonly property alias outputModel: sfpm

    // Sanity helper - QML asserts use this to make sure the chain reflects
    // the source model.  Returns the count after filtering.
    function expectedCount() {
        return sfpm.count
    }

    ObjectProxyModel {
        id: proxyModel
        sourceModel: root.sourceModel ?? null

        delegate: QObject {
            readonly property var rootModel: model
            readonly property string itemKey: model.key

            SortFilterProxyModel {
                id: filteredBalances
                sourceModel: rootModel.balances

                filters: [
                    OneOfFilter {
                        roleName: "chainId"
                        array: root.chains
                    },
                    OneOfFilter {
                        roleName: "account"
                        array: root.accounts
                    }
                ]
            }

            FunctionAggregator {
                id: totalBalanceAggregator
                model: filteredBalances
                initialValue: 0
                roleName: "balance"
                aggregateFunction: (aggr, value) => aggr + Number(value)
            }

            readonly property real totalBalance: totalBalanceAggregator.value
            readonly property bool visible: totalBalance > 0
        }

        expectedRoles: ["key", "balances"]
        exposedRoles: ["itemKey", "totalBalance", "visible"]
    }

    SortFilterProxyModel {
        id: sfpm
        sourceModel: proxyModel
        filters: ValueFilter {
            roleName: "visible"
            value: true
        }
    }
}
