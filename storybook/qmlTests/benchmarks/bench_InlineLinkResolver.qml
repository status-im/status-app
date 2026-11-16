import QtQuick
import QtQml.Models
import QtTest

import AppLayouts.Chat.controls
import utils

// Includes deferred resolution: each iteration settles updates for 200 messages.
// Domain reads are mocked and counted; this measures resolver CPU, not DB latency.
Item {
    id: root
    width: 800
    height: 800
    property int revision: 0
    property int reads: 0
    readonly property string url: "https://status.app/c#community"
    readonly property string variant: (Qt.application.arguments.find(arg => arg.startsWith("BenchResolver::benchmark_")) || "BenchResolver::benchmark_plain").split("benchmark_")[1]

    ListModel {
        id: previews
        dynamicRoles: true
        Component.onCompleted: append({url: root.url, previewType: Constants.LinkPreviewType.StatusCommunity,
                                       statusCommunityPreview: {displayName: "Status"}, statusCommunityPreviewIcon: {url: ""}})
    }
    Instantiator {
        id: messages
        model: 200
        delegate: InlineLinkResolver {
            text: root.variant === "plain" ? "Hello team" : "Before " + root.url + " after"
            previewModel: root.variant === "preview" ? previews : null
            revision: root.revision
            parseLink: url => ({url, communityId: "community"})
            resolveLink: target => {
                ++root.reads
                return {kind: "community", communityId: "community", communityName: "Status"}
            }
        }
    }
    TestCase {
        name: "BenchResolver"
        when: windowShown && messages.count === 200
        function settle() { ++root.revision; wait(0); wait(0) }
        function benchmark_plain() { settle() }
        function benchmark_preview() { settle() }
        function benchmark_fallback() { settle() }
        function cleanupTestCase() {
            if (root.variant !== "fallback")
                compare(root.reads, 0)
            else
                verify(root.reads >= 200)
        }
    }
}
