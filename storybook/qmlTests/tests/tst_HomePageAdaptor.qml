import QtCore
import QtQuick
import QtTest

import Models
import Storybook
import Storybook.Testing

import StatusQ.Core.Utils as SQUtils

import QtModelsToolkit

import AppLayouts.HomePage

import utils

import "homePageAdaptorGolden.js" as Golden

Item {
    id: root

    readonly property var snapshotRoles: [
        "key", "id", "sectionType", "name", "icon", "color", "banner", "hasNotification",
        "notificationsCount", "enabled", "chatType", "onlineStatus", "lastMessageText", "sectionName",
        "members", "activeMembers", "pending", "banned", "isExperimental", "walletType",
        "currencyBalance", "connectorBadge", "pinned", "timestamp"
    ]

    function uniqueProfileId() {
        return "tst_HomePageAdaptor_" + Date.now() + "_" + Math.floor(Math.random() * 1e9)
    }

    Component {
        id: mockAdaptorComponent

        HomePageAdaptor {
            sectionsBaseModel: SectionsModel {}
            chatsBaseModel: ChatsModel {}
            chatsSearchBaseModel: ChatsSearchModel {}
            walletsBaseModel: WalletAccountsModel {}
            dappsBaseModel: DappsModel {}

            syncingBadgeCount: 2
            messagingBadgeCount: 4
            showBackUpSeed: true
            backUpSeedBadgeCount: 1
            keycardEnabled: true

            searchPhrase: ""
            profileId: root.uniqueProfileId()
        }
    }

    Component {
        id: generatedChatsComponent

        ListModel {
            property int rowsToGenerate: 0

            Component.onCompleted: {
                for (let i = 0; i < rowsToGenerate; i++)
                    append({
                        itemId: "gen" + i, type: 1, name: "Chat " + i, emoji: "", icon: "", color: "",
                        colorId: i % 10, hasUnreadMessages: false, notificationsCount: 0, onlineStatus: 0,
                        lastMessageText: "", isCategory: false
                    })
            }
        }
    }

    Component {
        id: emptyModelComponent
        ListModel {}
    }

    Component {
        id: scaledAdaptorComponent

        HomePageAdaptor {
            sectionsBaseModel: emptyModelComponent.createObject(this)
            chatsSearchBaseModel: emptyModelComponent.createObject(this)
            walletsBaseModel: emptyModelComponent.createObject(this)
            dappsBaseModel: emptyModelComponent.createObject(this)

            syncingBadgeCount: 0
            messagingBadgeCount: 0
            showBackUpSeed: false
            backUpSeedBadgeCount: 0
            keycardEnabled: false

            searchPhrase: ""
            profileId: root.uniqueProfileId()
        }
    }

    Component {
        id: settingsComponent
        Settings {}
    }

    ObjectCounter {
        id: objectCounter
    }

    TestCase {
        name: "HomePageAdaptor"

        function digest(str) {
            let h = 5381
            for (let i = 0; i < str.length; i++)
                h = ((h * 33) ^ str.charCodeAt(i)) >>> 0
            return "len" + str.length + ":" + h.toString(16)
        }

        function normalize(role, value) {
            if (value === undefined || value === null)
                return null
            if (typeof value === "string" && value.length > 120)
                return digest(value)
            if (role === "connectorBadge") // url vs string
                return decodeURI(String(value))
            if (role === "color")
                return value === "" ? "" : Qt.lighter(value, 1.0).toString()
            if (typeof value === "object")
                return String(value)
            return value
        }

        function snapshot(model) {
            const rows = []
            const count = model.ModelCount.count
            for (let i = 0; i < count; i++) {
                const row = {}
                for (const role of root.snapshotRoles)
                    row[role] = normalize(role, SQUtils.ModelUtils.get(model, i, role))
                rows.push(row)
            }
            return rows
        }

        function keys(model) {
            return SQUtils.ModelUtils.modelToFlatArray(model, "key")
        }

        function createAdaptor(props) {
            const adaptor = createTemporaryObject(mockAdaptorComponent, root, props || {})
            verify(!!adaptor)
            tryVerify(() => !!adaptor.homePageEntriesModel)
            return adaptor
        }

        function compareRows(actual, expected) {
            if (Golden.dump)
                return
            compare(actual.length, expected.length)
            for (let i = 0; i < expected.length; i++)
                compare(JSON.stringify(actual[i]), JSON.stringify(expected[i]), "row " + i)
        }

        function compareJson(actual, expected) {
            if (Golden.dump)
                return
            compare(JSON.stringify(actual), JSON.stringify(expected))
        }

        function dumpIfRequested(tag, value) {
            if (Golden.dump)
                console.warn("GOLDEN", tag, JSON.stringify(value))
        }

        function test_defaultEntries() {
            const adaptor = createAdaptor()
            const rows = snapshot(adaptor.homePageEntriesModel)
            dumpIfRequested("defaultEntries", rows)
            compareRows(rows, Golden.defaultEntries)
            compare(adaptor.pinnedModel.ModelCount.count, 0)
        }

        function applyInteractions(adaptor) {
            adaptor.setTimestamp("2;id1", 1000)
            adaptor.setTimestamp("1;0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884", 3000)
            adaptor.setTimestamp("3;id106", 2000)
            adaptor.setPinned("3;id106", true)
            adaptor.setPinned("2;id1", true)
            adaptor.setTimestamp("4;1", 500)
            adaptor.setPinned("4;1", true)
            adaptor.setPinned("4;1", false)
            adaptor.setPinned("non;existing", true)
        }

        function test_interactions() {
            const adaptor = createAdaptor()
            applyInteractions(adaptor)

            tryCompare(adaptor.pinnedModel.ModelCount, "count", 2)
            const rows = snapshot(adaptor.homePageEntriesModel)
            const pinned = snapshot(adaptor.pinnedModel)
            dumpIfRequested("interactionEntries", rows)
            dumpIfRequested("interactionPinned", pinned)
            compareRows(rows, Golden.interactionEntries)
            compareRows(pinned, Golden.interactionPinned)
        }

        function test_search_data() {
            return [
                { tag: "a", searchPhrase: "a", showAllChats: false },
                { tag: "chan", searchPhrase: "chan", showAllChats: false },
                { tag: "welcome", searchPhrase: "welcome", showAllChats: false },
                { tag: "allChats", searchPhrase: "", showAllChats: true },
                { tag: "nothing", searchPhrase: "zzzzzz", showAllChats: false },
            ]
        }

        function test_search(data) {
            const adaptor = createAdaptor({ searchPhrase: data.searchPhrase, showAllChats: data.showAllChats })
            const k = keys(adaptor.homePageEntriesModel)
            dumpIfRequested("search_" + data.tag, k)
            compareJson(k, Golden["search_" + data.tag])
        }

        function test_visibilityFlags() {
            const adaptor = createAdaptor({ showCommunities: false, showWallets: false, showDapps: false })
            const k = keys(adaptor.homePageEntriesModel)
            dumpIfRequested("visibilityFlags", k)
            compareJson(k, Golden.visibilityFlags)
        }

        function test_saveLoadRoundtrip() {
            const profileId = root.uniqueProfileId()
            const first = createAdaptor({ profileId })
            applyInteractions(first)
            tryCompare(first.pinnedModel.ModelCount, "count", 2)
            const expectedEntries = snapshot(first.homePageEntriesModel)
            const expectedPinned = snapshot(first.pinnedModel)
            first.destroy() // saves
            tryVerify(() => first.homePageEntriesModel === undefined)

            const second = createAdaptor({ profileId })
            tryCompare(second.pinnedModel.ModelCount, "count", 2)
            compareRows(snapshot(second.homePageEntriesModel), expectedEntries)
            compareRows(snapshot(second.pinnedModel), expectedPinned)
            second.clear()
        }

        function storedEntries(profileId) {
            const settings = createTemporaryObject(settingsComponent, root, { category: "HomePage_" + profileId })
            return JSON.parse(settings.value("HomePageEntries"))
        }

        // saved data: every present row with key/timestamp/pinned (format kept)
        function test_savedFormat() {
            const profileId = root.uniqueProfileId()
            const adaptor = createAdaptor({ profileId, showAllChats: true }) // all rows visible
            applyInteractions(adaptor)
            const rowCount = adaptor.homePageEntriesModel.ModelCount.count
            adaptor.save()

            const stored = storedEntries(profileId)
            compare(stored.length, rowCount)
            for (const entry of stored)
                compare(JSON.stringify(Object.keys(entry).sort()), JSON.stringify(["key", "pinned", "timestamp"]))

            const fab = stored.find(e => e.key === "1;0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884")
            compare(fab.timestamp, 3000)
            compare(fab.pinned, false)
            compare(stored.find(e => e.key === "2;id1").pinned, true)
            adaptor.clear()
        }

        // stored entries for keys not present when loading are dropped
        function test_loadIgnoresAbsentKeys() {
            const profileId = root.uniqueProfileId()
            const settings = createTemporaryObject(settingsComponent, root, { category: "HomePage_" + profileId })
            settings.setValue("HomePageEntries", JSON.stringify([
                { key: "2;id1", timestamp: 1000, pinned: true },
                { key: "2;gone", timestamp: 2000, pinned: true }
            ]))
            settings.sync()

            const adaptor = createAdaptor({ profileId })
            tryCompare(adaptor.pinnedModel.ModelCount, "count", 1)
            compare(SQUtils.ModelUtils.get(adaptor.pinnedModel, 0, "key"), "2;id1")

            adaptor.save()
            const stored = storedEntries(profileId)
            verify(!stored.some(e => e.key === "2;gone"))
            adaptor.clear()
        }

        function test_clear() {
            const adaptor = createAdaptor()
            applyInteractions(adaptor)
            tryCompare(adaptor.pinnedModel.ModelCount, "count", 2)
            adaptor.clear()
            tryCompare(adaptor.pinnedModel.ModelCount, "count", 0)
            compareRows(snapshot(adaptor.homePageEntriesModel), Golden.defaultEntries)
        }

        function test_sourceChangesPropagate() {
            const adaptor = createAdaptor()
            applyInteractions(adaptor)
            tryCompare(adaptor.pinnedModel.ModelCount, "count", 2)

            const chats = adaptor.chatsBaseModel
            const idx = SQUtils.ModelUtils.indexOf(chats, "itemId", "id1")
            verify(idx >= 0)

            // rename a pinned chat; overlay data must follow the row
            chats.setProperty(idx, "name", "Renamed chat")
            tryVerify(() => SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;id1", "name") === "Renamed chat")
            compare(SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;id1", "pinned"), true)
            compare(SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;id1", "timestamp"), 1000)

            // insert a new chat before the pinned one
            chats.insert(0, { itemId: "new1", type: 1, name: "AAA new chat", emoji: "", icon: "", color: "",
                              colorId: 1, hasUnreadMessages: true, notificationsCount: 3, onlineStatus: 0,
                              lastMessageText: "hi", isCategory: false })
            tryVerify(() => SQUtils.ModelUtils.indexOf(adaptor.homePageEntriesModel, "key", "2;new1") >= 0)
            compare(SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;new1", "pinned"), false)
            compare(SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;new1", "hasNotification"), true)
            compare(SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;id1", "pinned"), true)

            const afterInsert = keys(adaptor.homePageEntriesModel)
            dumpIfRequested("afterInsert", afterInsert)
            compareJson(afterInsert, Golden.afterInsert)

            // remove it again
            chats.remove(0)
            tryVerify(() => SQUtils.ModelUtils.indexOf(adaptor.homePageEntriesModel, "key", "2;new1") < 0)
            compare(SQUtils.ModelUtils.getByKey(adaptor.homePageEntriesModel, "key", "2;id1", "pinned"), true)
            compare(adaptor.pinnedModel.ModelCount.count, 2)
            adaptor.clear()
        }

        function createScaledAdaptor(chatsCount) {
            const chats = createTemporaryObject(generatedChatsComponent, root, { rowsToGenerate: chatsCount })
            const adaptor = createTemporaryObject(scaledAdaptorComponent, root, { chatsBaseModel: chats })
            tryVerify(() => !!adaptor.homePageEntriesModel)
            compare(adaptor.homePageEntriesModel.ModelCount.count >= chatsCount, true)
            return adaptor
        }

        function liveProxyRowsFor(chatsCount) {
            objectCounter.start()
            const adaptor = createScaledAdaptor(chatsCount)

            // typical use: open and search
            adaptor.searchPhrase = "1"
            adaptor.searchPhrase = ""

            const result = objectCounter.count("QQmlPropertyMap")
            adaptor.destroy()
            objectCounter.stop()
            return result
        }

        // Opening Home with N chats must not create a per-row QObject (OPM proxy) for every row
        function test_noPerRowProxyObjects() {
            const baseline = liveProxyRowsFor(0)
            const scaled = liveProxyRowsFor(200)
            compare(scaled - baseline, 0, "per-row proxy objects: baseline " + baseline + ", with 200 chats " + scaled)
        }

        function test_pinAndActivateWithManyChats() {
            const adaptor = createScaledAdaptor(200)
            adaptor.setTimestamp("2;gen150", 1000)
            adaptor.setPinned("2;gen150", true)
            tryCompare(adaptor.pinnedModel.ModelCount, "count", 1)
            compare(SQUtils.ModelUtils.get(adaptor.homePageEntriesModel, 0, "key"), "2;gen150")
            adaptor.clear()
        }
    }
}
