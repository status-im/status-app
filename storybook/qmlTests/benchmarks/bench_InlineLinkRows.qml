import QtQuick
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme

import Storybook.Testing

import utils
import shared.views.chat
import AppLayouts.Chat.stores as ChatStores

/*
  Cost of inline deep links on real MessageView rows, dressed the way
  ChatMessagesView dresses pooled rows (context bindings, then RowBinder).

  Kinds: plain (text only), url (text with an external URL), profile (text
  with a profile link of a known contact), channel (text with a community
  channel link resolved by the store).

  Per kind, over `rows` rows, median of `reps`:
    build     first dress of fresh rows, until the next frame (deferred
              resolution included)
    rebind    rows of the kind dressed with other messages of the same kind
  as ms per row, plus the QObjects a dressed row holds.

  Run:
    QmlTests -platform offscreen -maxwarnings 0 -input bench_InlineLinkRows.qml
*/
Item {
    id: root

    width: 800
    height: 600

    readonly property int rows: 64
    readonly property int reps: 7
    readonly property var kinds: ["plain", "url", "profile", "channel"]

    readonly property string profileUrl: "https://status.app/u#zQ3shwQPhRuDJSjVGVBnTjCdgXy5i9WQaeVPdGJD6yTarJQSj"
    readonly property string channelUrl: "https://status.app/cc/G00AAAA#zQ3shchannelkey"
    readonly property string externalUrl: "https://example.com/some/page"

    readonly property ChatTextAppearance textAppearance: MessageTextAppearance { theme: root.Theme }
    readonly property ChatTextAppearance previewAppearance: ReplyTextAppearance { theme: root.Theme }

    ListModel {
        id: contacts
        ListElement { pubKey: "profile-key"; displayName: "JohnDoe.ETH"; preferredDisplayName: "JohnDoe.ETH"; thumbnailImage: "" }
    }

    ChatStores.RootStore {
        id: rootStoreMock
        contactsModel: contacts
    }

    ChatStores.MessageStore {
        id: messageStoreMock

        profileUrlResolver: QtObject {
            signal profileUrlsResolved(string profilesJson)
            function releaseProfileUrls(urlsJson) {}
            function resolveProfileUrls(urlsJson) {
                const profiles = {}
                for (const url of JSON.parse(urlsJson))
                    profiles[url] = {publicKey: "profile-key", displayName: ""}
                return JSON.stringify(profiles)
            }
        }

        function parseInlineLink(url) {
            if (!url.startsWith(root.channelUrl))
                return null
            return {url, kind: "channel", communityId: "community-1", chatId: "community-1chan",
                    communityName: "Status", chatName: "general"}
        }

        function resolveInlineLink(target) {
            return Object.assign({}, target)
        }
    }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.communityChat
            readonly property bool canPostReactions: true
        }
    }

    ListModel { id: noPreviews }
    ListModel { id: messages }
    ObjectCounter { id: objects }

    Component {
        id: rowComponent
        MessageView {}
    }

    Component {
        id: binderComponent
        RowBinder {}
    }

    Column {
        id: column
        width: 600
    }

    readonly property var context: ({
        rootStore: rootStoreMock,
        messageStore: messageStoreMock,
        chatContentModule: chatContentModuleMock,
        textAppearance: root.textAppearance,
        previewAppearance: root.previewAppearance,
        joined: true,
        isChatBlocked: false,
        myPublicKey: "0xme",
        stickersLoaded: false
    })

    function makeMessage(kind, i) {
        const ts = 1760000000000 - i * 3600000
        const words = []
        for (let w = 0; w < 4 + (i * 7) % 24; ++w)
            words.push(["chat", "message", "about", "the", "release", "plan", "today"][(i + w) % 7])
        const half = Math.ceil(words.length / 2)
        // Every message links somewhere else, so a rebind never finds the
        // previous message's link already resolved.
        const link = kind === "url" ? root.externalUrl + i
                   : kind === "profile" ? root.profileUrl + i
                   : kind === "channel" ? root.channelUrl + i : ""
        const text = link ? words.slice(0, half).join(" ") + " " + link + " " + words.slice(half).join(" ")
                          : words.join(" ")

        const sender = "0xpeer" + (i % 7)
        return {
            messageId: kind + "-" + i,
            senderId: sender,
            senderDisplayName: "Peer " + (i % 7),
            senderIcon: "",
            senderColorId: i % 12,
            amISender: false,
            messageTimestamp: ts,
            messageContentType: Constants.messageContentType.messageType,
            unparsedText: text,
            messageOutgoingStatus: "",
            prevMessageSenderId: "0xother",
            prevMessageTimestamp: ts - 3600000,
            prevMessageContentType: Constants.messageContentType.messageType,
            prevMessageDeleted: false,
            prevMessageIndex: i + 1,
            nextMessageIndex: i - 1,
            nextMessageTimestamp: ts + 3600000,
            responseToMessageWithId: "",
            reactionsModel: [],
            linkPreviewModel: noPreviews,
            pinnedMessage: false,
            messagePinnedBy: "",
            messageImage: "",
            albumMessageImages: "",
            albumCount: 0,
            isEdited: false
        }
    }

    property var ranges: ({})

    function fillModel() {
        messages.clear()
        let first = 0
        const all = []
        const ranges = {}
        for (const kind of root.kinds) {
            ranges[kind] = first
            for (let i = 0; i < root.rows * 4; ++i)
                all.push(makeMessage(kind, first + i))
            first += root.rows * 4
        }
        messages.append(all)
        root.ranges = ranges
    }

    function median(values) {
        const v = values.slice().sort((a, b) => a - b)
        const n = v.length
        return n % 2 ? v[(n - 1) / 2] : (v[n / 2 - 1] + v[n / 2]) / 2
    }

    TestCase {
        id: bench

        name: "Bench"
        when: windowShown

        property var items: []
        property var binders: []

        function create() {
            const items = []
            const binders = []
            for (let i = 0; i < root.rows; ++i) {
                const item = rowComponent.createObject(null)
                items.push(item)
                binders.push(binderComponent.createObject(item, { target: item }))
            }
            bench.items = items
            bench.binders = binders
        }

        function destroyRows() {
            for (const item of bench.items)
                item.destroy()
            bench.items = []
            bench.binders = []
            wait(0)
            gc()
            wait(0)
        }

        function dress(i, modelRow, fresh) {
            const item = bench.items[i]
            if (fresh) {
                for (const name in root.context)
                    item[name] = Qt.binding(() => root.context[name])
            }
            bench.binders[i].bind(messages, modelRow)
            if (fresh) {
                item.width = Qt.binding(() => column.width)
                item.parent = column
            }
        }

        function findVisible(item, test) {
            if (!item || !item.visible)
                return null
            if (test(item))
                return item
            for (let i = 0; i < item.children.length; ++i) {
                const found = findVisible(item.children[i], test)
                if (found)
                    return found
            }
            return null
        }

        function textItem(item) {
            return findVisible(item, i => i.objectName === "StatusTextMessage_chatText")
        }

        // Each kind shows what it measures: a pill that silently fails to
        // resolve would otherwise just look cheap.
        function verifyKind(kind, item) {
            const text = textItem(item)
            verify(!!text, kind + ": text shown")
            // A baseline without inline links has no inlineIconOffsets.
            if (text.segments.length && text.segments[0].inlineIconOffsets === undefined)
                return
            const pill = text.segments.some(segment => segment.inlineIconOffsets.length > 0)
            if (kind === "profile" || kind === "channel")
                verify(pill, kind + ": pill shown")
            else
                verify(!pill, kind + ": no pill")
        }

        // Deferred (Qt.callLater) resolution and the next frame included.
        function timed(op) {
            const t0 = Date.now()
            op()
            wait(0)
            waitForRendering(column, 5000)
            return Date.now() - t0
        }

        function bindRows(kind, round, fresh) {
            const first = root.ranges[kind] + (round % 4) * root.rows
            for (let i = 0; i < root.rows; ++i)
                dress(i, first + i, fresh)
        }

        function measureKind(kind) {
            const result = {}
            const build = []
            for (let rep = 0; rep < root.reps; ++rep) {
                const last = rep === root.reps - 1
                if (last)
                    objects.start()
                create()
                build.push(timed(() => bindRows(kind, rep, true)))
                wait(50)
                if (rep === 0)
                    verifyKind(kind, bench.items[0])
                if (last) {
                    result.qobjects = Math.round(objects.count("QObject") / root.rows)
                    result.histogram = objects.histogram()
                    objects.stop()
                } else {
                    destroyRows()
                }
            }
            result.build = median(build) / root.rows

            const rebind = []
            for (let round = 1; round <= root.reps; ++round)
                rebind.push(timed(() => bindRows(kind, round, false)))
            result.rebind = median(rebind) / root.rows
            verifyKind(kind, bench.items[0])

            destroyRows()
            return result
        }

        function pad(text, width) {
            text = String(text)
            return text.length >= width ? text : " ".repeat(width - text.length) + text
        }

        function test_rows() {
            fillModel()

            create()
            bindRows("plain", 0, true)
            waitForRendering(column, 5000)
            wait(100)
            destroyRows()

            const results = {}
            for (const kind of root.kinds)
                results[kind] = measureKind(kind)

            const base = results.plain
            const ratio = (v, b) => v.toFixed(2) + " (" + (v / b).toFixed(1) + "x)"
            const lines = ["", "MessageView rows: " + root.rows + " per batch, median of " + root.reps,
                           pad("kind", 10) + pad("build ms/row", 18) + pad("rebind ms/row", 18) + pad("QObj/row", 14)]
            for (const kind of root.kinds) {
                const r = results[kind]
                lines.push(pad(kind, 10) + pad(ratio(r.build, base.build), 18)
                           + pad(ratio(r.rebind, base.rebind), 18)
                           + pad(r.qobjects + " (" + (r.qobjects / base.qobjects).toFixed(1) + "x)", 14))
            }
            // Where each kind's extra objects come from, per row, against plain.
            const plainHistogram = results.plain.histogram
            for (const kind of root.kinds.slice(1)) {
                const histogram = results[kind].histogram
                const names = new Set(Object.keys(histogram).concat(Object.keys(plainHistogram)))
                const extra = Array.from(names)
                    .map(name => [name, ((histogram[name] || 0) - (plainHistogram[name] || 0)) / root.rows])
                    .filter(entry => Math.abs(entry[1]) >= 0.5)
                    .sort((a, b) => b[1] - a[1])
                lines.push(kind + " vs plain: " + extra.map(e => e[0] + " " + (e[1] > 0 ? "+" : "") + e[1].toFixed(1)).join(", "))
                delete results[kind].histogram
            }
            delete results.plain.histogram
            console.info(lines.join("\n"))
            console.info("BENCH-RESULT " + JSON.stringify(results))
        }
    }
}
