import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core.Utils
import StatusQ.Core.Theme

import AppLayouts.Wallet.panels

import utils

Control {
    id: root

    /** Expected model structure: see SearchableAssetsPanel::model **/
    property alias assetsModel: tokenSelectorPanel.assetsModel

    /** Expected model structure: see SearchableCollectiblesPanel::model **/
    property alias collectiblesModel: tokenSelectorPanel.collectiblesModel

    /** Sets size of the TokenSelectorButton **/
    property alias size: tokenSelectorButton.size

    readonly property bool isTokenSelected: tokenSelectorButton.selected

    property bool showSectionName: true

    signal assetSelected(string key)
    signal collectionSelected(string key)
    signal collectibleSelected(string key)
    signal searchInAssets(string keyword)
    signal fetchMoreAssets()

    // Index of the current tab, indexes ​​correspond to the
    // TokensSelectorPanel.Tabs enum values.
    property alias currentTab: tokenSelectorPanel.currentTab

    function setSelection(name: string, icon: url, key: string) {
        // reset token selector in case of empty call
        if (!key && !name && !icon.toString()) {
            tokenSelectorButton.selected = false
        } else {
            tokenSelectorButton.selected = true
            tokenSelectorButton.name = name
            tokenSelectorButton.icon = icon
            tokenSelectorPanel.highlightedKey = key ?? ""
        }
    }

    function close() {
        dropdown.close()
    }

    QObject {
        id: d

        readonly property int maxPopupHeight: 455
    }

    contentItem: TokenSelectorButton {
        id: tokenSelectorButton

        objectName: "tokenSelectorButton"

        forceHovered: dropdown.opened

        onClicked: dropdown.opened ? dropdown.close() : dropdown.open()
    }

    StatusDropdown {
        id: dropdown

        objectName: "dropdown"

        directParent: root
        relativeY: parent.height + 4
        width: 448
        fillHeightOnBottomSheet: true

        horizontalPadding: 0
        bottomPadding: Theme.halfPadding / 2

        onClosed: tokenSelectorPanel.clear()

        contentItem: Item {
            implicitHeight: Math.min(tokenSelectorPanel.implicitHeight, d.maxPopupHeight)

            TokenSelectorPanel {
                id: tokenSelectorPanel

                objectName: "tokenSelectorPanel"

                anchors.fill: parent

                function findSubitem(key) {
                    const count = collectiblesModel.rowCount()

                    for (let i = 0; i < count; i++) {
                        const entry = ModelUtils.get(collectiblesModel, i)
                        const subitem = ModelUtils.getByKey(
                                          entry.subitems, "key", key)
                        if (subitem)
                            return subitem
                    }
                }

                function setCurrentAndClose(name, icon) {
                    tokenSelectorButton.name = name
                    tokenSelectorButton.icon = icon
                    tokenSelectorButton.selected = true
                    dropdown.close()
                }

                showSectionName: root.showSectionName

                onAssetSelected: function(key) {
                    const entry = ModelUtils.getByKey(assetsModel, "key", key)
                    highlightedKey = key

                    setCurrentAndClose(entry.symbol, entry.iconSource)
                    root.assetSelected(key)
                }

                onCollectibleSelected: function(key) {
                    highlightedKey = key

                    const subitem = findSubitem(key)
                    setCurrentAndClose(subitem.name, subitem.icon)

                    root.collectibleSelected(key)
                }

                onCollectionSelected: function(key) {
                    highlightedKey = key

                    const subitem = findSubitem(key)
                    setCurrentAndClose(subitem.name, subitem.icon)

                    root.collectionSelected(key)
                }

                onSearchInAssets: function(keyword) {
                    root.searchInAssets(keyword)
                }

                onFetchMoreAssets: function() {
                    root.fetchMoreAssets()
                }
            }
        }
    }
}
