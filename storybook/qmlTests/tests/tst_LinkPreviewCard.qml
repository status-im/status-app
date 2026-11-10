import QtQuick
import QtTest

import shared.controls.chat
import shared.controls.delegates
import utils

Item {
    id: root
    width: 640
    height: 720

    Component {
        id: componentUnderTest

        LinkPreviewCard {
            type: Constants.LinkPreviewType.Standard
            linkData {
                threadAccessible: true
                title: "Example title"
                description: "Example description"
                domain: "www.example.com"
            }
        }
    }

    Component {
        id: delegateUnderTest
        LinkPreviewCardDelegate {
            unfurled: true
            empty: false
            immutable: true
            isLocalData: false
            loadingLocalData: false
            previewType: Constants.LinkPreviewType.StatusThread
            standardPreview: ({threadAccessible: true, title: "Planning", description: "Community", threadParentName: "general", hostname: "status.app"})
            standardPreviewThumbnail: null
            statusContactPreview: null
            statusContactPreviewThumbnail: null
            statusCommunityPreview: null
            statusCommunityPreviewIcon: null
            statusCommunityPreviewBanner: null
            statusCommunityChannelPreview: null
            statusCommunityChannelCommunityPreview: null
            statusCommunityChannelCommunityPreviewIcon: null
            statusCommunityChannelCommunityPreviewBanner: null
        }
    }

    TestCase {
        name: "LinkPreviewCard"
        when: windowShown

        function test_standardLink_showsTitle() {
            const card = createTemporaryObject(componentUnderTest, root)
            verify(card)

            const title = findChild(card, "linkPreviewTitle")
            verify(title)
            compare(title.text, "Example title")
            compare(findChild(card, "linkPreviewFooter").text, "www.example.com")
        }

        function test_threadOrigin_data() {
            return [
                {tag: "https DM", url: "https://status.app/p/?thread-id=thread", direct: true, group: false},
                {tag: "http DM", url: "http://status.app/p/?thread-id=thread", direct: true, group: false},
                {tag: "internal DM", url: "status-app://p/?thread-id=thread", direct: true, group: false},
                {tag: "community", url: "https://status.app/cc/channel?thread-id=thread#community", direct: false, group: false},
                {tag: "group", url: "https://status.app/g/?a2=group&thread-id=thread", direct: false, group: true}
            ]
        }

        function test_threadOrigin(data) {
            const card = createTemporaryObject(delegateUnderTest, root, {url: data.url})
            verify(card)
            compare(findChild(card, "linkPreviewDescription").text, "Community")
            compare(findChild(card, "linkPreviewFooter").text,
                    data.direct ? "Thread in direct message" : data.group ? "Thread in group chat" : "Thread in general")
        }

        function test_inaccessibleThreadHidesMetadataAndPhoto() {
            const card = createTemporaryObject(componentUnderTest, root, {type: Constants.LinkPreviewType.StatusThread})
            verify(card)
            card.linkData.title = "Private title"
            card.linkData.description = "Private origin"
            card.linkData.parentName = "Private parent"
            card.linkData.thumbnail = Qt.resolvedUrl("../../../ui/StatusQ/doc/src/images/status_banner.png")
            card.linkData.isDirectThread = true
            card.linkData.threadAccessible = false
            verify(waitForPolish(card.contentItem))
            compare(findChild(card, "linkPreviewTitle").text, "Unknown thread name")
            compare(findChild(card, "linkPreviewDescription").text, "Unknown")
            compare(findChild(card, "linkPreviewFooter").text, "Thread in Unknown")
            const banner = findChild(card, "linkPreviewBanner")
            verify(!banner.visible)
            verify(!banner.active)
            tryCompare(card, "implicitHeight", 120)
        }

        function test_threadContentsStayInsideCard_data() {
            return [
                {tag: "DM", url: "https://status.app/p/?thread-id=thread", width: 300, parent: "Alice", description: "Alice"},
                {tag: "legacy DM", url: "https://status.app/p/?thread-id=thread", width: 300, parent: "", description: "Alice › Planning"},
                {tag: "legacy group long text", url: "https://status.app/g/?a2=group&thread-id=thread", width: 180, parent: "", description: "Community › ".repeat(15) + "Planning"},
                {tag: "community without banner", url: "https://status.app/cc/channel?thread-id=thread#community", width: 300, parent: "#general", description: "Community"}
            ]
        }

        function test_threadContentsStayInsideCard(data) {
            const card = createTemporaryObject(delegateUnderTest, root, {
                url: data.url, width: data.width,
                standardPreview: {threadAccessible: true, title: "Planning", description: data.description,
                                  threadParentName: data.parent, hostname: "status.app"}
            })
            verify(card)
            verify(waitForPolish(card.contentItem))
            for (const name of ["linkPreviewIcon", "linkPreviewTitle", "linkPreviewDescription", "linkPreviewFooter"]) {
                const item = findChild(card, name)
                verify(item, name)
                const position = item.mapToItem(card, 0, 0)
                verify(position.y >= -0.5, name + " begins above the card")
                verify(position.y + item.height <= card.height + 0.5,
                       name + " extends below the card: " + (position.y + item.height) + " > " + card.height)
            }
        }

        function test_threadPreview_data() {
            return [
                {tag: "community thread", subtitle: "Status Community", isDirect: false, isGroup: false, parent: "#general", banner: Qt.resolvedUrl("../../../ui/StatusQ/doc/src/images/status_banner.png"), height: 290},
                {tag: "DM with photo", subtitle: "Alice", isDirect: true, isGroup: false, parent: "Alice", banner: Qt.resolvedUrl("../../../ui/StatusQ/doc/src/images/status_banner.png"), height: 290},
                {tag: "group with photo", subtitle: "Team", isDirect: false, isGroup: true, parent: "Team", banner: Qt.resolvedUrl("../../../ui/StatusQ/doc/src/images/status_banner.png"), height: 290},
                {tag: "DM thread", subtitle: "Alice", isDirect: true, isGroup: false, parent: "Alice", banner: "", height: 120}
            ]
        }

        function test_threadPreview(data) {
            const card = createTemporaryObject(componentUnderTest, root, {type: Constants.LinkPreviewType.StatusThread})
            verify(card)
            card.linkData.title = "<b>Release planning</b>"
            card.linkData.description = data.subtitle
            card.linkData.parentName = data.parent
            card.linkData.isDirectThread = data.isDirect
            card.linkData.isGroupThread = data.isGroup
            card.linkData.thumbnail = data.banner
            verify(waitForPolish(card.contentItem))
            compare(findChild(card, "linkPreviewTitle").text, "<b>Release planning</b>")
            compare(findChild(card, "linkPreviewTitle").textFormat, Text.PlainText)
            const footer = findChild(card, "linkPreviewFooter")
            verify(footer)
            compare(footer.text, data.isDirect ? "Thread in direct message" : data.isGroup ? "Thread in group chat" : "Thread in " + data.parent)
            compare(footer.textFormat, Text.PlainText)
            const description = findChild(card, "linkPreviewDescription")
            compare(description.text, data.subtitle)
            compare(description.textFormat, Text.PlainText)
            const icon = findChild(card, "linkPreviewIcon")
            verify(icon.visible)
            compare(icon.asset.name, "thread")
            compare(icon.asset.isImage, false)
            tryCompare(card, "implicitHeight", data.height)
        }
    }
}
