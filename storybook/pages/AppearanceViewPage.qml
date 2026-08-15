import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Backpressure

import AppLayouts.Profile.views

import AppLayouts.stores as AppLayoutStores
import shared.stores as SharedStores
import mainui.sectionLoaders

Item {
    id: root

    QtObject {
        id: d

        // not bindings intentionally
        property real nativeWindowDpr // baseline/native DPR of the respective Screen
        property string screen

        // refresh values when either the Window changes Screen, or the Screen OS settings have changed
        readonly property var nativeWindowDprConn: Connections {
            enabled: false
            target: root.Window.window
            function onDevicePixelRatioChanged() {
                console.warn("!!! DPR CHANGED")
                Backpressure.debounce(root, 1000, function() {
                    const window = root.Window.window
                    const currentScreen = window.screen.name
                    const newDpr = SystemUtils.nativeDpr(window)
                    console.warn("!!! DPR CHANGED; OLD/NEW :", d.nativeWindowDpr, newDpr)
                    console.warn("!!! SCREENS:", d.screen, currentScreen)
                    if (!SystemUtils.fuzzyCompare(d.nativeWindowDpr, newDpr) && d.screen === currentScreen) {
                        console.warn("!!! RESTART POPUP")
                        popups.openDprChangedConfirmationPopup()
                    }
                    d.nativeWindowDpr = newDpr
                    d.screen = currentScreen
                })()
            }
        }
    }

    Component.onCompleted: {
        Backpressure.debounce(root, 50, function() {
            d.screen = root.Window.window.screen.name
            console.warn("!!! INITIAL SCREEN:", d.screen)
            d.nativeWindowDpr = SystemUtils.nativeDpr(root.Window.window)
            console.warn("!!! INITIAL DPR:", d.nativeWindowDpr)
            d.nativeWindowDprConn.enabled = true
        })()
    }

    PopupsLoader {
        id: popups
        keychain: Keychain {}
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}

        onRestartRequested: console.info("PopupsLoader.onRestartRequested")
    }

    AppearanceView {
        anchors.fill: parent
        anchors.topMargin: 80
        contentWidth: root.width * 4 / 5

        nativeWindowDpr: d.nativeWindowDpr

        theme: ThemeUtils.Style.System
        onThemeChangeRequested: function(theme) {
            console.info("AppearanceView.onThemeChangeRequested:", theme)
            this.theme = theme
        }

        onRestartRequested: console.info("AppearanceView.onRestartRequested")
    }
}

// category: Settings
// status: good
