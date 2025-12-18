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

StatusDropdown {
    id: root

    implicitWidth: 400
    implicitHeight: 300

    required property var model

    property string searchBoxPlaceholder: qsTr("Search...")

    signal selected(string sectionId, string chatId)

    ColumnLayout {
        anchors.fill: parent

        // workaround for QTBUG-142248
        Theme.style: root.Theme.style
        Theme.padding: root.Theme.padding
        Theme.fontSizeOffset: root.Theme.fontSizeOffset

        StatusInput {
            id: searchBox

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
                    listView.currentItem.selectThisItem()
                }
            }

            onTextChanged: if (text === "") listView.currentIndex = 0
        }

        StatusListView {
            id: listView

            Layout.fillWidth: true
            Layout.fillHeight: true

            property bool selectByHover: false

            highlightMoveDuration: 200
            highlightFollowsCurrentItem: true
            keyNavigationWraps: true

            model: SortFilterProxyModel {
                sourceModel: root.model

                filters: AnyOf {
                    SearchFilter {
                        roleName: "sectionName"
                        searchPhrase: searchBox.text
                    }
                    SearchFilter {
                        roleName: "name"
                        searchPhrase: searchBox.text
                    }
                    enabled: !!searchBox.text
                }
                sorters: StringSorter {
                    roleName: "name"
                }
            }

            delegate: StatusListItem {
                id: listItem

                function selectThisItem() {
                    root.selected(model.sectionId, model.chatId)
                }

                title: model ? model.name : ""
                label: model? model.sectionName : ""
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
