import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Popups

import AppLayouts.Communities.controls
import shared.controls

import QtModelsToolkit
import SortFilterProxyModel

StatusDropdown {
    id: root

    width: 289
    padding: 8
    fillHeightOnBottomSheet: true

    // force keeping within the bounds of the enclosing window
    margins: 0

    property bool allowChoosingEntireCommunity: false
    property bool showAddChannelButton: false

    property string communityName
    property string communityImage
    property string communityColor

    property var model

    property int acceptMode: InDropdown.AcceptMode.Add

    enum AcceptMode {
        Add, Update
    }

    signal addChannelClicked
    signal communitySelected
    signal channelsSelected(var channels)

    function setSelectedChannels(channels) {
        d.selectedChannels.clear()
        channels.forEach(c => d.selectedChannels.add(c))
        d.selectedChannelsChanged()
    }

    onAboutToHide: {
        searcher.text = ""
        listView.positionViewAtBeginning()
    }

    onAboutToShow: {
        searcher.forceActiveFocus()
        listView.Layout.preferredHeight = Math.min(
                       listView.implicitHeight, 420)
    }

    // only channels (no entries representing categories), sorted according to
    // category position and position
    SortFilterProxyModel {
        id: onlyChannelsModel

        sourceModel: root.model

        filters: ValueFilter {
            roleName: "isCategory"
            value: false
        }

        sorters: [
            RoleSorter {
                roleName: "categoryPosition"
                priority: 2 // Higher number -> higher priority
            },
            RoleSorter {
                roleName: "position"
                priority: 1
            }
        ]
    }

    // only items representing categories
    SortFilterProxyModel {
        id: categoriesModel

        sourceModel: root.model

        filters: ValueFilter {
            roleName: "isCategory"
            value: true
        }
    }

    // categories, name role renamed to categoryName
    RolesRenamingModel {
        id: categoriesModelRenamed

        sourceModel: categoriesModel

        mapping: RoleRename {
            from: "name"
            to: "categoryName"
        }
    }

    // categories joined to channels model in order to provide channelName,
    // in order to be used in section.property.
    LeftJoinModel {
        id: joined

        leftModel: onlyChannelsModel
        rightModel: categoriesModelRenamed

        joinRole: "categoryId"
        rolesToJoin: "categoryName"
    }

    // final filtering based on user's input in search bar
    SortFilterProxyModel {
        id: filtered

        sourceModel: joined

        filters: SearchFilter {
            roleName: "name"
            searchPhrase: searcher.text
        }
    }

    QtObject {
        id: d

        readonly property int defaultVMargin: 9
        readonly property int maxHeightCountNo: 5
        readonly property int itemStandardHeight: 44
        readonly property var selectedChannels: new Set()

        function resolveEmoji(emoji) {
            return !!emoji ? emoji : ""
        }

        function resolveColor(color, colorId) {
            return !!color ? color : root.Theme.palette.userCustomizationColors[colorId]
        }
    }

   contentItem: ColumnLayout {
        spacing: 0

        SearchBox {
            id: searcher

            Layout.fillWidth: true
            Layout.preferredHeight: 36
        }

        StatusListItem {
            Layout.fillWidth: true
            Layout.topMargin: d.defaultVMargin
            Layout.preferredHeight: d.itemStandardHeight

            visible: root.allowChoosingEntireCommunity
            title: root.communityName
            subTitle: qsTr("Community")

            asset.name:  root.communityImage
            asset.color: root.communityColor
            asset.isImage: true
            asset.width: 32
            asset.height: 32
            asset.isLetterIdenticon: !asset.name
            asset.charactersLen: 2
            asset.letterSize: 15

            leftPadding: 8
            rightPadding: 6

            statusListItemTitleArea.anchors.leftMargin: 8
            statusListItemTitle.font.pixelSize: Theme.additionalTextSize
            statusListItemTitle.font.weight: Font.Medium

            statusListItemSubTitle.font.pixelSize: Theme.tertiaryTextFontSize

            components: [
                StatusRadioButton {
                    id: radioButton

                    size: StatusRadioButton.Size.Small
                    rightPadding: 0
                }
            ]

            // using StatusMouseArea instead of build-in 'clicked' signal to avoid
            // intercepting event by the StatusRadioButton
            StatusMouseArea {
                anchors.fill: parent
                onClicked: {
                    radioButton.toggle()
                    radioButton.toggled()
                }
                cursorShape: Qt.PointingHandCursor
            }
        }

        StatusMenuSeparator {
            Layout.fillWidth: true
            Layout.topMargin: 4 - implicitHeight / 2
            Layout.bottomMargin: 4 - implicitHeight / 2

            visible: root.allowChoosingEntireCommunity
        }

        StatusListView {
            id: listView

            model: filtered

            Layout.fillWidth: true
            Layout.minimumHeight: Math.min(d.maxHeightCountNo * d.itemStandardHeight,
                                           contentHeight)
            Layout.fillHeight: true
            Layout.bottomMargin: d.defaultVMargin
            Layout.topMargin: !root.allowChoosingEntireCommunity
                              && !root.allowChoosingEntireCommunity ? d.defaultVMargin : 0

            Component {
                id: addChannelButtonComponent

                StatusIconTextButton {
                    height: 36
                    leftPadding: 8
                    spacing: 8
                    statusIcon: "add"
                    icon.width: 16
                    icon.height: 16
                    iconRotation: 0
                    text: qsTr("Add channel")
                    onClicked: root.addChannelClicked()
                }
            }

            header: root.showAddChannelButton ? addChannelButtonComponent : null

            section.delegate: CategoryListItem {
                title: section

                width: ListView.view.width

                StatusMouseArea {
                    anchors.fill: parent

                    onClicked: {
                        const categoryId = ModelUtils.getByKey(
                                             categoriesModel, "name", section, "categoryId")
                        const allKeys = ModelUtils.modelToArray(
                                          filtered, ["itemId", "categoryId"])
                        const inCategoryKeys = allKeys.filter(
                                                 e => e.categoryId === categoryId)
                        const allSelected = inCategoryKeys.every(
                                              e => d.selectedChannels.has(e.itemId))

                        if (allSelected)
                            inCategoryKeys.forEach(
                                        e => d.selectedChannels.delete(e.itemId))
                        else
                            inCategoryKeys.forEach(
                                        e => d.selectedChannels.add(e.itemId))

                        d.selectedChannelsChanged()
                    }
                }
            }

            section.property: "categoryName"

            delegate: CommunityListItem {
                id: communitySubItem

                objectName: "communityListItem_" + model.name

                width: ListView.view.width
                visible: show

                title: "#" + model.name

                asset.name: model.icon ?? ""
                asset.emoji: d.resolveEmoji(model.emoji)
                asset.color: d.resolveColor(model.color, model.colorId)

                checked: d.selectedChannels.has(model.itemId)

                checkBox.onToggled: {
                    if (checked)
                        d.selectedChannels.add(model.itemId)
                    else
                        d.selectedChannels.delete(model.itemId)

                    d.selectedChannelsChanged()
                }
            }
        }

        StatusButton {
            Layout.fillWidth: true

            enabled: root.acceptMode === InDropdown.AcceptMode.Update
                     || d.selectedChannels.size > 0

            text: {
                if (root.acceptMode === InDropdown.AcceptMode.Update)
                    return qsTr("Update")

                if (radioButton.checked)
                    return qsTr("Add community")

                if (d.selectedChannels.size === 0)
                    return qsTr("Add")

                return qsTr("Add %n channel(s)", "", d.selectedChannels.size)
            }


            onClicked: {
                if (radioButton.checked) {
                    root.communitySelected()
                    return
                }

                root.channelsSelected(Array.from(d.selectedChannels.values()))
            }
        }

   }
}
