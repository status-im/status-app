import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Browser
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Wallet.stores
import shared.stores as SharedStores
import shared.stores.send

import Storybook
import Models
import Mocks

SplitView {
    id: root

    orientation: Qt.Vertical

    BrowserLayout {
        id: browserLayout
        Layout.fillWidth: true
        Layout.fillHeight: true

        isMobile: isMobile.checked
        userUID: "0xdeadbeef"
        transactionStore: TransactionStoreMock {}
        thirdpartyServicesEnabled: true
        connectorController: null
        platformOS: ctrlPlatformOS.currentValue

        bookmarksStore: BrowserStores.BookmarksStore {
            property var bookmarksModel: ListModel {}
            function addBookmark(url, name) {}
            function deleteBookmark(url) {}
            function updateBookmark(originalUrl, newUrl, newName) {}
            function getBookmarkIndexByUrl(url) {}
            function getCurrentFavorite(url) {}
        }
        downloadsStore: BrowserStores.DownloadsStore {
            property ListModel downloadModel : ListModel {
                property var downloads: []
            }
            function getDownload(index) {
                return downloadModel.downloads[index]
            }
        }
        browserRootStore: BrowserStores.BrowserRootStore {
            property var urlENSDictionary: ({})

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
                            browserLayout.localAccountSensitiveSettings.selectedBrowserSearchEngineId,
                            url,
                            browserLayout.localAccountSensitiveSettings.customSearchEngineUrl
                            )
            }

            function determineRealURL(text) {
                return UrlUtils.urlFromUserInput(text)
            }

            function obtainAddress(url) {
                return url
            }
        }
        browserWalletStore: BrowserStores.BrowserWalletStore {
            property var dappBrowserAccount: ({address:"0xdeadbeef", name: "Foobar", colorId: 0})
            property var accounts: []
            property string defaultCurrency: "USD"
            property string signingPhrase

            function getEtherscanLink(chainID) {
                return "https://etherscan.io/tx/"
            }

            function switchAccountByAddress(address) {
                dappBrowserAccount.address = address
            }
        }
        browserActivityStore: BrowserStores.BrowserActivityStore {}
        networksStore: SharedStores.NetworksStore {}
        currencyStore: SharedStores.CurrenciesStore {}

        readonly property var localAccountSensitiveSettings: Settings {
            property bool devToolsEnabled
            property bool compatibilityMode: true
            property bool shouldShowFavoritesBar
            property int useBrowserEthereumExplorer: Constants.browserEthereumExplorerEtherscan
            property int selectedBrowserSearchEngineId: SearchEnginesConfig.browserSearchEngineDuckDuckGo
            property string customSearchEngineUrl: "https://example.com/search?q="

            property bool autoLoadImages: true
            property bool javaScriptEnabled: true
            property bool errorPageEnabled: true
            property bool pluginsEnabled: true
            property bool autoLoadIconsForPage: true
            property bool touchIconsEnabled: SQUtils.Utils.isMobile
            property bool webRTCPublicInterfacesOnly
            property bool pdfViewerEnabled: true
            property bool focusOnNavigationEnabled: true
        }

        onSendToRecipientRequested: (address) => console.warn("!!! SEND TO:", address)
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 300

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Spoof user-agent:" }
            ComboBox {
                id: ctrlPlatformOS
                textRole: "text"
                valueRole: "value"
                model: [
                    { value: SQUtils.Utils.linux, text: "Linux" },
                    { value: SQUtils.Utils.mac, text: "MacOS" },
                    { value: SQUtils.Utils.windows, text: "Windows" },
                    { value: SQUtils.Utils.android, text: "Android" },
                    { value: SQUtils.Utils.ios, text: "iOS" }
                ]
                onCurrentValueChanged: browserLayout.reloadCurrentTab()
            }
            TextInput {
                id: userAgentString
                text: browserLayout.userAgent
                selectByMouse: true
                readOnly: true
            }
            Button {
                icon.name: "edit-copy"
                onClicked: {
                    userAgentString.selectAll()
                    userAgentString.copy()
                }
            }
        }

        Switch {
            id: isMobile
            text: "is mobile"
            checked: false
        }
    }
}

// category: Sections
// status: good
