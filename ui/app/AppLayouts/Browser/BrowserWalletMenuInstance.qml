import QtQuick

import StatusQ.Core.Theme

import AppLayouts.Browser.popups
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Browser.webview

// Loaded by URL (see BrowserLayout), so BrowserWalletMenu is not loaded with the browser section
BrowserWalletMenu {
    id: root

    required property Item anchorItem
    required property BrowserStores.BrowserWalletStore browserWalletStore
    required property BrowserWebViewContext webViewContext

    parent: root.anchorItem
    x: root.parent.width - root.width - Theme.halfPadding
    y: root.parent.height + 4

    accounts: root.browserWalletStore.accounts
    currentAccount: root.browserWalletStore.dappBrowserAccount

    onAccountChanged: newAddress => root.webViewContext.changeAccountForCurrentDapp(newAddress)
    onReload: {
        for (let i = 0; i < root.webViewContext.tabsModel.count; ++i)
            root.webViewContext.getWebView(i).reload()
    }
    onAccountSwitchRequested: address => root.browserWalletStore.switchAccountByAddress(address)
    onFilterAddressesChangeRequested: addressesJson => root.activityStore.activityController.setFilterAddressesJson(addressesJson)

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
