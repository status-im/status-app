import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import SortFilterProxyModel

/**
  * One tab of the share picker: the recency-ranked destinations narrowed by
  * chat type, by the share selection (Selected tab) and by the search
  * phrase. Reads the selection to render ticks; emits toggleRequested for
  * the host to mutate it.
  */
Control {
    id: root

    required property var model
    required property ShareSelection selection

    property int chatTypeFilter: -1
    property bool selectedOnly: false
    property string searchPhrase: ""
    property string emptyText: qsTr("No destinations found")

    readonly property alias count: listView.count

    signal toggleRequested(string chatId)

    QtObject {
        id: d

        // Channel names are searched without their leading "#".
        readonly property string effectiveSearchPhrase: root.searchPhrase.startsWith("#")
            ? root.searchPhrase.substring(1) : root.searchPhrase
    }

    padding: Theme.halfPadding

    contentItem: StatusListView {
        id: listView
        objectName: "shareDestinationListView"

        clip: true
        spacing: Theme.halfPadding

        model: SortFilterProxyModel {
            sourceModel: root.model

            filters: [
                ValueFilter {
                    roleName: "chatType"
                    value: root.chatTypeFilter
                    enabled: root.chatTypeFilter !== -1
                },
                ExpressionFilter {
                    enabled: root.selectedOnly
                    expression: !!root.selection && root.selection.chatIds.indexOf(model.chatId) !== -1
                },
                AnyOf {
                    enabled: !!root.searchPhrase
                    SearchFilter { roleName: "name"; searchPhrase: d.effectiveSearchPhrase }
                    SearchFilter { roleName: "sectionName"; searchPhrase: d.effectiveSearchPhrase }
                }
            ]
        }

        delegate: ShareDestinationDelegate {
            objectName: "shareDestinationDelegate_" + chatId
            width: ListView.view.width
            checked: !!root.selection && root.selection.chatIds.indexOf(chatId) !== -1
            selectable: !root.selection || !root.selection.isFull
            onToggled: chatId => root.toggleRequested(chatId)
        }

        StatusBaseText {
            objectName: "shareDestinationListEmptyText"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.padding * 2
            visible: listView.count === 0
            text: root.selectedOnly && (!root.selection || root.selection.count === 0)
                  ? qsTr("Nothing selected yet") : root.emptyText
            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.baseColor1
        }
    }
}
