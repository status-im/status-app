import QtQuick

import StatusQ.Core.Theme

import AppLayouts.Browser.popups

// Loaded by URL (see BrowserLayout), so BrowserWalletMenu is not loaded with the browser section
BrowserWalletMenu {
    id: root

    required property Item anchorItem

    parent: root.anchorItem
    x: root.parent.width - root.width - Theme.halfPadding
    y: root.parent.height + 4

    Connections {
        target: root.activityStore.transactionActivityStatus
        enabled: root.visible
        function onIsFilterDirtyChanged() {
            root.activityStore.updateTransactionFilterIfDirty()
        }
        function onFilterChainsChanged() {
            root.activityStore.currentActivityFiltersStore.updateCollectiblesModel()
            root.activityStore.currentActivityFiltersStore.updateRecipientsModel()
        }
    }
}
