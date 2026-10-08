import QtQuick

import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

// Filters users by preferredDisplayName, optionally keeping "everyone" first
// and sorting the remaining suggestions by name.
QObject {
    id: root

    // input model
    required property var sourceModel
    property bool usersModelIncludeAtEveryone: true

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
        sorters: [
            StringSorter {
                roleName: "which_model"
            },
            StringSorter {
                roleName: "preferredDisplayName"
                caseSensitivity: Qt.CaseInsensitive
            }
        ]
    }

    ListModel {
        id: everyoneModel
        ListElement {
            pubKey: "0x00001"
            preferredDisplayName: "everyone"
            icon: ""
            colorId: 0
            usesDefaultName: false
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
                model: root.usersModelIncludeAtEveryone ? everyoneModel : null
                markerRoleValue: "everyone_model"
            }
        ]
        markerRoleName: "which_model"
        expectedRoles: ["pubKey", "preferredDisplayName"]
    }
}
