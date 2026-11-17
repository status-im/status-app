import QtQuick

import StatusQ

import utils

QtObject {
    id: root

    property var urlENSDictionary: ({})

    function getAscii2Hex(input) {
        return globalUtils.ascii2Hex(input)
    }

    function getHex2Ascii(input) {
        return globalUtils.hex2Ascii(input)
    }

    function getWei2Eth(wei,decimals) {
        return globalUtils.wei2Eth(wei,decimals)
    }

    function getEth2Hex(eth) {
        return globalUtils.eth2Hex(eth)
    }

    function getGwei2Hex(gwei){
        return globalUtils.gwei2Hex(gwei)
    }

    function get0xFormedUrl(browserExplorer, url) {
        var tempUrl = ""
        switch (browserExplorer) {
        case Constants.browserEthereumExplorerEtherscan:
            if (url.length > 42) {
                tempUrl = "https://etherscan.io/tx/" + url; break;
            } else {
                tempUrl = "https://etherscan.io/address/" + url; break;
            }
        case Constants.browserEthereumExplorerEthplorer:
            if (url.length > 42) {
                tempUrl = "https://ethplorer.io/tx/" + url; break;
            } else {
                tempUrl = "https://ethplorer.io/address/" + url; break;
            }
        case Constants.browserEthereumExplorerBlockchair:
            if (url.length > 42) {
                tempUrl = "https://blockchair.com/ethereum/transaction/" + url; break;
            } else {
                tempUrl = "https://blockchair.com/ethereum/address/" + url; break;
            }
        }
        return tempUrl
    }

    function getFormedUrl(selectedBrowserSearchEngineId, url) {
        return SearchEnginesConfig.formatSearchUrl(
            localAccountSettings.selectedBrowserSearchEngineId,
            url,
            localAccountSettings.customSearchEngineUrl
        )
    }

    // ENS resolution functions (stubbed until connector integration)
    // See: https://github.com/status-im/status-app/issues/19137
    function determineRealURL(text) {
        const url = UrlUtils.urlFromUserInput(text)
        // TODO: ENS resolution will be handled by connector in next PR
        return url
    }

    function obtainAddress(url) {
        // TODO: ENS resolution will be handled by connector in next PR
        return url
    }
}
