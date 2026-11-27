pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import QtModelsToolkit

import StatusQ
import StatusQ.Components
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import AppLayouts.Profile.helpers
import utils

// Resolves destination data at the store boundary; presentation stays here.
QObject {
    id: root

    property string text
    property StatusMessageDetails messageDetails: StatusMessageDetails { unparsedText: root.text }
    property alias contactsModel: profiles.contactsModel
    property alias profileUrlResolver: profiles.profileUrlResolver
    // (url) -> destination metadata, or null for an unsupported/invalid URL.
    property var parseLink: null
    property var resolveLink: null
    property var metadataSource: null
    property int revision: 0
    property var previewModel: null
    property var chatModelForLink: null
    property var communitiesModel: null
    readonly property var links: {
        d.revision
        const result = Object.assign({}, profiles.links)
        for (let i = 0; i < entries.count; ++i) {
            const entry = entries.objectAt(i)
            if (entry?.definition)
                result[entry.modelData] = entry.definition
        }
        return result
    }

    // Refresh on activation too: access may have changed since the last render.
    function refreshLink(url) {
        for (let i = 0; i < entries.count; ++i) {
            const entry = entries.objectAt(i)
            if (entry?.modelData === url) {
                entry.refreshAccess()
                return entry.definition
            }
        }
        return links[url] || null
    }

    onParseLinkChanged: Qt.callLater(d.reset)
    onResolveLinkChanged: Qt.callLater(d.refresh)
    onRevisionChanged: Qt.callLater(d.reset)
    Component.onCompleted: Qt.callLater(d.refresh)

    ProfileLinkResolver {
        id: profiles
        messageDetails: root.messageDetails
        onEmbeddedUrlsChanged: Qt.callLater(d.refresh)
    }

    QtObject {
        id: d
        property int revision: 0
        function invalidate() { ++d.revision }

        function fromPreview(preview, url) {
            if (!preview)
                return null
            const type = preview.previewType
            const channel = type === Constants.LinkPreviewType.StatusCommunityChannel
            if (channel || type === Constants.LinkPreviewType.StatusCommunity) {
                const community = channel ? preview.statusCommunityChannelCommunityPreview : preview.statusCommunityPreview
                const image = channel ? preview.statusCommunityChannelCommunityPreviewIcon : preview.statusCommunityPreviewIcon
                if (!community?.displayName || (channel && !preview.statusCommunityChannelPreview?.displayName))
                    return null
                return {title: community.displayName, image: image?.url || image?.dataUri || "",
                    path: channel ? [{text: "# " + preview.statusCommunityChannelPreview.displayName}] : [], trailingIcons: []}
            }
            if (type === Constants.LinkPreviewType.StatusThread && preview.standardPreview?.threadAccessible) {
                const thread = preview.standardPreview
                const community = Utils.canonicalStatusUrl(url).startsWith(Constants.externalStatusLinkWithHttps + "/cc/")
                const title = community ? thread.description : thread.threadParentName
                if (!title || !thread.title || !thread.threadParentName)
                    return null
                return {title, image: community ? "" : preview.standardPreviewThumbnail?.url || preview.standardPreviewThumbnail?.dataUri || "",
                    path: community ? [{text: thread.threadParentName}, {text: thread.title, icon: "thread"}]
                                    : [{text: thread.title, icon: "thread"}],
                    trailingIcons: []}
            }
            return null
        }

        function refresh(changes = null) {
            for (let i = 0; i < entries.count; ++i)
                entries.objectAt(i)?.refresh?.(changes)
        }
        function reset() {
            for (let i = 0; i < entries.count; ++i) {
                const entry = entries.objectAt(i)
                if (entry?.refresh) {
                    entry.parsedUrl = ""
                    entry.refresh()
                }
            }
        }

        function format(data) {
            if (!data || !["community", "channel", "message", "thread"].includes(data.kind))
                return null
            if (data.noAccess) {
                const context = data.communityId ? data.communityName : data.chatName
                return {title: context || qsTr("No access"), emoji: "🔒",
                    path: context ? [{text: qsTr("# no access")}] : [],
                    trailingIcons: [], error: "noAccess"}
            }
            if (data.contentUnavailable)
                return {title: qsTr("Content unavailable"), emoji: "⚠️", path: [], trailingIcons: [], error: "unavailable"}
            const community = !!data.communityId
            const path = []
            if (community && data.kind !== "community")
                path.push({text: "# " + (data.chatName || qsTr("Unknown channel"))})
            if (data.kind === "thread" || data.threadId)
                path.push({text: data.threadName || qsTr("Unknown thread name"), icon: "thread"})
            return {
                title: community ? data.communityName || qsTr("Unknown community") : data.chatName || qsTr("Unknown chat"),
                image: community ? data.communityImage || "" : data.chatImage || "",
                path,
                trailingIcons: data.kind === "message" ? [{image: Assets.svg("message-link")}] : []
            }
        }
    }

    Connections {
        target: root.metadataSource ?? null
        function onInlineLinkDataChanged(changes) { d.refresh(changes) }
    }

    Instantiator {
        id: entries
        model: profiles.embeddedUrls.filter(url => !/\/u(?:\/|#)/.test(url))
        delegate: ModelEntry {
            id: entry
            required property string modelData
            sourceModel: root.previewModel ?? null
            key: "url"
            value: modelData
            readonly property var preview: d.fromPreview(item, modelData)
            property string parsedUrl: ""
            property var target: null
            property var fallbackData: null
            readonly property var definition: {
                if (preview && root.parseLink && (!target ||
                    (["thread", "message"].includes(target.kind) && root.resolveLink && !fallbackData)))
                    return null
                const noAccess = !!fallbackData?.noAccess || chat.item?.canView === false || community.item?.amIBanned === true
                if (preview && !noAccess && !fallbackData?.contentUnavailable) {
                    const result = Object.assign({}, preview)
                    result.trailingIcons = target?.kind === "message" ? [{image: Assets.svg("message-link")}] : []
                    result.title = target?.communityId ? community.item?.name || result.title : chat.item?.name || result.title
                    if (community.item?.id) result.image = community.item.image || ""
                    else if (chat.item?.itemId) result.image = chat.item.icon || ""
                    result.path = preview.path.map((part, index) => {
                        if (target?.communityId && index === 0 && chat.item?.itemId)
                            return Object.assign({}, part, {text: "# " + chat.item.name})
                        if (part.icon === "thread" && fallbackData?.threadName)
                            return Object.assign({}, part, {text: fallbackData.threadName})
                        return part
                    })
                    return result
                }
                if (!fallbackData) return null
                return d.format(Object.assign({}, fallbackData, {
                    noAccess,
                    threadName: noAccess ? "" : fallbackData.threadName,
                    communityName: community.item?.name || fallbackData.communityName,
                    communityImage: community.item?.id ? community.item.image || "" : fallbackData.communityImage,
                    chatName: chat.item?.name || fallbackData.chatName,
                    chatImage: chat.item?.itemId ? chat.item.icon || "" : fallbackData.chatImage
                }))
            }

            readonly property ModelEntry chat: ModelEntry {
                sourceModel: {
                    if (!entry.target?.chatId || !root.chatModelForLink)
                        return null
                    if (entry.target.communityId && !community.item?.joined && !community.item?.spectated)
                        return null
                    return root.chatModelForLink(entry.target.communityId || "")
                }
                key: "itemId"
                value: entry.target?.chatId || ""
            }
            readonly property ModelEntry community: ModelEntry {
                sourceModel: entry.target?.communityId ? root.communitiesModel : null
                key: "id"
                value: entry.target?.communityId || ""
            }
            // Names and images bind directly to the existing models. Only access changes
            // require rereading thread metadata.
            readonly property string accessState: JSON.stringify([
                !!chat.item?.itemId, chat.item?.canView, chat.item?.active,
                !!community.item?.id, community.item?.joined, community.item?.isMember,
                community.item?.amIBanned, community.item?.access
            ])
            onAccessStateChanged: if (parsedUrl) Qt.callLater(entry.refreshAccess)

            function refreshAccess() { refresh(null, true) }

            function refresh(changes = null, accessChanged = false) {
                if (parsedUrl !== modelData || (!target && changes)) {
                    target = root.parseLink ? root.parseLink(modelData) : null
                    parsedUrl = modelData
                }
                if (changes && target && !changes.chats[target.chatId] && !changes.communities[target.communityId])
                    return
                if (preview && !changes && !accessChanged && fallbackData)
                    return
                if (preview && !["thread", "message"].includes(target?.kind)) {
                    fallbackData = target ? Object.assign({}, target, {noAccess: chat.item?.canView === false || community.item?.amIBanned === true}) : null
                    return
                }
                fallbackData = target && root.resolveLink ? root.resolveLink(target) : null
            }
            onPreviewChanged: Qt.callLater(entry.refresh)
            onDefinitionChanged: Qt.callLater(d.invalidate)
        }
        onObjectAdded: { Qt.callLater(d.refresh); Qt.callLater(d.invalidate) }
        onObjectRemoved: Qt.callLater(d.invalidate)
    }
}
