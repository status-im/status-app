import QtQuick

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

import utils
import AppLayouts.Profile.stores

QtObject {
    id: root

    // Some token+currency-related functions are implemented in the profileSectionModule.
    // We should probably refactor this and move those functions to some Wallet module.
    property var _profileSectionModuleInst: profileSectionModule

    readonly property var currenciesModel: CurrenciesModel {}

    readonly property string currentCurrency: Global.appIsReady ? walletSection.currentCurrency : "USD"

    function updateCurrency(shortName) {
        walletSection.updateCurrency(shortName)
    }

    function getCurrencyAmount(amount, key) {
        try {
            let jsonData = walletSection.getCurrencyAmount(amount, key)
            let obj = JSON.parse(jsonData)
            return obj
        } catch (e) {
            console.warn("Error parsing prepared currency amount: " + e)
            return {amount: 0, tokenKey: key, symbol: "", displayDecimals: 2, stripTrailingZeroes: false}
        }
    }

    // key - token group key or token key or currency symbol
    function formatCurrencyAmount(amount, key, options = null, locale = null) {
        if (isNaN(amount)) {
            return qsTr("N/A")
        }
        var currencyAmount = getCurrencyAmount(amount, key)
        return LocaleUtils.currencyAmountToLocaleString(currencyAmount, options, locale)
    }

    // key - token group key or token key or currency symbol
    function formatCurrencyAmountFromBigInt(balance, key, decimals, options = null) {
        let bigIntBalance = SQUtils.AmountsArithmetic.fromString(balance)
        let decimalBalance = SQUtils.AmountsArithmetic.toNumber(bigIntBalance, decimals)
        return formatCurrencyAmount(decimalBalance, key, options)
    }

    // key - token group key or token key or currency symbol
    function formatBigNumber(number: string, key: string, noSymbolOption: bool): string  {
        if (!number)
            return "N/A"
        if (!key)
            key = root.currentCurrency
        let options = {}
        if (!!noSymbolOption)
            options = {noSymbol: true}
        return formatCurrencyAmount(parseFloat(number), key, options)
    }

    function getFiatValue(cryptoAmount, tokenKey) {
        var amount = _profileSectionModuleInst.ensUsernamesModule.getFiatValue(cryptoAmount, tokenKey)
        return parseFloat(amount)
    }

    function getCryptoValue(fiatAmount, tokenKey) {
        var amount = _profileSectionModuleInst.ensUsernamesModule.getCryptoValue(fiatAmount, tokenKey)
        return parseFloat(amount)
    }

    function getCurrentCurrencyAmount(amount) {
        return getCurrencyAmount(amount, currentCurrency)
    }

    function hexToDec(hex) {
        return globalUtils.hexToDec(hex)
    }

    function hexToEth(value) {
        return hexToEthDenomination(value, "eth")
    }

    function hexToEthDenomination(value, ethUnit) {
        let BigOps = SQUtils.AmountsArithmetic
        if (ethUnit !== "qwei" && ethUnit !== "eth") {
            console.warn("unsuported conversion")
            return BigOps.fromNumber(0)
        }
        let unitMapping = {
            "gwei": 9,
            "eth": 18
        }
        let decValue = hexToDec(value)
        if (!!decValue) {
            return BigOps.div(BigOps.fromNumber(decValue), BigOps.fromNumber(1, unitMapping[ethUnit]))
        }
        return BigOps.fromNumber(0)
    }
}
