import QtQuick
import QtTest

import shared.panels

import mainui

Item {
    id: root
    width: 900
    height: 300

    Component {
        id: passwordBannerComponent
        ZeroOnboardingBanner {
            width: root.width
        }
    }

    Component {
        id: termsBannerComponent
        TermsOfUseBanner {
            width: root.width
        }
    }

    SignalSpy {
        id: spy
    }

    TestCase {
        name: "ZeroOnboardingBanner"
        when: windowShown

        function cleanup() {
            spy.target = null
            spy.clear()
        }

        function createBanner(component) {
            const banner = createTemporaryObject(component, root)
            verify(!!banner)
            banner.show()
            tryCompare(banner, "visible", true)
            return banner
        }

        function test_passwordBannerContent() {
            const banner = createBanner(passwordBannerComponent)
            compare(banner.type, ModuleWarning.Warning)
            compare(findChild(banner, "bannerText").visible, false)

            const setPassword = findChild(banner, "setPasswordButton")
            compare(setPassword.text, qsTr("Set password"))
            compare(setPassword.icon.name, "password")
            compare(findChild(banner, "orText").text, qsTr("or"))
            const createOrLogin = findChild(banner, "createOrLoginButton")
            compare(createOrLogin.text, qsTr("Create / Log in"))
            compare(createOrLogin.icon.name, "profile/contacts")
            verify(setPassword.mapToItem(banner, 0, 0).x < createOrLogin.mapToItem(banner, 0, 0).x)
        }

        function test_passwordBannerCollapses() {
            const banner = createBanner(passwordBannerComponent)
            verify(banner.collapsible)
            mouseClick(findChild(banner, "closeButton"))
            tryCompare(banner, "collapsed", true)
            verify(banner.active)
        }

        function test_passwordBannerButtons_data() {
            return [
                { tag: "set password", button: "setPasswordButton", signal: "setPasswordRequested" },
                { tag: "create or log in", button: "createOrLoginButton", signal: "createOrLoginRequested" },
            ]
        }
        function test_passwordBannerButtons(data) {
            const banner = createBanner(passwordBannerComponent)
            spy.target = banner
            spy.signalName = data.signal
            mouseClick(findChild(banner, data.button))
            compare(spy.count, 1)
        }

        function test_termsBannerContent() {
            const banner = createBanner(termsBannerComponent)
            compare(banner.type, ModuleWarning.Success)
            compare(banner.closeBtnVisible, false)
            compare(banner.collapsible, false)
            compare(findChild(banner, "closeButton").visible, false)
            compare(findChild(banner, "actionButton").visible, false)
            const termsText = findChild(banner, "termsText")
            const text = termsText.text
            verify(text.startsWith(qsTr("By using Status you accept the")))
            verify(text.includes(">" + qsTr("Terms of Use") + "</a>"))
            verify(text.includes(">" + qsTr("Privacy Policy") + "</a>"))
            verify(!text.includes("<style"))
        }

        // "Ok" follows the text instead of sitting at the banner's right edge
        function test_termsBannerOkAfterText() {
            const banner = createBanner(termsBannerComponent)
            const termsText = findChild(banner, "termsText")
            const ok = findChild(banner, "okButton")
            compare(ok.text, qsTr("Ok"))
            const textEnd = termsText.mapToItem(banner, termsText.width, 0).x
            const okStart = ok.mapToItem(banner, 0, 0).x
            verify(okStart >= textEnd)
            verify(okStart - textEnd <= 16)
        }

        function test_termsBannerOk() {
            const banner = createBanner(termsBannerComponent)
            spy.target = banner
            spy.signalName = "acceptRequested"
            mouseClick(findChild(banner, "okButton"))
            compare(spy.count, 1)
        }

        function test_termsBannerLinks_data() {
            return [
                { tag: "terms", link: "#terms", signal: "termsOfUseRequested" },
                { tag: "privacy", link: "#privacy", signal: "privacyPolicyRequested" },
            ]
        }
        function test_termsBannerLinks(data) {
            const banner = createBanner(termsBannerComponent)
            spy.target = banner
            spy.signalName = data.signal
            banner.linkActivated(data.link)
            compare(spy.count, 1)
        }
    }
}
