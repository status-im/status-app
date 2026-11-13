pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import QtModelsToolkit

import StatusQ
import StatusQ.Core.Utils
import utils

// Resolves bare profile URLs embedded in message text. Standalone URLs keep their previews.
QObject {
    id: root

    property string text
    property var contactsModel: null
    // (url) -> { publicKey, displayName }, supplied by the application/store.
    property var parseProfileUrl: null
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

    onTextChanged: Qt.callLater(d.refresh)
    onParseProfileUrlChanged: Qt.callLater(d.refresh)
    Component.onCompleted: Qt.callLater(d.refresh)

    QtObject {
        id: d
        property var urls: []
        property int revision: 0

        function refresh() {
            const urls = []
            const seen = new Set()
            if (root.parseProfileUrl && /\/u(?:\/|#)/.test(root.text)) {
                const segments = MarkdownUtils.toChatTextSegments(root.text)
                const link = segments.find(segment => !!segment.href)
                if (link && segments.map(segment => segment.text).join("").trim() === link.href) {
                    d.urls = []
                    return
                }
                for (const segment of segments) {
                    const url = segment.href
                    if (!url || segment.code || segment.codeBlock || segment.text !== url
                            || seen.has(url) || !Utils.isStatusDeepLink(url)
                            || !/\/u(?:\/|#)/.test(url))
                        continue
                    seen.add(url)
                    const data = root.parseProfileUrl(url)
                    if (data && data.publicKey)
                        urls.push({url, publicKey: data.publicKey, name: data.displayName || ""})
                }
            }
            d.urls = urls
        }

        function invalidate() { ++d.revision }
    }

    Instantiator {
        id: entries
        model: d.urls
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
