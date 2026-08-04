import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.views
import utils

import QtModelsToolkit
import SortFilterProxyModel

/**
  Panel holding search field and two-levels list of collectibles.
*/
Control {
    id: root

    /**
      Expected model structure:

        groupName           [string] - group name
        icon                [url]    - icon image of a group
        type                [string] - group type, can be "community" or "other"
        subitems            [model]  - submodel of collectibles/collections of the group
            key             [string] - balance
            name            [string] - name of the subitem
            balance         [int]    - balance of the subitem
            icon            [url]    - icon of the subitem
    **/
    property alias model: sfpm.sourceModel

    signal collectionSelected(string key)
    signal collectibleSelected(string key)

    property string highlightedKey: ""

    readonly property alias currentItem: collectiblesStackView.currentItem

    function clearSearch() {
        collectiblesSearchBox.text = ""
    }

    SortFilterProxyModel {
        id: sfpm

        filters: SearchFilter {
            roleName: "groupName"
            searchPhrase: collectiblesSearchBox.text
        }
    }

    contentItem: StackView {
        id: collectiblesStackView

        implicitHeight: currentItem.implicitHeight

        initialItem: ColumnLayout {
            spacing: 0

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 4
                text: qsTr("Your collectibles will appear here")
                color: Theme.palette.baseColor1
                visible: !collectiblesListView.count && !collectiblesSearchBox.text
            }

            TokenSearchBox {
                id: collectiblesSearchBox

                objectName: "collectiblesSearchBox"

                Layout.fillWidth: true
                placeholderText: qsTr("Search collectibles")

                visible: collectiblesListView.count || !!collectiblesSearchBox.text

                Keys.forwardTo: [collectiblesListView]
            }

            StatusDialogDivider {
                Layout.fillWidth: true
                visible: collectiblesListView.count
            }

            StatusListView {
                id: collectiblesListView

                readonly property bool validSearchResultExists: !!collectiblesSearchBox.text && sfpm.count > 0

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                spacing: 4

                clip: true
                model: sfpm

                delegate: TokenSelectorCollectibleDelegate {
                    required property var model

                    readonly property int subitemsCount:
                        model.subitems.ModelCount.count

                    readonly property bool isCommunity:
                        model.type === "community"

                    readonly property bool showCount:
                        subitemsCount > 1 || isCommunity

                    name: model.groupName
                    balance: showCount ? subitemsCount : ""
                    image: Utils.collectibleThumbnailSource(model.thumbnailUrl,
                                                           model.imageUrl)
                    goDeeperIconVisible: subitemsCount > 1
                                         || isCommunity
                    networkIcon: model.iconUrl
                    highlighted: subitemsCount === 1 && !isCommunity
                                 ? ModelUtils.get(model.subitems, 0, "key")
                                   === root.highlightedKey
                                 : false
                    isAutoHovered: collectiblesListView.validSearchResultExists && model.index === 0 && !collectiblesListViewHoverHandler.hovered

                    onClicked: {
                        if (subitemsCount === 1 && !isCommunity) {
                            const key = ModelUtils.get(model.subitems, 0, "key")
                            root.collectibleSelected(key)
                            return
                        }

                        const parameters = {
                            index: sfpm.index(model.index, 0),
                            model: model.subitems,
                            isCommunity: isCommunity
                        }

                        collectiblesStackView.push(
                                    collectiblesSublistComponent,
                                    parameters,
                                    StackView.Immediate)
                    }
                }

                section.property: "type"

                section.delegate: TokenSelectorSectionDelegate {
                    width: ListView.view.width
                    text: section === "community"
                          ? qsTr("Community minted")
                          : qsTr("Other")
                }

                Keys.onReturnPressed: {
                    if(validSearchResultExists)
                        collectiblesListView.itemAtIndex(0).clicked()
                }

                Keys.onEnterPressed: {
                    if(validSearchResultExists)
                        collectiblesListView.itemAtIndex(0).clicked()
                }

                HoverHandler {
                    id: collectiblesListViewHoverHandler
                }
            }
        }
    }

    Component {
        id: collectiblesSublistComponent

        ColumnLayout {
            property var index
            property alias model: sublistSfpm.sourceModel
            property bool isCommunity

            spacing: 0

            SortFilterProxyModel {
                id: sublistSfpm

                filters: SearchFilter {
                    roleName: "name"
                    searchPhrase: collectiblesSublistSearchBox.text
                }
            }

            StatusIconTextButton {
                id: backButton

                statusIcon: "previous"
                icon.width: 12
                icon.height: 12
                text: qsTr("Back")

                horizontalPadding: 21
                bottomPadding: Theme.halfPadding

                onClicked: collectiblesStackView.pop(StackView.Immediate)
            }

            StatusDialogDivider {
                Layout.fillWidth: true
                visible: collectiblesListView.count
            }

            TokenSearchBox {
                id: collectiblesSublistSearchBox

                Layout.fillWidth: true
                placeholderText: qsTr("Search collectibles")

                Keys.forwardTo: [sublist]
            }

            StatusDialogDivider {
                Layout.fillWidth: true
                visible: collectiblesListView.count
            }

            StatusListView {
                id: sublist

                readonly property bool validSearchResultExists: !!collectiblesSublistSearchBox.text && sublistSfpm.count > 0

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                model: sublistSfpm

                clip: true

                delegate: TokenSelectorCollectibleDelegate {
                    required property var model

                    name: model.name
                    balance: model.balance > 1 ? model.balance : ""
                    image: model.icon
                    goDeeperIconVisible: false
                    networkIcon: model.iconUrl
                    highlighted: model.key === root.highlightedKey
                    isAutoHovered: sublist.validSearchResultExists && model.index === 0 && !sublistHoverHandler.hovered

                    onClicked: {
                        if (isCommunity)
                            root.collectionSelected(model.key)
                        else
                            root.collectibleSelected(model.key)
                    }
                }

                Keys.onReturnPressed: {
                    if(validSearchResultExists)
                        sublist.itemAtIndex(0).clicked()
                }

                Keys.onEnterPressed: {
                    if(validSearchResultExists)
                        sublist.itemAtIndex(0).clicked()
                }

                HoverHandler {
                    id: sublistHoverHandler
                }
            }

            // Detection if the related model entry has been removed.
            // Using model.Component.destruction.connect is not reliable because
            // is not called for submodels maintained in c++ by the parent model.
            ItemSelectionModel {
                id: selection

                model: sfpm

                onHasSelectionChanged: {
                    if (!hasSelection)
                        collectiblesStackView.pop(StackView.Immediate)
                }

                Component.onCompleted: select(index, ItemSelectionModel.Select)
            }
        }
    }
}
