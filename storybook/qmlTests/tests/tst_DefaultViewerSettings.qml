import QtQuick
import QtTest

import AppLayouts.Profile.views.browser

import utils

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: settingsComponent

        DefaultViewerSettings {
            property var platform: []
            property int resets: 0
            property int reads: 0

            width: 600
            typesFn: () => { reads++; return platform }
            resetFn: () => { resets++; platform = []; return true }
        }
    }

    Component {
        id: platformSettingsComponent

        DefaultViewerSettings {}
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }

    TestCase {
        name: "DefaultViewerSettings"
        when: windowShown

        function makeSettings(props) {
            return createTemporaryObject(settingsComponent, root, props ?? {})
        }

        // The desktop opens no type by default and has nothing to reset.
        function test_thePlatformIsReachedAndListsNothingHere() {
            const settings = createTemporaryObject(platformSettingsComponent, root)
            compare(settings.typesFn(), [])
            compare(settings.resetFn(), true)
            compare(settings.types, [])
        }

        function test_theSwitchShowsAndChangesTheUsersChoice() {
            const settings = makeSettings({ suggested: false })
            const toggled = createTemporaryObject(signalSpy, root, { target: settings, signalName: "suggestedToggled" })
            const toggle = findChild(settings, "suggestDefaultViewerSwitch")
            verify(!toggle.checked)
            mouseClick(toggle)
            compare(toggled.count, 1)
            compare(toggled.signalArguments[0][0], true)
        }

        function test_noTypesRowWhileStatusOpensNoType() {
            const settings = makeSettings()
            verify(!findChild(settings, "defaultViewerTypesItem").visible)
        }

        function test_namesEachTypeStatusOpensOnce() {
            const settings = makeSettings({ platform: ["application/pdf", "audio/mpeg", "audio/mp3"] })
            const item = findChild(settings, "defaultViewerTypesItem")
            verify(item.visible)
            compare(item.subTitle, "PDFs, MP3 audio")
        }

        function test_namesBitmapsAndJsonLikeTheirSiblings() {
            compare(DefaultViewerTypes.names(["application/json", "image/x-ms-bmp", "image/bmp"]),
                    "JSON files, BMP images")
        }

        function test_stoppingResetsAndHidesTheTypes() {
            const settings = makeSettings({ platform: ["image/png"] })
            mouseClick(findChild(settings, "resetDefaultViewerButton"))
            compare(settings.resets, 1)
            compare(settings.types, [])
            verify(!findChild(settings, "defaultViewerTypesItem").visible)
        }

        function test_comingBackToTheAppDoesNotAskThePlatformAgain() {
            const settings = makeSettings()
            const reads = settings.reads
            settings.applicationActivated()
            compare(settings.reads, reads)
        }

        function test_comingBackFromStopReadsTheTypesAgain() {
            const settings = makeSettings({ platform: ["image/png"] })
            mouseClick(findChild(settings, "resetDefaultViewerButton"))
            settings.platform = ["text/plain"]
            settings.applicationActivated()
            compare(settings.types, ["text/plain"])
            const reads = settings.reads
            settings.applicationActivated()
            compare(settings.reads, reads)
        }

        function test_showingThePageReadsTheTypesAgain() {
            const settings = makeSettings()
            settings.visible = false
            settings.platform = ["text/plain"]
            settings.visible = true
            compare(settings.types, ["text/plain"])
        }

        function test_readsTheTypesAgainOnRefresh() {
            const settings = makeSettings()
            settings.platform = ["text/plain"]
            settings.refresh()
            compare(DefaultViewerTypes.names(settings.types), "text files")
        }
    }
}
