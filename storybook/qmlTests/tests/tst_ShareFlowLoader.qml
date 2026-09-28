import QtQuick
import QtTest

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores

import mainui.sectionLoaders

Item {
    id: root
    width: 480
    height: 800

    Component {
        id: destinationsModelComponent

        ListModel {
            readonly property var data: [
                { chatId: "0x04me", name: "Me", color: "", colorId: 0, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: 1, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 2000, lastOwnMessageTimestamp: 2000 },
                { chatId: "0x04alice", name: "Alice", color: "", colorId: 1, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: 1, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 1000, lastOwnMessageTimestamp: 1000 },
                { chatId: "channel-pets", name: "pets", color: "#887af9", colorId: 4, icon: "", emoji: "🐶", sectionId: "community-1", sectionName: "Status", chatType: 6, membersCount: 0, onlineStatus: 0, canPost: true, lastMessageTimestamp: 900, lastOwnMessageTimestamp: 900 },
                { chatId: "channel-locked", name: "announcements", color: "#887af9", colorId: 4, icon: "", emoji: "📣", sectionId: "community-1", sectionName: "Status", chatType: 6, membersCount: 0, onlineStatus: 0, canPost: false, lastMessageTimestamp: 800, lastOwnMessageTimestamp: 0 }
            ]
            Component.onCompleted: append(data)
        }
    }

    Component {
        id: rootStoreComponent

        AppStores.RootStore {
            property bool sectionsLoaded: true
            property var chatSearchModel: null
            property var releasedPaths: []
            property var activatedChats: []

            function releaseShareIntakeFiles(imagePaths) {
                releasedPaths = releasedPaths.concat(imagePaths)
            }
            function setActiveSectionChat(sectionId, chatId) {
                activatedChats = activatedChats.concat([{ sectionId, chatId }])
            }
        }
    }

    Component {
        id: rootChatStoreComponent

        ChatStores.RootStore {
            property bool sendResult: true
            property var sends: []

            function sendSharedContent(destinations, text, imagePaths) {
                sends = sends.concat([{ destinations, text, imagePaths }])
                return sendResult
            }
        }
    }

    Component {
        id: loaderComponent

        ShareFlowLoader {
            excludedChatId: "0x04me"
            unlimitedImages: true
        }
    }

    TestCase {
        name: "ShareFlowLoader"
        when: windowShown

        property var rootStore
        property var rootChatStore
        property var loader

        function init() {
            const model = createTemporaryObject(destinationsModelComponent, root)
            rootStore = createTemporaryObject(rootStoreComponent, root, { chatSearchModel: model })
            rootChatStore = createTemporaryObject(rootChatStoreComponent, root)
            loader = createTemporaryObject(loaderComponent, root,
                                           { rootStore: rootStore, rootChatStore: rootChatStore })
        }

        function picker() {
            return findChild(loader.item, "shareFlowPicker")
        }

        function launchAndOpen(text, imagePaths) {
            loader.launch(text, imagePaths)
            tryVerify(() => !!loader.item && loader.item.opened)
            waitForRendering(picker())
        }

        function waitForUnload() {
            tryCompare(loader, "active", false)
            tryVerify(() => !loader.item)
        }

        function test_launchOpensPickerWithPayloadAndPostableDestinations() {
            verify(!loader.active)
            launchAndOpen("https://status.app", ["/cache/a.png"])
            compare(picker().text, "https://status.app")
            compare(picker().imagePaths, ["/cache/a.png"])
            compare(picker().unlimitedImages, true)
            // own chat and the channel without post rights are never offered
            compare(picker().model.rowCount(), 2)
            compare(rootStore.releasedPaths, [])
        }

        function test_cancelReleasesCachedImagesAndUnloads() {
            launchAndOpen("hello", ["/cache/a.png", "/cache/b.png"])
            picker().cancelRequested()
            compare(rootStore.releasedPaths, ["/cache/a.png", "/cache/b.png"])
            compare(rootChatStore.sends, [])
            waitForUnload()
        }

        function test_relaunchWhileOpenReplacesPayloadAndReleasesPreviousImages() {
            launchAndOpen("first", ["/cache/a.png"])
            const dialog = loader.item
            loader.launch("second", ["/cache/b.png"])
            compare(loader.item, dialog)
            verify(dialog.opened)
            compare(rootStore.releasedPaths, ["/cache/a.png"])
            compare(picker().text, "second")
            compare(picker().imagePaths, ["/cache/b.png"])
        }

        function test_sendLandsInFirstDestinationAndReleasesDetachedImages() {
            launchAndOpen("hi", ["/cache/a.png", "/cache/b.png"])
            const destinations = [{ sectionId: "community-1", chatId: "channel-pets" },
                                  { sectionId: "personal", chatId: "0x04alice" }]
            picker().sendRequested(destinations, "hi there", ["/cache/b.png"])
            compare(rootStore.activatedChats, [{ sectionId: "community-1", chatId: "channel-pets" }])
            compare(rootChatStore.sends.length, 1)
            compare(rootChatStore.sends[0].destinations, destinations)
            compare(rootChatStore.sends[0].text, "hi there")
            compare(rootChatStore.sends[0].imagePaths, ["/cache/b.png"])
            // the kept image is consumed by the send; only the detached one is released
            compare(rootStore.releasedPaths, ["/cache/a.png"])
            waitForUnload()
        }

        function test_failedSendReleasesKeptImages() {
            rootChatStore.sendResult = false
            launchAndOpen("hi", ["/cache/a.png"])
            picker().sendRequested([{ sectionId: "personal", chatId: "0x04alice" }], "hi", ["/cache/a.png"])
            compare(rootChatStore.sends.length, 1)
            compare(rootStore.releasedPaths, ["/cache/a.png"])
            waitForUnload()
        }

        function test_sendWithoutDestinationsActivatesNothing() {
            rootChatStore.sendResult = false
            launchAndOpen("hi", [])
            picker().sendRequested([], "hi", [])
            compare(rootStore.activatedChats, [])
            compare(rootStore.releasedPaths, [])
            waitForUnload()
        }

        function test_relaunchAfterCloseRebuildsTheDialog() {
            launchAndOpen("first", [])
            const dialog = loader.item
            picker().cancelRequested()
            waitForUnload()
            launchAndOpen("second", [])
            verify(loader.item !== dialog)
            compare(picker().text, "second")
        }
    }
}
