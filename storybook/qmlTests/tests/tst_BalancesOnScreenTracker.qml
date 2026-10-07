import QtQuick
import QtQuick.Window
import QtTest

import utils
import mainui

Item {
    id: root
    width: 100
    height: 100

    Component {
        id: trackerComponent
        BalancesOnScreenTracker {
            sectionType: Constants.appSection.wallet
            isMobile: false
            applicationState: Qt.ApplicationActive
            windowVisibility: Window.Windowed
            popupOpen: false
            leaveDelay: 20
        }
    }

    SignalSpy {
        id: onScreenSpy
        signalName: "onScreenChanged"
    }

    TestCase {
        name: "BalancesOnScreenTracker"
        when: windowShown

        property BalancesOnScreenTracker tracker

        function init() {
            tracker = createTemporaryObject(trackerComponent, root)
            onScreenSpy.target = tracker
            onScreenSpy.clear()
        }

        function test_walletSectionsAreOnScreen_data() {
            return [
                { tag: "wallet", section: Constants.appSection.wallet, onScreen: true },
                { tag: "swap", section: Constants.appSection.swap, onScreen: true },
                { tag: "market", section: Constants.appSection.market, onScreen: true },
                { tag: "browser", section: Constants.appSection.browser, onScreen: true },
                { tag: "dApp", section: Constants.appSection.dApp, onScreen: true },
                { tag: "chat", section: Constants.appSection.chat, onScreen: false },
                { tag: "profile", section: Constants.appSection.profile, onScreen: false }
            ]
        }

        function test_walletSectionsAreOnScreen(data) {
            tracker.sectionType = data.section
            tryCompare(tracker, "onScreen", data.onScreen)
        }

        function test_startsOffScreenOutsideTheWallet() {
            const chat = createTemporaryObject(trackerComponent, root, { sectionType: Constants.appSection.chat })
            compare(chat.onScreen, false)
        }

        function test_balancesPopupIsOnScreenInAnySection() {
            tracker.sectionType = Constants.appSection.chat
            tryCompare(tracker, "onScreen", false)

            tracker.popupOpen = true
            compare(tracker.onScreen, true)

            tracker.popupOpen = false
            tryCompare(tracker, "onScreen", false)
        }

        function test_desktopWindowBehindOthersIsStillOnScreen_data() {
            return [
                { tag: "windowed", visibility: Window.Windowed, onScreen: true },
                { tag: "maximized", visibility: Window.Maximized, onScreen: true },
                { tag: "full screen", visibility: Window.FullScreen, onScreen: true },
                { tag: "minimized", visibility: Window.Minimized, onScreen: false },
                { tag: "hidden", visibility: Window.Hidden, onScreen: false }
            ]
        }

        function test_desktopWindowBehindOthersIsStillOnScreen(data) {
            tracker.applicationState = Qt.ApplicationInactive
            tracker.windowVisibility = data.visibility
            tryCompare(tracker, "onScreen", data.onScreen)
        }

        function test_mobileAppInTheBackgroundIsOffScreen() {
            tracker.isMobile = true
            compare(tracker.onScreen, true)

            tracker.applicationState = Qt.ApplicationSuspended
            tryCompare(tracker, "onScreen", false)
        }

        function test_shortInterruptionChangesNothing() {
            tracker.leaveDelay = 60000
            tracker.isMobile = true

            tracker.applicationState = Qt.ApplicationInactive
            tracker.applicationState = Qt.ApplicationActive

            compare(tracker.onScreen, true)
            verify(!tracker.leaveTimer.running)
            compare(onScreenSpy.count, 0)
        }

        function test_comingBackIsImmediate() {
            tracker.sectionType = Constants.appSection.chat
            tryCompare(tracker, "onScreen", false)

            tracker.leaveDelay = 60000
            tracker.sectionType = Constants.appSection.wallet
            compare(tracker.onScreen, true)
        }
    }
}
