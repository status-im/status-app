import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import SortFilterProxyModel

import utils

/**
  * Destination picker step of the share flow: a searchable list of postable
  * destinations, recents first. Takes the model in (recency-sorted postable
  * destinations, see RecentPostableDestinationsAdaptor; roles: chatId, name,
  * color, colorId, icon, emoji, sectionId, sectionName) and emits intent
  * signals out — no store access.
  */
Control {
    id: root

    /* Recency-sorted model of postable destinations */
    required property var model

    signal destinationPicked(string sectionId, string chatId, string name)
    signal cancelRequested()

    QtObject {
        id: d

        readonly property string searchPhrase: searchBox.text
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        RowLayout {
            Layout.fillWidth: true

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Share to")
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StatusFlatRoundButton {
                objectName: "shareDestinationPickerCancelButton"
                icon.name: "close"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.cancelRequested()
            }
        }

        StatusInput {
            id: searchBox
            objectName: "shareDestinationPickerSearchBox"

            Layout.fillWidth: true
            placeholderText: qsTr("Search chats and channels")
            input.asset.name: "search"
        }

        StatusListView {
            id: listView
            objectName: "shareDestinationPickerListView"

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: SortFilterProxyModel {
                sourceModel: root.model

                filters: AnyOf {
                    SearchFilter {
                        roleName: "name"
                        searchPhrase: d.searchPhrase
                    }
                    SearchFilter {
                        roleName: "sectionName"
                        searchPhrase: d.searchPhrase
                    }
                    enabled: !!d.searchPhrase
                }
            }

            delegate: StatusListItem {
                objectName: "shareDestinationDelegate_" + model.name
                width: ListView.view.width
                title: model.name
                label: model.sectionName
                statusListItemIcon {
                    name: model.name
                    active: true
                }
                asset.width: 30
                asset.height: 30
                asset.color: model.color ? model.color
                                         : Utils.colorForColorId(Theme.palette, model.colorId)
                asset.name: model.icon
                asset.emoji: model.emoji
                asset.charactersLen: 2
                asset.letterSize: asset._twoLettersSize
                onClicked: root.destinationPicked(model.sectionId, model.chatId, model.name)
            }

            StatusBaseText {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: qsTr("No destinations found")
                color: Theme.palette.baseColor1
            }
        }
    }
}
