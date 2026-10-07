import QtQuick

import StatusQ.Core.Utils as SQUtils

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

    required property var savedAddressesModel
    required property var recentRecipientsModel

    required property bool swapEnabled
    required property bool routeOrderEnabled

    /** number of swap modals open now **/
    property int openModals: 0

    function openSendModal(params = {}, callback = null) {
        if (!root.swapEnabled) {
            console.warn("SwapModalHandler: swap is disabled by feature flag")
            return
        }

        d.swapInputParams.resetFormData()

        let swapModalInst = swapModalComponent.createObject(popupParent)
        root.openModals++
        swapModalInst.closed.connect(() => root.openModals--)
        swapModalInst.open()

        if (callback)
            callback(swapModalInst)

        const setup = (params) => {
            // don't set from and to group keys, cause they will be eveluated from the default keys, just rebind them
            d.swapInputParams.fromGroupKey = Qt.binding(() => d.swapInputParams.defaultFromGroupKey)
            d.swapInputParams.toGroupKey = Qt.binding(() => d.swapInputParams.defaultToGroupKey)

            // The pay side lists what the account holds, so the modal opens on the chain
            // where the account holds the pay token (the one the launch names, else the
            // default), preferring the requested chain. Held nowhere: no pay token.
            const requestedChainId = d.isValidParameter(params.selectedNetworkChainId) ? params.selectedNetworkChainId : -1
            const pay = d.resolvePayToken(swapModalInst.swapAdaptor, params.defaultFromGroupKey,
                                          d.isValidParameter(params.selectedAccountAddress) ? params.selectedAccountAddress : "",
                                          requestedChainId)
            if (pay.chainId !== -1) {
                d.swapInputParams.selectedNetworkChainId = pay.chainId
            } else if (requestedChainId !== -1) {
                d.swapInputParams.selectedNetworkChainId = requestedChainId
            }
            // optional pre-filled destination chain (defaults to the source chain)
            if (d.isValidParameter(params.toNetworkChainId)) {
                d.swapInputParams.toNetworkChainId = params.toNetworkChainId
            }
            if (!!pay.groupKey) {
                d.swapInputParams.defaultFromGroupKey = pay.groupKey
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
            if (pay.chainId === -1) {
                d.swapInputParams.fromGroupKey = "" // "Select asset"
            }
        }

        if (swapModalInst.opened) {
            setup(params)
        } else {
            swapModalInst.onOpened.connect(() => {
                Qt.callLater(() => setup(params))
            })
        }
    }

    readonly property QtObject _d: QtObject {
        id: d

        function isValidParameter(param) {
            return param !== undefined && param !== null
        }

        function resolvePayToken(adaptor, namedGroupKey, accountAddress, requestedChainId) {
            let candidates = []
            if (d.isValidParameter(namedGroupKey) && namedGroupKey !== "") {
                candidates = [namedGroupKey]
            } else {
                const chains = adaptor.filteredFlatNetworksModel
                const chainIds = [requestedChainId]
                for (let i = 0; i < chains.rowCount(); i++)
                    chainIds.push(SQUtils.ModelUtils.get(chains, i, "chainId"))
                for (const chainId of chainIds) {
                    const groupKey = d.swapInputParams.getDefaultFromGroupKey(chainId)
                    if (!candidates.includes(groupKey))
                        candidates.push(groupKey)
                }
            }
            for (const groupKey of candidates) {
                const chainId = adaptor.chainHoldingGroup(groupKey, accountAddress, requestedChainId)
                if (chainId !== -1)
                    return { groupKey: groupKey, chainId: chainId }
            }
            return { groupKey: candidates.length > 0 ? candidates[0] : "", chainId: -1 }
        }

        readonly property WalletStores.SwapStore swapStore: WalletStores.SwapStore {
            onTransactionSent: (returnedUuid, chainId, approvalTx, txHash, error) => {
                                   if(returnedUuid !== d.lastUuid || approvalTx) {
                                       return
                                   }
                               }
        }

        property string lastUuid

        property SwapInputParamsForm swapInputParams: SwapInputParamsForm {}
    }

    readonly property Component swapModalComponent: Component {
        // TODO: Update the API to be explicit and avoid direct store access
        SwapModal {
            id: swapModal

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
            routeOrderEnabled: root.routeOrderEnabled

            savedAddressesModel: root.savedAddressesModel
            recentRecipientsModel: root.recentRecipientsModel
            fnResolveENS: function(ensName, uuid) {
                root.rootStore.resolveENS(ensName, uuid)
            }

            readonly property Connections resolvedEnsConnection: Connections {
                target: root.rootStore
                function onEnsNameResolved(resolvedPubKey, resolvedAddress, uuid) {
                    swapModal.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
                }
            }

            onClosed: {
                swapInputParamsForm.resetFormData()
                destroy()
            }
        }
    }
}
