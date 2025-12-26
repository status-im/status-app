import QtQml

import StatusQ.Core.Utils as SQUtils

import utils

/* This is used so that there is an easy way to fill in the data
needed to launch the Swap Modal with pre-filled requisites. */
QtObject {
    id: root

    signal formValuesChanged()

    property string selectedAccountAddress: ""
    property int selectedNetworkChainId: -1
    property string fromGroupKey: root.defaultFromGroupKey
    property string fromTokenAmount: ""
    property string toGroupKey: root.defaultToGroupKey
    property string toTokenAmount: ""
    property double selectedSlippage: 0.5

    // default to token key
    property string defaultToGroupKey: root.getDefaultToGroupKey(root.selectedNetworkChainId)
    // default from group key
    property string defaultFromGroupKey: root.getDefaultFromGroupKey(root.selectedNetworkChainId)
    // 15 seconds
    property int autoRefreshTime: 15000

    onSelectedAccountAddressChanged: root.formValuesChanged()
    onSelectedNetworkChainIdChanged: root.formValuesChanged()
    onFromGroupKeyChanged: root.formValuesChanged()
    onFromTokenAmountChanged: root.formValuesChanged()
    onToGroupKeyChanged: root.formValuesChanged()
    onToTokenAmountChanged: root.formValuesChanged()
    onSelectedSlippageChanged: root.formValuesChanged()

    function resetFormData() {
        root.selectedAccountAddress = ""
        root.selectedNetworkChainId = -1
        root.selectedSlippage = 0.5
        root.resetFromTokenValues()
        root.resetToTokenValues()
    }

    function resetFromTokenValues(keepDefault = true) {
        root.defaultFromGroupKey = root.getDefaultFromGroupKey(root.selectedNetworkChainId)
        if(keepDefault) {
            root.fromGroupKey = root.defaultFromGroupKey
        } else {
            root.fromGroupKey = ""
        }
        root.fromTokenAmount = ""
    }

    function resetToTokenValues(keepDefault = true) {
        root.defaultToGroupKey = root.getDefaultToGroupKey(root.selectedNetworkChainId)
        if(keepDefault) {
            root.toGroupKey = root.defaultToGroupKey
        } else {
            root.toGroupKey = ""
        }
        root.toTokenAmount = ""
    }

    function isFormFilledCorrectly() {
        let bigIntNumber = SQUtils.AmountsArithmetic.fromString(root.fromTokenAmount)
        return !!root.selectedAccountAddress &&
                root.selectedNetworkChainId !== -1 &&
                !!root.fromGroupKey && !!root.toGroupKey &&
                (!!root.fromTokenAmount && !isNaN(bigIntNumber) && bigIntNumber.gt(0)) &&
                root.selectedSlippage > 0
    }

    function getDefaultFromGroupKey(chainId) {
        switch (chainId) {
            case Constants.chains.binanceSmartChainMainnetChainId:
            case Constants.chains.binanceSmartChainTestnetChainId:
                return Constants.usdcGroupKeyBsc
            default:
                return Constants.usdcGroupKeyEvm
        }
    }

    function getDefaultToGroupKey(chainId) {
        let selectedGK = Utils.getNativeTokenGroupKey(chainId)
        if (selectedGK !== root.defaultFromGroupKey) {
            return selectedGK
        }
        return root.getDefaultFromGroupKey()
    }
}
