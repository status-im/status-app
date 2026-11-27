import QtQuick
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import AppLayouts.Chat.controls
import AppLayouts.Chat.stores as ChatStores
import shared.views.chat
import Models
import utils
import Storybook.Testing

Item {
    id: root
    width: 800
    height: 800

    property var destinations: ({})
    property int resolveCalls: 0
    readonly property string communityUrl: "https://status.app/c#community"
    readonly property string channelUrl: "https://status.app/cc/channel#community"
    readonly property string messageUrl: "https://status.app/m/group?message-id=message"
    readonly property string threadUrl: "https://status.app/g/?a2=group&thread-id=thread"

    Component {
        id: resolverComponent
        InlineLinkResolver {
            parseLink: url => root.destinations[url] ? Object.assign({url}, root.destinations[url]) : null
            resolveLink: target => { ++root.resolveCalls; return root.destinations[target.url] || null }
        }
    }
    Component {
        id: messageComponent
        MessageView {
            width: 650
            textAppearance: MessageTextAppearance { theme: Theme }
            previewAppearance: ReplyTextAppearance { theme: Theme }
            messageStore: ChatStores.MessageStore {
                function parseInlineLink(url) { return root.destinations[url] ? Object.assign({url}, root.destinations[url]) : null }
                function resolveInlineLink(target) { return root.destinations[target.url] || null }
            }
        }
    }
    Component {
        id: actualStoreComponent
        MessageStoreUnderTest {
            property var mainModule: ({isOnline: true, activeSection: {id: ""}})
        }
    }
    Component { id: integrationPageComponent; InlineLinkIntegrationPage {} }
    Component { id: spyComponent; SignalSpy {} }
    Component { id: changesComponent; QtObject { signal inlineLinkDataChanged(var changes) } }
    Component {
        id: profileUrlResolverComponent
        QtObject {
            signal profileUrlsResolved(string profilesJson)

            function resolveProfileUrls(urlsJson) {
                const profiles = {}
                for (const url of JSON.parse(urlsJson))
                    profiles[url] = {publicKey: "key", displayName: "Alice"}
                return JSON.stringify(profiles)
            }

            function releaseProfileUrls(urlsJson) {}
        }
    }
    Component { id: rowsComponent; ListModel {} }
    Component { id: previewRowsComponent; ListModel { dynamicRoles: true } }
    LinkPreviewModel { id: previewData }

    TestCase {
        name: "InlineLinkResolver"
        when: windowShown

        function test_previewAccessRevocationAndRecovery_data() {
            return [{tag: "initially-allowed", denied: false}, {tag: "initially-denied", denied: true}]
        }

        function test_previewAccessRevocationAndRecovery(row) {
            const rows = createTemporaryObject(previewRowsComponent, root)
            const preview = previewData.getStandardLinkPreview()
            preview.url = root.threadUrl
            preview.previewType = Constants.LinkPreviewType.StatusThread
            preview.standardPreview.threadAccessible = true
            preview.standardPreview.threadParentName = "Travel"
            preview.standardPreview.title = "Plans"
            rows.append(preview)
            const source = createTemporaryObject(changesComponent, root)
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatId: "group", chatName: "Travel", threadId: "thread", threadName: row.denied ? "" : "Plans", noAccess: row.denied}})
            const resolver = createTemporaryObject(resolverComponent, root, {
                text: "Before " + root.threadUrl + " after", previewModel: rows, metadataSource: source
            })
            tryVerify(() => !!resolver.links[root.threadUrl])
            wait(0)
            compare(resolver.links[root.threadUrl].path.some(part => part.text === "# no access"), row.denied)
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatId: "group", chatName: "Travel", threadId: "thread", noAccess: true}})
            source.inlineLinkDataChanged({chats: {group: true}, communities: {}})
            wait(0)
            verify(resolver.links[root.threadUrl].path.some(part => part.text === "# no access"), "Access revocation must invalidate the stored preview")
            verify(!resolver.links[root.threadUrl].path.some(part => part.text === "Plans"))
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatId: "group", chatName: "Travel", threadId: "thread", threadName: "Renamed"}})
            source.inlineLinkDataChanged({chats: {group: true}, communities: {}})
            tryVerify(() => resolver.links[root.threadUrl].path.some(part => part.text === "Renamed"))
            verify(!resolver.links[root.threadUrl].path.some(part => part.text === "# no access"))
        }

        function init() { root.destinations = ({}); root.resolveCalls = 0 }

        function test_canonicalStatusUrl_data() {
            return [
                {tag: "internal", input: "status-app://c#community", expected: "https://status.app/c#community"},
                {tag: "http", input: "http://status.app/cc/channel#community", expected: "https://status.app/cc/channel#community"},
                {tag: "https", input: "https://status.app/u#profile", expected: "https://status.app/u#profile"},
                {tag: "mixed-case-internal", input: "STATUS-APP://c#AbC", expected: "https://status.app/c#AbC"},
                {tag: "mixed-case-http", input: "HTTP://STATUS.APP/cc/AbC#DeF", expected: "https://status.app/cc/AbC#DeF"},
                {tag: "mixed-case-https", input: "HtTpS://StAtUs.ApP/g/?a2=AbC&thread-id=DeF", expected: "https://status.app/g/?a2=AbC&thread-id=DeF"},
                {tag: "external", input: "http://example.com/c#community", expected: "http://example.com/c#community"},
                {tag: "similar-host", input: "HTTP://STATUS.APP.example.com/c#community", expected: "HTTP://STATUS.APP.example.com/c#community"}
            ]
        }

        function test_canonicalStatusUrl(row) {
            compare(Utils.canonicalStatusUrl(row.input), row.expected)
            compare(Utils.isStatusDeepLink(row.input), row.expected.startsWith("https://status.app/"))
        }

        function test_destinations_data() {
            return [
                {tag: "community", url: root.communityUrl,
                    data: {kind: "community", communityId: "community", communityName: "Status", communityImage: Assets.svg("message-link")},
                    title: "Status", context: "", thread: false, message: false},
                {tag: "internal-community", url: "status-app://c#community",
                    data: {kind: "community", communityId: "community", communityName: "Status"},
                    title: "Status", context: "", thread: false, message: false},
                {tag: "channel", url: root.channelUrl,
                    data: {kind: "channel", communityId: "community", communityName: "Status", chatName: "general"},
                    title: "Status", context: "# general", thread: false, message: false},
                {tag: "community-message", url: "https://status.app/m/community-channel?message-id=message",
                    data: {kind: "message", communityId: "community", communityName: "Status", chatName: "general"},
                    title: "Status", context: "# general", thread: false, message: true},
                {tag: "group-message", url: "HTTP://STATUS.APP/m/group?message-id=message",
                    data: {kind: "message", chatName: "Travel", chatImage: Assets.svg("message-link")},
                    title: "Travel", context: "", thread: false, message: true},
                {tag: "community-thread", url: root.channelUrl.replace("#", "?thread-id=thread#"),
                    data: {kind: "thread", communityId: "community", communityName: "Status", chatName: "general", threadId: "thread", threadName: "Community plans"},
                    title: "Status", context: "Community plans", thread: true, message: false},
                {tag: "group-thread", url: root.threadUrl,
                    data: {kind: "thread", chatName: "Travel", threadId: "thread", threadName: "Sierra Park"},
                    title: "Travel", context: "Sierra Park", thread: true, message: false},
                {tag: "message-in-thread", url: root.messageUrl,
                    data: {kind: "message", chatName: "Travel", threadId: "thread", threadName: "Sierra Park"},
                    title: "Travel", context: "Sierra Park", thread: true, message: true},
                {tag: "direct-thread", url: "STATUS-APP://p/?thread-id=thread",
                    data: {kind: "thread", chatName: "Alice", threadId: "thread", threadName: "Plans"},
                    title: "Alice", context: "Plans", thread: true, message: false}
            ]
        }

        function test_destinations(row) {
            root.destinations = ({[row.url]: row.data})
            const resolver = createTemporaryObject(resolverComponent, root, {text: "Before " + row.url + " after"})
            tryVerify(() => !!resolver.links[row.url])
            const link = resolver.links[row.url]
            compare(link.title, row.title)
            compare(link.image, row.data.communityImage || row.data.chatImage || "")
            verify(link.path.map(part => part.text).join(" ").includes(row.context))
            compare(link.path.some(part => part.icon === "thread"), row.thread)
            if (row.data.threadName) compare(link.path.find(part => part.icon === "thread").text, row.data.threadName)
            compare(link.trailingIcons.length, row.message ? 1 : 0)
        }

        function test_existingParserDispatch_data() { return test_destinations_data() }
        function test_existingParserDispatch(row) {
            const calls = []
            const canonical = Utils.canonicalStatusUrl(row.url)
            const parser = {
                parseSharedUrl: url => {
                    calls.push("shared")
                    return JSON.stringify({community: {communityId: "community", displayName: "Status"},
                                           channel: {uuid: row.data.kind === "community" ? "" : "channel", displayName: "general"}})
                },
                parseMessageUrl: url => { calls.push("message"); compare(url, canonical); return JSON.stringify({chatId: "chat", messageId: "message"}) },
                parseThreadUrl: url => { calls.push("thread"); compare(url, canonical); return JSON.stringify({chatId: "chat", threadId: "thread", communityId: row.data.communityId || ""}) }
            }
            const store = createTemporaryObject(actualStoreComponent, root, {sharedUrlParser: parser})
            verify(store)
            const data = store.parseInlineLink(row.url)
            verify(data)
            compare(data.kind, row.data.kind)
            compare(data.url, row.url)
            compare(calls.length, row.tag === "community-thread" ? 2 : 1)
        }

        function test_liveModelsUpdateNamesWithoutDomainReads_data() {
            return [{tag: "fallback", withPreview: false}, {tag: "preview", withPreview: true}]
        }

        function test_liveModelsUpdateNamesWithoutDomainReads(row) {
            const chats = createTemporaryObject(rowsComponent, root)
            const communities = createTemporaryObject(rowsComponent, root)
            chats.append({itemId: "chat", name: "general", icon: "", canView: true, active: true})
            communities.append({id: "community", name: "Status", image: "avatar", joined: true})
            const previews = createTemporaryObject(previewRowsComponent, root)
            if (row.withPreview) {
                const preview = previewData.getChannelLinkPreview()
                preview.url = root.channelUrl
                preview.statusCommunityChannelCommunityPreview.displayName = "Stored community"
                preview.statusCommunityChannelPreview.displayName = "stored-channel"
                previews.append(preview)
            }
            root.destinations = ({[root.channelUrl]: {kind: "channel", chatId: "chat", communityId: "community"}})
            const resolver = createTemporaryObject(resolverComponent, root, {
                text: "Before " + root.channelUrl + " after", chatModelForLink: communityId => chats, communitiesModel: communities, previewModel: previews
            })
            tryVerify(() => resolver.links[root.channelUrl]?.title === "Status")
            compare(resolver.links[root.channelUrl].image, "avatar")
            compare(resolver.links[root.channelUrl].path[0].text, "# general")
            wait(0)
            const calls = root.resolveCalls
            communities.setProperty(0, "name", "Renamed community")
            communities.setProperty(0, "image", "new-avatar")
            chats.setProperty(0, "name", "renamed-channel")
            tryVerify(() => resolver.links[root.channelUrl].title === "Renamed community")
            compare(resolver.links[root.channelUrl].image, "new-avatar")
            compare(resolver.links[root.channelUrl].path[0].text, "# renamed-channel")
            wait(0)
            compare(root.resolveCalls, calls)
            chats.append({itemId: "other", name: "Unrelated", icon: "", canView: true, active: true})
            chats.setProperty(1, "name", "Other renamed")
            wait(0)
            compare(root.resolveCalls, calls)
            root.destinations = ({[root.channelUrl]: {kind: "channel", chatId: "chat", communityId: "community", noAccess: true}})
            chats.setProperty(0, "canView", false)
            if (!row.withPreview) tryCompare(root, "resolveCalls", calls + 1)
            tryVerify(() => resolver.links[root.channelUrl].path.some(part => part.text === "# no access"))
            verify(resolver.links[root.channelUrl].path.some(part => part.text === "# no access"))
        }

        function test_communityThreadPreviewUsesCurrentName() {
            const url = root.channelUrl.replace("#", "?thread-id=thread#")
            const rows = createTemporaryObject(previewRowsComponent, root)
            const preview = previewData.getStandardLinkPreview()
            preview.url = url
            preview.previewType = Constants.LinkPreviewType.StatusThread
            preview.standardPreview.threadAccessible = true
            preview.standardPreview.description = "Status"
            preview.standardPreview.threadParentName = "general"
            preview.standardPreview.title = "Preview thread name"
            rows.append(preview)
            const source = createTemporaryObject(changesComponent, root)
            root.destinations = ({[url]: {kind: "thread", communityId: "community", chatId: "channel", threadId: "thread"}})
            const resolver = createTemporaryObject(resolverComponent, root, {
                text: "Before " + url + " after", previewModel: rows, metadataSource: source
            })
            tryVerify(() => !!resolver.links[url])
            compare(resolver.links[url].path.find(part => part.icon === "thread").text, "Preview thread name")
            compare(resolver.links[url].trailingIcons.length, 0)
            root.destinations = ({[url]: {kind: "thread", communityId: "community", chatId: "channel", threadId: "thread", threadName: "Renamed thread"}})
            source.inlineLinkDataChanged({chats: {channel: true}, communities: {}})
            tryVerify(() => resolver.links[url].path.find(part => part.icon === "thread").text === "Renamed thread")
        }

        function test_messageInThreadPreviewKeepsMessageIcon() {
            const rows = createTemporaryObject(previewRowsComponent, root)
            const preview = previewData.getStandardLinkPreview()
            preview.url = root.messageUrl
            preview.previewType = Constants.LinkPreviewType.StatusThread
            preview.standardPreview.threadAccessible = true
            preview.standardPreview.threadParentName = "Travel"
            preview.standardPreview.title = "Plans"
            rows.append(preview)
            root.destinations = ({[root.messageUrl]: {kind: "message", chatId: "group", threadId: "thread", threadName: "Plans"}})
            const resolver = createTemporaryObject(resolverComponent, root, {
                text: "Before " + root.messageUrl + " after", previewModel: rows
            })
            tryVerify(() => !!resolver.links[root.messageUrl])
            compare(resolver.links[root.messageUrl].trailingIcons.length, 1)
            compare(resolver.links[root.messageUrl].path.find(part => part.icon === "thread").text, "Plans")
        }

        function test_existingSectionModelsAreReused() {
            const chats = createTemporaryObject(rowsComponent, root)
            const channels = createTemporaryObject(rowsComponent, root)
            let preparedCommunity = ""
            const store = createTemporaryObject(actualStoreComponent, root, {
                mainModule: {
                    isOnline: true, activeSection: {id: ""},
                    getChatSectionModule: () => ({model: chats}),
                    prepareCommunitySectionModuleForCommunityId: id => { preparedCommunity = id },
                    getCommunitySectionModule: () => ({model: channels})
                }
            })
            compare(store.chatModelForInlineLink(""), chats)
            compare(store.chatModelForInlineLink("community"), channels)
            compare(preparedCommunity, "community")
        }

        function test_fallbackWithoutLocalModelPreservesSharedMetadata() {
            const store = createTemporaryObject(actualStoreComponent, root)
            verify(store)
            const data = store.resolveInlineLink({kind: "community", communityId: "community", communityName: "Shared name"})
            compare(data.communityName, "Shared name")
        }

        function test_parserReusesImmutableTargets() {
            let calls = 0
            const store = createTemporaryObject(actualStoreComponent, root, {
                sharedUrlParser: {parseSharedUrl: url => {
                    ++calls
                    return JSON.stringify({community: {communityId: "community", displayName: "Status"}})
                }}
            })
            verify(store)
            const first = store.parseInlineLink(root.communityUrl)
            verify(first)
            verify(Object.isFrozen(first))
            for (let i = 0; i < 100; ++i)
                compare(store.parseInlineLink(root.communityUrl), first)
            compare(calls, 1)
        }

        function test_unrelatedMetadataDoesNotResolveAgain() {
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatId: "group", chatName: "Travel", threadName: "Plans"}})
            const source = createTemporaryObject(changesComponent, root)
            const resolver = createTemporaryObject(resolverComponent, root, {text: "Before " + root.threadUrl + " after", metadataSource: source})
            tryVerify(() => !!resolver.links[root.threadUrl])
            wait(0)
            const calls = root.resolveCalls
            source.inlineLinkDataChanged({chats: {other: true}, communities: {}})
            compare(root.resolveCalls, calls)
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatId: "group", chatName: "Renamed", threadName: "Plans"}})
            source.inlineLinkDataChanged({chats: {group: true}, communities: {}})
            tryVerify(() => resolver.links[root.threadUrl].title === "Renamed")
            compare(root.resolveCalls, calls + 1)
        }

        function test_standaloneAndAuthoredLinksStayUnchanged_data() { return test_destinations_data() }

        function test_standaloneAndAuthoredLinksStayUnchanged(row) {
            root.destinations = ({[row.url]: row.data})
            for (const text of [row.url, "[Custom label](" + row.url + ")",
                                "Before `" + row.url + "` after", "```\n" + row.url + "\n```"] ) {
                const resolver = createTemporaryObject(resolverComponent, root, {text})
                wait(0)
                compare(Object.keys(resolver.links).length, 0)
            }
        }

        function test_profilesCoexistWithOtherDestinations_data() {
            return [
                {tag: "https", url: "https://status.app/u#key"},
                {tag: "mixed-case", url: "HTTPS://STATUS.APP/u#key"}
            ]
        }

        function test_profilesCoexistWithOtherDestinations(row) {
            const profileUrl = row.url
            root.destinations = ({[root.communityUrl]: {kind: "community", communityId: "community", communityName: "Status"}})
            const resolver = createTemporaryObject(resolverComponent, root, {
                text: "Contact " + profileUrl + " in " + root.communityUrl,
                profileUrlResolver: createTemporaryObject(profileUrlResolverComponent, root)
            })
            tryVerify(() => Object.keys(resolver.links).length === 2)
            compare(resolver.links[profileUrl].title, "Alice")
            compare(resolver.links[root.communityUrl].title, "Status")
        }

        function test_unavailableAndMalformedDestinations() {
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatId: "group", threadId: "thread", noAccess: true}})
            const resolver = createTemporaryObject(resolverComponent, root, {
                text: "Before " + root.threadUrl + " https://status.app/c/invalid https://example.org/c#community after"
            })
            tryVerify(() => !!resolver.links[root.threadUrl])
            compare(Object.keys(resolver.links).length, 1)
            compare(resolver.links[root.threadUrl].title, "No access")
            compare(resolver.links[root.threadUrl].emoji, "🔒")
            compare(resolver.links[root.threadUrl].path.length, 0)
        }

        function createMessage(text, previews = null) {
            const message = createTemporaryObject(messageComponent, root, {unparsedText: text, linkPreviewModel: previews})
            verify(message)
            tryCompare(message, "status", Loader.Ready)
            const field = findChild(message, "StatusTextMessage_chatText")
            verify(field)
            return {message, field}
        }

        function test_messageNavigationAndCopy_data() { return test_destinations_data() }

        function test_messageNavigationAndCopy(row) {
            root.destinations = ({[row.url]: row.data})
            const text = "Before " + row.url + " after"
            const {message, field} = createMessage(text)
            tryVerify(() => field.text.includes(row.title))
            verify(field.text.includes(row.context))
            const spy = createTemporaryObject(spyComponent, root, {target: Global, signalName: "activateDeepLink"})
            const icon = field.inlineIconRects[0].rect
            // Every row clicks the same spot; a quicker click would be a double click.
            wait(Qt.styleHints.mouseDoubleClickInterval + 30)
            mouseClick(field, icon.x + icon.width / 2, icon.y + icon.height / 2)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], Utils.canonicalStatusUrl(row.url))
            field.selectAll()
            compare(field.selectedText, text)
        }

        function test_metadataUpdatesAndRebinding() {
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatName: "Travel", threadId: "thread"}})
            const {message, field} = createMessage("Before " + root.threadUrl + " after")
            tryVerify(() => field.text.includes("Unknown thread name"))
            root.destinations = ({[root.threadUrl]: {kind: "thread", chatName: "New group", threadId: "thread", threadName: "Plans"}})
            ++message.messageStore.inlineLinkRevision
            tryVerify(() => field.text.includes("New group") && field.text.includes("Plans"))
            message.unparsedText = "Recycled message"
            tryCompare(field, "text", "Recycled message")
            compare(field.inlineIconRects.length, 0)
        }

        function test_mixedPreviewsAndStandaloneRestoration() {
            root.destinations = ({[root.communityUrl]: {kind: "community", communityId: "community", communityName: "Status"}})
            const rows = createTemporaryObject(rowsComponent, root)
            for (const url of [root.communityUrl, "https://example.org"]) {
                const preview = previewData.getStandardLinkPreview()
                preview.url = url
                preview.isLocalData = true
                preview.loadingLocalData = false
                preview.standardPreviewThumbnail.url = ""
                rows.append(preview)
            }
            const {message, field} = createMessage("Before " + root.communityUrl + " https://example.org after", rows)
            tryVerify(() => field.text.includes("Status"))
            const links = findChild(message, "LinksMessageView")
            verify(links)
            const card = findChild(links, "linkPreviewCard_" + root.communityUrl)
            const external = findChild(links, "linkPreviewCard_https://example.org")
            verify(card)
            verify(external)
            tryCompare(card, "showPreview", false)
            compare(external.showPreview, true)
            compare(rows.count, 2)
            rows.remove(1)
            tryCompare(links.parent, "visible", false)
            message.unparsedText = root.communityUrl
            tryCompare(card, "showPreview", true)
            tryCompare(card, "visible", true)
            compare(field.inlineIconRects.length, 0)
            compare(rows.count, 1)
        }

        function test_existingPreviewsAvoidDomainReads_data() {
            return [{tag: "community", kind: "community"}, {tag: "channel", kind: "channel"},
                    {tag: "thread", kind: "thread"}]
        }

        function test_existingPreviewsAvoidDomainReads(row) {
            const rows = createTemporaryObject(previewRowsComponent, root)
            const url = row.kind === "community" ? root.communityUrl : row.kind === "channel" ? root.channelUrl : root.threadUrl
            let preview
            if (row.kind === "community") {
                preview = previewData.getCommunityLinkPreview()
                preview.statusCommunityPreview.displayName = "Status"
                preview.statusCommunityPreviewIcon.url = ""
            } else if (row.kind === "channel") {
                preview = previewData.getChannelLinkPreview()
                preview.statusCommunityChannelCommunityPreview.displayName = "Status"
                preview.statusCommunityChannelPreview.displayName = "general"
                preview.statusCommunityChannelCommunityPreviewIcon.url = ""
            } else {
                preview = previewData.getStandardLinkPreview()
                preview.previewType = Constants.LinkPreviewType.StatusThread
                preview.standardPreview.threadAccessible = true
                preview.standardPreview.threadParentName = "Travel"
                preview.standardPreview.title = "Plans"
            }
            preview.url = url
            rows.append(preview)
            root.destinations = ({[url]: {kind: row.kind, communityId: row.kind === "thread" ? "" : "community", chatId: row.kind === "community" ? "" : "chat", threadId: row.kind === "thread" ? "thread" : ""}})
            const resolver = createTemporaryObject(resolverComponent, root, {text: "Before " + url + " after", previewModel: rows})
            tryVerify(() => !!resolver.links[url])
            compare(resolver.links[url].title, row.kind === "thread" ? "Travel" : "Status")
            wait(0)
            const reads = root.resolveCalls
            compare(reads, row.kind === "thread" ? 1 : 0)
            for (let i = 0; i < 100; ++i)
                ++resolver.revision
            wait(0)
            compare(root.resolveCalls, reads)
            // A model update must refresh presentation without querying the domain.
            if (row.kind === "community") {
                rows.setProperty(0, "statusCommunityPreview", {displayName: "Renamed community"})
                tryCompare(resolver.links[url], "title", "Renamed community")
                compare(root.resolveCalls, 0)
            }
        }

        function test_previewRemovalUsesFallbackAndRecyclingClearsObservers() {
            const rows = createTemporaryObject(previewRowsComponent, root)
            const preview = previewData.getCommunityLinkPreview()
            preview.url = root.communityUrl
            preview.statusCommunityPreview.displayName = "Preview name"
            rows.append(preview)
            root.destinations = ({[root.communityUrl]: {kind: "community", communityId: "community", communityName: "Local name"}})
            const resolver = createTemporaryObject(resolverComponent, root, {text: "Before " + root.communityUrl + " after", previewModel: rows})
            tryVerify(() => resolver.links[root.communityUrl]?.title === "Preview name")
            compare(root.resolveCalls, 0)
            rows.clear()
            tryVerify(() => resolver.links[root.communityUrl]?.title === "Local name")
            tryVerify(() => root.resolveCalls > 0)
            resolver.text = "Recycled message"
            tryVerify(() => Object.keys(resolver.links).length === 0)
            const calls = root.resolveCalls
            ++resolver.revision
            wait(0)
            compare(root.resolveCalls, calls)
        }

        function test_storybookIntegration() {
            const page = createTemporaryObject(integrationPageComponent, root, {width: 1100, height: 800})
            verify(page)
            const first = findChild(page, "inlineIntegrationMessage0")
            verify(first)
            tryCompare(first, "status", Loader.Ready)
            const field = findChild(first, "StatusTextMessage_chatText")
            verify(field)
            tryVerify(() => field.text.includes("Status App"))
            findChild(page, "inlineIntegrationNoAccess").checked = true
            tryVerify(() => field.text.includes("# no access"))
            findChild(page, "inlineIntegrationUnknown").checked = true
            tryVerify(() => field.text.includes("No access"))
            for (let i = 0; i < page.examples.length; ++i)
                verify(findChild(page, "inlineIntegrationMessage" + i))
        }
    }
}
