import SortFilterProxyModel

import StatusQ
import StatusQ.Core.Utils

import utils

SortFilterProxyModel {
    id: root

    // Excludes threads; channel/category inputs must expose a boolean isThread role.
    filters: ValueFilter {
        roleName: "isThread"
        value: false
    }

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
