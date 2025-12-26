import QtQuick

import AppLayouts.Wallet.popups.swap
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Wallet.stores as WalletStores

import shared.stores

import utils

QtObject {
    id: root

    required property var popupParent

    required property CurrenciesStore currencyStore
    required property AppLayoutStores.RootStore rootStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property NetworksStore networksStore

    function openSendModal(params = {}, callback = null) {
        d.swapInputParams.resetFormData()

        // don't set from and to group keys, cause they will be eveluated from the default keys, just rebind them
        d.swapInputParams.fromGroupKey = Qt.binding(() => d.swapInputParams.defaultFromGroupKey)
        d.swapInputParams.toGroupKey = Qt.binding(() => d.swapInputParams.defaultToGroupKey)

        if (d.isValidParameter(params.selectedNetworkChainId)) {
            d.swapInputParams.selectedNetworkChainId = params.selectedNetworkChainId
        }
        if (d.isValidParameter(params.defaultFromGroupKey)) {
            d.swapInputParams.defaultFromGroupKey = params.defaultFromGroupKey
        }
        if (d.isValidParameter(params.defaultToGroupKey)) {
            d.swapInputParams.defaultToGroupKey = params.defaultToGroupKey
        } else {
            // this is important cause it reevaluates token on the receiver side based on the token on the sender side (e.g. eth selected for sender)
            d.swapInputParams.defaultToGroupKey = d.swapInputParams.getDefaultToGroupKey(d.swapInputParams.selectedNetworkChainId)
        }
        if (d.isValidParameter(params.autoRefreshTime)) {
            d.swapInputParams.autoRefreshTime = params.autoRefreshTime
        }
        if (d.isValidParameter(params.selectedSlippage)) {
            d.swapInputParams.selectedSlippage = params.selectedSlippage
        }
        if (d.isValidParameter(params.selectedAccountAddress)) {
            d.swapInputParams.selectedAccountAddress = params.selectedAccountAddress
        }

        if (d.isValidParameter(params.fromTokenAmount)) {
            d.swapInputParams.fromTokenAmount = params.fromTokenAmount
        }
        if (d.isValidParameter(params.toTokenAmount)) {
            d.swapInputParams.toTokenAmount = params.toTokenAmount
        }

        let swapModalInst = swapModalComponent.createObject(popupParent)
        swapModalInst.open()

        if (callback)
            callback(swapModalInst)
    }

    readonly property QtObject _d: QtObject {
        id: d

        function addMetricsEvent(subEvent) {
            Global.addCentralizedMetricIfEnabled("swap", {subEvent: subEvent})
        }

        function isValidParameter(param) {
            return param !== undefined && param !== null
        }

        readonly property WalletStores.SwapStore swapStore: WalletStores.SwapStore {
            onTransactionSent: (returnedUuid, chainId, approvalTx, txHash, error) => {
                                   if(returnedUuid !== d.lastUuid || approvalTx) {
                                       return
                                   }

                                   if (!!error) {
                                       d.addMetricsEvent("transaction error")
                                   } else {
                                       d.addMetricsEvent("transaction successful")
                                   }
                               }
        }

        property string lastUuid

        property SwapInputParamsForm swapInputParams: SwapInputParamsForm {}
    }

    readonly property Component swapModalComponent: Component {
        // TODO: Update the API to be explicit and avoid direct store access
        SwapModal {
            swapAdaptor: SwapModalAdaptor {
                swapStore: d.swapStore
                walletAssetsStore: root.walletAssetsStore
                currencyStore: root.currencyStore
                networksStore: root.networksStore
                swapFormData: d.swapInputParams
                swapOutputData: SwapOutputData{}

                onUuidChanged: {
                    if (!!uuid)
                        d.lastUuid = uuid
                }
            }
            swapInputParamsForm: d.swapInputParams
            loginType: root.rootStore.getLoginType()
            onAddMetricsEvent: (subEvent) => d.addMetricsEvent(subEvent)
            onClosed: {
                destroy()
                swapInputParamsForm.resetFormData()
            }
        }
    }
}
