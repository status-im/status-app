import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel
import utils

StatusDropdown {
    id: root

    implicitWidth: 400
    implicitHeight: 300

    required property var model
    property var threadModel: null

    property string searchBoxPlaceholder: qsTr("Search...")

    readonly property string searchPhrase: searchBox.text.trim()

    signal selected(string sectionId, string chatId, string threadId)

    ColumnLayout {
        anchors.fill: parent

        StatusInput {
            id: searchBox
            objectName: "switcherSearchBox"

            Layout.fillWidth: true
            placeholderText: root.searchBoxPlaceholder
            input.asset.name: "search"

            onKeyPressed: function(event) {
                listView.selectByHover = false

                if (event.key === Qt.Key_Down) {
                    listView.incrementCurrentIndex()
                } else if (event.key === Qt.Key_Up) {
                    listView.decrementCurrentIndex()
                } else if (event.key === Qt.Key_Escape) {
                    root.close()
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    if (listView.currentIndex >= 0 && listView.currentIndex < listView.count)
                        listView.currentItem?.selectThisItem()
                }
            }

            onTextChanged: if (text === "") listView.currentIndex = 0
        }

        StatusListView {
            id: listView
            objectName: "switcherResults"

            Layout.fillWidth: true
            Layout.fillHeight: true

            property bool selectByHover: false

            highlightMoveDuration: 200
            highlightFollowsCurrentItem: true
            keyNavigationWraps: true

            model: SortFilterProxyModel {
                sourceModel: ConcatModel {
                    expectedRoles: ["chatId", "sectionId", "name", "sectionName", "icon", "color",
                                    "colorId", "emoji", "threadId", "archived", "parentChatName"]
                    markerRoleName: ""
                    sources: [
                        SourceModel { model: root.model },
                        SourceModel { model: root.threadModel }
                    ]
                }

                filters: [
                    ValueFilter {
                        roleName: "archived"
                        value: true
                        inverted: true
                        enabled: !root.searchPhrase
                    },
                    AnyOf {
                        enabled: !!root.searchPhrase

                        SearchFilter {
                            roleName: "name"
                            searchPhrase: root.searchPhrase
                        }
                        AllOf {
                            ValueFilter { roleName: "threadId"; value: "" }
                            SearchFilter {
                                roleName: "sectionName"
                                searchPhrase: root.searchPhrase
                            }
                        }
                    }
                ]
                sorters: StringSorter {
                    roleName: "name"
                }
            }

            delegate: StatusListItem {
                id: listItem

                function selectThisItem() {
                    root.selected(model.sectionId, model.chatId, model.threadId)
                }

                title: model ? model.name : ""
                label: model ? (model.threadId ? model.parentChatName + " · " + model.sectionName
                                               : model.sectionName) : ""
                highlighted: ListView.isCurrentItem
                width: ListView.view.width
                sensor.hoverEnabled: false
                statusListItemIcon {
                    name: model ? model.name : ""
                    active: true
                }
                asset.width: 30
                asset.height: 30
                asset.color: model ? model.color ? model.color : Utils.colorForColorId(Theme.palette, model.colorId) : ""
                asset.name: model ? model.icon : ""
                asset.emoji: model ? model.emoji : ""
                asset.charactersLen: 2
                asset.letterSize: asset._twoLettersSize

                StatusMouseArea {
                    anchors.fill: parent

                    hoverEnabled: true
                    onClicked: (mouse) => {
                                listView.currentIndex = index
                                listItem.selectThisItem()
                                mouse.accepted = false
                            }
                    onContainsMouseChanged: if (containsMouse) listView.currentIndex = index
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Loader {
                anchors.fill: parent
                active: !listView.selectByHover

                sourceComponent: StatusMouseArea {
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onPositionChanged: listView.selectByHover = true
                }
            }
        }
    }

    onAboutToShow: {
        listView.currentIndex = 0
        listView.selectByHover = false
        searchBox.text = ""
        if (Utils.isMobile)
            return
        searchBox.input.edit.forceActiveFocus()
    }
}
