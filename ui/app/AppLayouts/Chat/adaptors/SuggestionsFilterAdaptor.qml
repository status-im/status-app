import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

// Adaptor adding special entry "everyone" to list of users, providing filtering
// by preferredDisplayName role and sorting by the same role.
QObject {
    id: root

    // input model
    required property var sourceModel

    // name used for filtering
    property string filter: ""

    // output model
    readonly property alias model: filteredModel

    SortFilterProxyModel {
        id: filteredModel

        sourceModel: concatModel

        filters: SearchFilter {
            roleName: "preferredDisplayName"
            searchPhrase: root.filter
        }
        sorters: StringSorter {
            roleName: "preferredDisplayName"
            caseSensitivity: Qt.CaseInsensitive
        }
    }

    ConcatModel {
        id: concatModel

        sources: [
            SourceModel {
                model: root.sourceModel
                markerRoleValue: "filtered_model"
            },
            SourceModel {
                model: ListModel {
                    ListElement {
                        pubKey: "0x00001"
                        preferredDisplayName: "everyone"
                        icon: ""
                        colorId: 0
                        usesDefaultName: false
                    }
                }
                markerRoleValue: "everyone_model"
            }
        ]
        markerRoleName: "which_model"
        expectedRoles: ["pubKey", "preferredDisplayName"]
    }
}
