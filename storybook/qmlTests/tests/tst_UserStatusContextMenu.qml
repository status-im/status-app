import QtQuick
import QtTest

import Models
import shared.popups
import utils

Item {
    id: root
    width: 500
    height: 700

    Component {
        id: menuComponent

        UserStatusContextMenu {
            compressedPubKey: "zxcvdeadbeef"
            emojiHash: []
            name: "Alice"
            headerIcon: ""
            colorId: 0
            usesDefaultName: true
            bio: "Test bio"
            isMobile: false
            currentUserStatus: Constants.currentUserStatus.automatic
            directParent: root
        }
    }

    SignalSpy {
        id: viewProfileSpy
        signalName: "viewProfileRequested"
    }

    SignalSpy {
        id: copyLinkSpy
        signalName: "copyLinkRequested"
    }

    SignalSpy {
        id: shareProfileSpy
        signalName: "shareOwnProfileRequested"
    }

    SignalSpy {
        id: settingsSpy
        signalName: "settingsRequested"
    }

    SignalSpy {
        id: statusSpy
        signalName: "setCurrentUserStatusRequested"
    }

    SignalSpy {
        id: quitSpy
        signalName: "quitRequested"
    }

    TestCase {
        name: "UserStatusContextMenu"
        when: windowShown

        property var menuUnderTest: null

        function cleanup() {
            if (menuUnderTest) {
                menuUnderTest.close()
                menuUnderTest.destroy()
                menuUnderTest = null
            }

            viewProfileSpy.target = null
            copyLinkSpy.target = null
            shareProfileSpy.target = null
            settingsSpy.target = null
            statusSpy.target = null
            quitSpy.target = null
            viewProfileSpy.clear()
            copyLinkSpy.clear()
            shareProfileSpy.clear()
            settingsSpy.clear()
            statusSpy.clear()
            quitSpy.clear()
        }

        function createMenu(props) {
            menuUnderTest = createTemporaryObject(menuComponent, root, props || {})
            verify(!!menuUnderTest, "Component exists")
            menuUnderTest.open()
            tryCompare(menuUnderTest, "opened", true)
            return menuUnderTest
        }

        function findAction(menu, objectName) {
            return findChild(menu, objectName)
        }

        function triggerAction(menu, objectName) {
            const action = findAction(menu, objectName)
            verify(!!action)
            action.action.trigger()
            return action
        }

        function test_desktopAndMobileActionsMatchPlatform() {
            let menu = createMenu({ isMobile: false })
            let copyLinkAction = findAction(menu, "userStatusCopyLinkAction")
            let shareAction = findAction(menu, "userStatusShareProfileAction")
            verify(!!copyLinkAction)
            verify(!!shareAction)
            compare(copyLinkAction.visible, true)
            compare(copyLinkAction.text, qsTr("Copy link to profile"))
            compare(shareAction.visible, false)

            menu.close()
            tryCompare(menu, "opened", false)
            menu.destroy()
            menuUnderTest = null

            menu = createMenu({ isMobile: true })
            copyLinkAction = findAction(menu, "userStatusCopyLinkAction")
            shareAction = findAction(menu, "userStatusShareProfileAction")
            verify(!!copyLinkAction)
            verify(!!shareAction)
            compare(copyLinkAction.visible, false)
            compare(shareAction.visible, true)
            compare(shareAction.text, qsTr("Invite contacts"))
        }

        function test_headerIconAndDefaultNameUpdateUserImage() {
            const menu = createMenu({
                headerIcon: "",
                usesDefaultName: true
            })
            const userImage = findChild(menu, "userStatusImage")
            verify(!!userImage, "Object exists")
            compare(userImage.image, "")
            compare(userImage.usesDefaultName, true)
            tryCompare(userImage, "status", Loader.Ready)
            compare(userImage.item.asset.name, "contact")
            compare(userImage.item.asset.isImage, false)

            menu.headerIcon = ModelsData.icons.cryptPunks
            menu.usesDefaultName = false
            tryCompare(userImage, "image", ModelsData.icons.cryptPunks)
            tryCompare(userImage, "usesDefaultName", false)
            tryCompare(userImage.item.asset, "name", ModelsData.icons.cryptPunks)
            tryCompare(userImage.item.asset, "isImage", true)
        }

        function test_viewProfileActionEmitsRequested() {
            const menu = createMenu()
            viewProfileSpy.target = menu
            viewProfileSpy.clear()

            triggerAction(menu, "userStatusViewMyProfileAction")

            tryCompare(viewProfileSpy, "count", 1)
            tryCompare(menu, "opened", false)
        }

        function test_copyLinkActionEmitsRequested() {
            const menu = createMenu()
            copyLinkSpy.target = menu
            copyLinkSpy.clear()

            triggerAction(menu, "userStatusCopyLinkAction")

            tryCompare(copyLinkSpy, "count", 1)
            tryCompare(menu, "opened", false)
        }

        function test_shareProfileActionEmitsRequested() {
            const menu = createMenu({ isMobile: true })
            shareProfileSpy.target = menu
            shareProfileSpy.clear()

            triggerAction(menu, "userStatusShareProfileAction")

            tryCompare(shareProfileSpy, "count", 1)
            tryCompare(menu, "opened", false)
        }

        function test_settingsActionEmitsRequested() {
            const menu = createMenu()
            settingsSpy.target = menu
            settingsSpy.clear()

            triggerAction(menu, "userStatusSettingsAction")

            tryCompare(settingsSpy, "count", 1)
            tryCompare(menu, "opened", false)
        }

        function test_statusActionEmitsSelectedStatus() {
            const menu = createMenu()
            statusSpy.target = menu
            statusSpy.clear()

            const automaticAction = findAction(menu, "userStatusMenuAutomaticAction")
            verify(!!automaticAction)
            compare(automaticAction.checked, true)

            triggerAction(menu, "userStatusMenuAlwaysOnlineAction")

            tryCompare(statusSpy, "count", 1)
            compare(statusSpy.signalArguments[0][0], Constants.currentUserStatus.alwaysOnline)
            tryCompare(menu, "opened", false)
        }

        function test_statusActionsReflectCurrentUserStatus_data() {
            return [
                {
                    tag: "unknown",
                    status: Constants.currentUserStatus.unknown,
                    automatic: false,
                    alwaysOnline: false,
                    inactive: false
                },
                {
                    tag: "automatic",
                    status: Constants.currentUserStatus.automatic,
                    automatic: true,
                    alwaysOnline: false,
                    inactive: false
                },
                {
                    tag: "always online",
                    status: Constants.currentUserStatus.alwaysOnline,
                    automatic: false,
                    alwaysOnline: true,
                    inactive: false
                },
                {
                    tag: "inactive",
                    status: Constants.currentUserStatus.inactive,
                    automatic: false,
                    alwaysOnline: false,
                    inactive: true
                }
            ]
        }

        function test_statusActionsReflectCurrentUserStatus(data) {
            const menu = createMenu({ currentUserStatus: data.status })

            compare(findAction(menu, "userStatusMenuAutomaticAction").checked, data.automatic)
            compare(findAction(menu, "userStatusMenuAlwaysOnlineAction").checked, data.alwaysOnline)
            compare(findAction(menu, "userStatusMenuInactiveAction").checked, data.inactive)
        }

        function test_quitActionEmitsRequested() {
            const menu = createMenu()
            quitSpy.target = menu
            quitSpy.clear()

            triggerAction(menu, "userStatusQuitAction")

            tryCompare(quitSpy, "count", 1)
            tryCompare(menu, "opened", false)
        }
    }
}
