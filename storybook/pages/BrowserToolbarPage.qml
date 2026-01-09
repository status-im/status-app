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
        BrowserToolbar {
            anchors.centerIn: parent
            width: Number(toolbarWidth.text)
            height: 50

            openTabsCount: 24
            currentTabIncognito: inConginto.checked
            currentTabIsBookmark: false
            currentTabLoading: false

            bookmarksAvailable: true
            canGoBack: true
            canGoForward: true
            reloadBtnAvailable: !isMobile.checked
            addressBarAvailable: !isMobile.checked
            dappBtnAvailable: !isMobile.checked
            walletAccountsBtnAvailable: !isMobile.checked
            showAllOpenTabsBtn: isMobile.checked
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
            onOpenSettingMenu: () => {
                                     logs.logEvent("browser::openSettingMenu")
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
                id: isMobile
                text: "Is Mobile"
                checked: false
            }

            Switch {
                id: inConginto
                text: "Is incognito"
                checked: false
            }

            RowLayout {
                Text {
                    text: "Toolbar width:"
                }
                TextInput {
                    id: toolbarWidth
                    text: !isMobile.checked ? "1000": "400"
                    color: Theme.palette.primaryColor1
                }
            }
        }
    }
}

// category: Panels
// status: good
// https://www.figma.com/design/pJgiysu3rw8XvL4wS2Us7W/DS?node-id=4806-79527&m=dev
