import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Browser
import AppLayouts.Browser.adapters
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Browser.webview
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
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        isMobile: ctrlIsMobile.checked
        userUID: "0xdeadbeef"
        transactionStore: TransactionStoreMock {}
        dappsEnabled: true
        thirdpartyServicesEnabled: ctrl3rdPartyServices.checked
        connectorController: QtObject {
            function getDAppsByClientId(clientId) {
                const rawModel = [
                                   {
                                       name: "",
                                       url: "https://dapp.test/1",
                                       iconUrl: "https://se-sdk-dapp.vercel.app/assets/eip155:1.png",
                                       connectorBadge: "https://random.imagecdn.app/20/20"
                                   },
                                   {
                                       name: "Test dApp 4 - very long name !!!!!!!!!!!!!!!!",
                                       url: "https://dapp.test/4",
                                       iconUrl: "https://react-app.walletconnect.com/assets/eip155-1.png",
                                       connectorBadge: ""
                                   },
                                   {
                                       name: "Test dApp 5 - very long url",
                                       url: "https://dapp.test/very_long/url/unusual",
                                       iconUrl: "https://react-app.walletconnect.com/assets/eip155-1.png",
                                       connectorBadge: ""
                                   },
                                   {
                                       name: "Test dApp 6",
                                       url: "https://dapp.test/6",
                                       iconUrl: "https://react-app.walletconnect.com/assets/eip155-1.png",
                                       connectorBadge: ""
                                   },
                                   {
                                       name: "Test dApp 8",
                                       url: "https://dapp.test/8",
                                       iconUrl: "",
                                       connectorBadge: ""
                                   }
                        ]
                return JSON.stringify(rawModel)
            }

            function disconnect(hostname) {
                console.info("connectorController.disconnect", hostname)
            }

            function connectorCallRPC(requestId, rpcRequestJSON) {
                console.info("connectorController.connectorCallRPC", requestId, rpcRequestJSON)
            }
        }

        platformOS: ctrlPlatformOS.currentValue
        leftPortraitPadding: 0

        bookmarksStore: BrowserStores.BookmarksStore {}
        browserPreferencesStore: BrowserStores.BrowserPreferencesStore { id: browserPrefsStore }
        downloadsStore: BrowserStores.DownloadsStore {
            // Stub is empty; provide the real Download Records API for Storybook.
            property var downloadModel: []
            property string downloadsDirectory: "/tmp/status-storybook-downloads"
            // One platform seam (DownloadsStore.platform) — nothing exists on disk here.
            property var platform: ({
                fileExists: function(path) { return false },
                preferShareSheet: false,
                showInFolderSupported: true
            })
            readonly property url _downloadRecordUrl: Qt.resolvedUrl(
                "../../../ui/app/AppLayouts/Browser/stores/DownloadRecord.qml")
            function addDownload(download, hostView) {
                const component = Qt.createComponent(_downloadRecordUrl)
                if (component.status !== Component.Ready)
                    return null
                const record = component.createObject(this)
                record.attach(download)
                if (hostView)
                    record.originatingView = hostView
                else if (download && download.view)
                    record.originatingView = download.view
                if (hostView && hostView.offTheRecord !== undefined)
                    record.offTheRecord = !!hostView.offTheRecord
                record.terminalReached.connect(() => {
                    if (!viewHasNonTerminalDownloads(record.originatingView))
                        viewDownloadsCleared(record.originatingView)
                })
                downloadModel = downloadModel.concat([record])
                return record
            }
            function viewHasNonTerminalDownloads(view) {
                if (!view)
                    return false
                for (let i = 0; i < downloadModel.length; ++i) {
                    const record = downloadModel[i]
                    if (!record || record.originatingView !== view)
                        continue
                    if (record.isTerminalState) {
                        if (!record.isTerminalState(record.state))
                            return true
                    } else if (!record.isTerminal) {
                        return true
                    }
                }
                return false
            }
            signal viewDownloadsCleared(var view)
            function resolveDownloadTarget(suggestedFileName) {
                const name = suggestedFileName || "download.bin"
                return downloadsDirectory + "/" + name
            }
            function acceptLiveDownload(download, record) {
                const target = resolveDownloadTarget(
                    download.suggestedFileName || download.downloadFileName || "download.bin")
                const slash = target.lastIndexOf("/")
                if (record) {
                    record.downloadDirectory = target.substring(0, slash)
                    record.fileName = target.substring(slash + 1)
                }
                if (download.downloadDirectory !== undefined) {
                    download.downloadDirectory = target.substring(0, slash)
                    download.downloadFileName = target.substring(slash + 1)
                    download.accept()
                } else {
                    download.accept(target)
                }
                return target
            }
            // Record-vocabulary surface the shared Record menu binds against (ticket 09).
            function refreshMissingFiles() {}
            function canShareFile(record) {
                return !!record && !record.missingFile && !!record.targetPath
            }
            function canShareUrl(record) {
                return !!record && !!record.url && String(record.url).length > 0
            }
            function canShowInFolder(record) {
                return canShareFile(record)
            }
            function canRetryFromMenu(record) { return false }
            function canRetryFromTap(record) { return false }
            function openRecord(record) {}
            function openDirectoryForRecord(record) {}
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

            function getEtherscanLink(chainID) {
                return "https://etherscan.io/tx/"
            }

            function switchAccountByAddress(address) {
                dappBrowserAccount.address = address
            }
        }
        browserActivityStore: BrowserStores.BrowserActivityStore {
            property var activityController: QtObject {
                function setFilterChainsJson(json, force) {}
                function setFilterAddressesJson(json) {}
            }
        }
        networksStore: SharedStores.NetworksStore {}
        currencyStore: SharedStores.CurrenciesStore {}

        readonly property var localAccountSensitiveSettings: Settings {
            property bool devToolsEnabled
            property bool compatibilityMode: true
            property alias shouldShowFavoritesBar: ctrlShowFavoritesBar.checked
            property int useBrowserEthereumExplorer: Constants.browserEthereumExplorerEtherscan
            property int selectedBrowserSearchEngineId: SearchEnginesConfig.browserSearchEngineDuckDuckGo
            property string customSearchEngineUrl: "https://example.com/search?q="

            property bool autoLoadImages: true
            property bool javaScriptEnabled: true
            property bool errorPageEnabled: true
            property bool pluginsEnabled: true
            property bool autoLoadIconsForPage: true
            property bool touchIconsEnabled: browserLayout.isMobile
            property bool webRTCPublicInterfacesOnly
            property bool focusOnNavigationEnabled: true
        }

        onSendToRecipientRequested: (address) => console.warn("!!! SEND TO:", address)
    }

    ColumnLayout {
        SplitView.fillWidth: true
        SplitView.preferredHeight: 200

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Spoof platform OS:" }
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
            Label {
                id: userAgentString
                text: browserLayout.userAgent
            }
            Button {
                icon.name: "edit-copy"
                onClicked: ClipboardUtils.setText(userAgentString.text)
            }
        }

        Switch {
            id: ctrlIsMobile
            text: "Is mobile"
        }

        Switch {
            id: ctrlShowFavoritesBar
            text: "Show favorites bar"
        }

        Switch {
            id: ctrl3rdPartyServices
            text: "3rd party services enabled"
            checked: true
        }

        RowLayout {
            Layout.fillWidth: true
            Switch {
                text: "Restore open tabs"
                checked: browserPrefsStore.getRestoreOpenTabs()
                onToggled: browserPrefsStore.setRestoreOpenTabs(checked)
            }
            Button {
                text: "Clear saved tabs"
                onClicked: browserPrefsStore.clearOpenTabsSession()
            }
        }
    }
}

// category: Sections
// status: good
