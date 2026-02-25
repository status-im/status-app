import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Core.Theme

/**
  Two-tabs panel holding searchable lists of assets (single level) and
  collectibles (two levels).

  Structure:

  TabBar (assets, collectibles)
  StackLayout (current index bound to tab bar's current index)
      Assets List  (assets part)
      StackView    (collectibles part)
         Collectibles List (top level - groups by collection/community)
         Collectibles List (nested level, on demand)
*/
Control {
    id: root

    enum Tabs {
        Assets = 0,
        Collectibles = 1
    }

    /** Expected model structure: see SearchableAssetsPanel::model **/
    property alias assetsModel: searchableAssetsPanel.model

    /** Expected model structure: see SearchableCollectiblesPanel::model **/
    property alias collectiblesModel: searchableCollectiblesPanel.model

    // Index of the current tab, indexes ​​correspond to the Tabs enum values.
    property alias currentTab: tabBar.currentIndex

    property bool showSectionName: true

    signal assetSelected(string key)
    signal collectionSelected(string key)
    signal collectibleSelected(string key)
    signal searchInAssets(string keyword)
    signal fetchMoreAssets()

    property string highlightedKey: ""

    function clear() {
        searchableAssetsPanel.clearSearch()
        searchableCollectiblesPanel.clearSearch()
    }

    contentItem: ColumnLayout {
        spacing: 0
        StatusTabBar {
            id: tabBar

            objectName: "tokensTabBar"

            Layout.fillWidth: true
            visible: !!root.assetsModel && !!root.collectiblesModel

            currentIndex: !!root.collectiblesModel && !root.assetsModel
                          ? TokenSelectorPanel.Tabs.Collectibles
                          : TokenSelectorPanel.Tabs.Assets

            StatusTabButton {
                objectName: "assetsTab"

                text: qsTr("Assets")
                width: visible ? implicitWidth : 0
                leftPadding: visible ? Theme.padding : 0

                visible: !!root.assetsModel
            }

            StatusTabButton {
                objectName: "collectiblesTab"
                
                text: qsTr("Collectibles")
                width: implicitWidth

                visible: !!root.collectiblesModel
            }
        }

        StatusDialogDivider {
            Layout.topMargin: -9
            Layout.fillWidth: true
        }

        SearchableAssetsPanel {
            id: searchableAssetsPanel

            visible: tabBar.currentIndex === TokenSelectorPanel.Tabs.Assets
                     && !!root.assetsModel
            Layout.fillWidth: true
            Layout.fillHeight: true

            highlightedKey: root.highlightedKey
            showSectionName: root.showSectionName

            onSelected: (key) => root.assetSelected(key)
            onSearch: (keyword) => root.searchInAssets(keyword)
            onLoadMoreRequested: root.fetchMoreAssets()
        }

        SearchableCollectiblesPanel {
            id: searchableCollectiblesPanel

            visible: tabBar.currentIndex === TokenSelectorPanel.Tabs.Collectibles
                     && !!root.collectiblesModel
            Layout.fillWidth: true
            Layout.fillHeight: true

            highlightedKey: root.highlightedKey

            onCollectibleSelected: (key) => root.collectibleSelected(key)
            onCollectionSelected: (key) => root.collectionSelected(key)
        }
    }
}
