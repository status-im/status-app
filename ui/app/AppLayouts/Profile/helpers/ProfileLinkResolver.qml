pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import QtModelsToolkit

import StatusQ.Components
import StatusQ.Core.Utils
import utils

// Resolves bare profile URLs embedded in message text. Standalone URLs keep their previews.
QObject {
    id: root

    required property StatusMessageDetails messageDetails
    property var contactsModel: null
    // A profile value of false defers the request until a batch frees capacity.
    property QtObject profileUrlResolver: null
    readonly property string text: messageDetails.unparsedText
    readonly property var links: {
        d.revision
        const result = {}
        for (let i = 0; i < entries.count; ++i) {
            const entry = entries.objectAt(i)
            if (entry && entry.profile.title)
                result[entry.modelData.url] = entry.profile
        }
        return result
    }

    onTextChanged: d.scheduleRefresh()
    onProfileUrlResolverChanged: d.scheduleRefresh()
    Component.onCompleted: Qt.callLater(d.refresh)
    Component.onDestruction: d.releasePending()

    QtObject {
        id: d
        property QtObject requestResolver: null
        property var candidateUrls: []
        property var profiles: ({})
        readonly property var pendingUrls: candidateUrls.filter(url => !(url in profiles))
        readonly property var deferredUrls: candidateUrls.filter(url => profiles[url] === false)
        readonly property var rows: Object.keys(profiles).filter(url => !!profiles[url]?.publicKey).map(url => ({
            url,
            publicKey: profiles[url].publicKey,
            name: profiles[url].displayName || ""
        }))
        property int revision: 0

        function releasePending() {
            if (d.requestResolver && d.pendingUrls.length)
                d.requestResolver.releaseProfileUrls(JSON.stringify(d.pendingUrls))
            d.requestResolver = null
        }

        function scheduleRefresh() {
            d.releasePending()
            d.candidateUrls = []
            d.profiles = {}
            Qt.callLater(d.refresh)
        }

        function refresh() {
            if (!root.profileUrlResolver || !/\/u(?:\/|#)/.test(root.text))
                return

            const segments = root.messageDetails.textSegments
            const link = segments.find(segment => !!segment.href)
            if (link && segments.map(segment => segment.text).join("").trim() === link.href)
                return

            const seen = new Set()
            for (const segment of segments) {
                const url = segment.href
                if (url && !segment.code && !segment.codeBlock && segment.text === url
                        && /\/u(?:\/|#)/.test(url) && Utils.isStatusDeepLink(url))
                    seen.add(url)
            }
            d.candidateUrls = Array.from(seen)
            if (d.candidateUrls.length) {
                d.requestResolver = root.profileUrlResolver
                d.profiles = d.requestProfiles(d.candidateUrls)
            }
        }

        function requestProfiles(urls) {
            return JSON.parse(d.requestResolver.resolveProfileUrls(JSON.stringify(urls)))
        }

        function invalidate() { ++d.revision }
    }

    Connections {
        target: d.pendingUrls.length || d.deferredUrls.length ? d.requestResolver : null

        function onProfileUrlsResolved(profilesJson) {
            const resolved = JSON.parse(profilesJson)
            const updated = d.pendingUrls.filter(url => url in resolved)
            const deferred = d.deferredUrls
            if (!updated.length && !deferred.length)
                return

            let changed = updated.length > 0
            const profiles = Object.assign({}, d.profiles)
            for (const url of updated)
                profiles[url] = resolved[url]
            if (deferred.length) {
                const retried = d.requestProfiles(deferred)
                for (const url of deferred) {
                    if (!(url in retried)) {
                        delete profiles[url]
                        changed = true
                    } else if (retried[url] !== false) {
                        profiles[url] = retried[url]
                        changed = true
                    }
                }
            }
            if (changed)
                d.profiles = profiles
        }
    }

    Instantiator {
        id: entries
        model: d.rows
        delegate: ModelEntry {
            id: entry
            required property var modelData
            sourceModel: root.contactsModel
            key: "pubKey"
            value: entry.modelData.publicKey
            readonly property var profile: ({
                title: entry.item?.preferredDisplayName || entry.item?.displayName || entry.modelData.name,
                image: entry.item?.thumbnailImage || entry.item?.icon || ""
            })
            onProfileChanged: Qt.callLater(d.invalidate)
        }
        onObjectAdded: Qt.callLater(d.invalidate)
        onObjectRemoved: Qt.callLater(d.invalidate)
    }
}
