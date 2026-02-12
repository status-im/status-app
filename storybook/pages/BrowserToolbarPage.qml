import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core as SQCore
import StatusQ.Core.Theme
import AppLayouts.Profile.views

import AppLayouts.Browser.panels

import Storybook

import utils

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Vertical

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        color: Theme.palette.directColor2

        ColumnLayout {
            anchors.centerIn: parent

            BrowserLandscapeToolbar {
                Layout.preferredWidth: Number(toolbarWidth.text)
                Layout.preferredHeight: 50

                isMobile: ctrlIsMobile.checked
                currentTabIsDownloads: false
                url: "https://status.app"
                openTabsCount: 24
                currentTabIncognito: inConginto.checked
                currentTabIsBookmark: false
                currentTabLoading: false

                canGoBack: true
                canGoForward: true
                browserDappsModel: ListModel {
                    ListElement {name: "DApp One"; url: "https://dapp.one"; iconUrl: "qrc:/assets/dapp1.png"; connectorBadge: "qrc:/assets/walletconnect_badge.png" }
                    ListElement {name: "DApp Two"; url: "https://dapp.one"; iconUrl: "qrc:/assets/dapp1.png"; connectorBadge: "qrc:/assets/walletconnect_badge.png" }
                    ListElement {name: "DApp Three"; url: "https://dapp.one"; iconUrl: "qrc:/assets/dapp1.png"; connectorBadge: "qrc:/assets/walletconnect_badge.png" }
                }

                onRequestAllOpenTabsView: () => {
                                              logs.logEvent("browser::requestAllOpenTabsView")
                                          }
                onAddBookmarkRequested: () => {
                                            logs.logEvent("browser::onAddBookmarkRequested")
                                            currentTabIsBookmark = !currentTabIsBookmark
                                        }
                onRequestStopLoadingPage: () => {
                                              logs.logEvent("browser::requestStopLoadingPage")
                                              currentTabLoading = false
                                          }
                onRequestReloadPage: () => {
                                         logs.logEvent("browser::requestReloadPage")
                                         currentTabLoading = true
                                     }
                onRequestHistoryPopup: () => {
                                           logs.logEvent("browser::requestHistoryPopup")
                                       }
                onRequestGoForward: () => {
                                        logs.logEvent("browser::requestGoForward")
                                    }
                onRequestGoBack: () => {
                                     logs.logEvent("browser::requestGoBack")
                                 }
                onRequestLaunchInBrowser: (url) => {
                                              logs.logEvent("browser::requestLaunchInBrowser: " + url)
                                          }
                onRequestSearch: () => {
                                     logs.logEvent("browser::requestSearch")
                                 }
                onRequestOpenDapp: (url) => {
                                       logs.logEvent("browser::requestOpenDapp: " + url)
                                   }
                onRequestDisconnectDapp: (dappUrl) => {
                                             logs.logEvent("browser::requestDisconnectDapp: " + dappUrl)
                                         }
                onRequestWalletMenu: () => {
                                         logs.logEvent("browser::requestWalletMenu")
                                     }
                onOpenSettingMenu: function(target) {
                    logs.logEvent("browser::openSettingMenu; target: " + target)
                }
                onGoIncognito: function(checked) {
                    logs.logEvent("browser::goIncognito; checked: " + checked)
                }
                onRequestDownloadsView: {
                    logs.logEvent("browser::requestDownloadsView")
                }
            }

            BrowserPortraitToolbar {
                Layout.preferredWidth: Number(toolbarWidth.text) / 2
                Layout.preferredHeight: 50
                Layout.alignment: Qt.AlignHCenter

                isMobile: ctrlIsMobile.checked
                currentTabIsDownloads: false
                openTabsCount: 24
                currentTabIncognito: inConginto.checked
                currentTabIsBookmark: false
                currentTabLoading: false

                canGoBack: true
                canGoForward: true
                browserDappsModel: ListModel {
                    ListElement {name: "DApp One"; url: "https://dapp.one"; iconUrl: "qrc:/assets/dapp1.png"; connectorBadge: "qrc:/assets/walletconnect_badge.png" }
                    ListElement {name: "DApp Two"; url: "https://dapp.one"; iconUrl: "qrc:/assets/dapp1.png"; connectorBadge: "qrc:/assets/walletconnect_badge.png" }
                    ListElement {name: "DApp Three"; url: "https://dapp.one"; iconUrl: "qrc:/assets/dapp1.png"; connectorBadge: "qrc:/assets/walletconnect_badge.png" }
                }

                onRequestAllOpenTabsView: () => {
                                              logs.logEvent("browser::requestAllOpenTabsView")
                                          }
                onAddBookmarkRequested: () => {
                                            logs.logEvent("browser::onAddBookmarkRequested")
                                            currentTabIsBookmark = !currentTabIsBookmark
                                        }
                onRequestStopLoadingPage: () => {
                                              logs.logEvent("browser::requestStopLoadingPage")
                                              currentTabLoading = false
                                          }
                onRequestReloadPage: () => {
                                         logs.logEvent("browser::requestReloadPage")
                                         currentTabLoading = true
                                     }
                onRequestHistoryPopup: () => {
                                           logs.logEvent("browser::requestHistoryPopup")
                                       }
                onRequestGoForward: () => {
                                        logs.logEvent("browser::requestGoForward")
                                    }
                onRequestGoBack: () => {
                                     logs.logEvent("browser::requestGoBack")
                                 }
                onRequestLaunchInBrowser: (url) => {
                                              logs.logEvent("browser::requestLaunchInBrowser: " + url)
                                          }
                onRequestSearch: () => {
                                     logs.logEvent("browser::requestSearch")
                                 }
                onRequestOpenDapp: (url) => {
                                       logs.logEvent("browser::requestOpenDapp: " + url)
                                   }
                onRequestDisconnectDapp: (dappUrl) => {
                                             logs.logEvent("browser::requestDisconnectDapp: " + dappUrl)
                                         }
                onRequestWalletMenu: () => {
                                         logs.logEvent("browser::requestWalletMenu")
                                     }
                onOpenSettingMenu: function(target) {
                    logs.logEvent("browser::openSettingMenu; target: " + target)
                }
                onGoIncognito: function(checked) {
                    logs.logEvent("browser::goIncognito; checked: " + checked)
                }
                onRequestDownloadsView: {
                    logs.logEvent("browser::requestDownloadsView")
                }
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 300

        logsView.logText: logs.logText

        ColumnLayout {

            Switch {
                id: ctrlIsMobile
                text: "Is Mobile"
                checked: false
            }

            Switch {
                id: inConginto
                text: "Is incognito"
                checked: false
            }

            RowLayout {
                Label {
                    text: "Toolbar width:"
                }
                TextField {
                    id: toolbarWidth
                    text: "1000"
                }
            }
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=4806-79527&m=dev
