import QtQuick
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import Models
import AppLayouts.Profile.helpers
import shared.views.chat
import AppLayouts.Chat.stores as ChatStores
import utils

import Storybook.Testing

Item {
    id: root
    width: 800
    height: 800
    property int parseCalls: 0
    readonly property string url: "https://status.app/u/example#key"

    Component {
        id: messageComponent
        StatusMessage {
            id: message
            width: 400
            showHeader: false
            property var inlineLinks: ({[root.url]: {title: "Alice", image: ""}})
            textAppearance: MessageTextAppearance { theme: message.Theme }
            previewAppearance: ReplyTextAppearance { theme: message.Theme }
            messageDetails: StatusMessageDetails {
                contentType: StatusMessage.ContentType.Text
                unparsedText: "Before " + root.url + " after"
                inlineLinks: message.inlineLinks
            }
        }
    }
    Component { id: spyComponent; SignalSpy { signalName: "linkActivated" } }
    MessageView {
        id: viewFixture
        visible: false
        width: 600
        unparsedText: root.url + " contact"
        textAppearance: MessageTextAppearance { theme: viewFixture.Theme }
        previewAppearance: ReplyTextAppearance { theme: viewFixture.Theme }
        messageStore: ChatStores.MessageStore {
            function parseProfileUrl(url) {
                return url === root.url ? {publicKey: "key", displayName: "Alice"} : null
            }
        }
        linkPreviewModel: null
    }

    LinkPreviewModel { id: previewData }
    ListModel {
        id: previewRows
        Component.onCompleted: {
            const contact = previewData.getContactLinkPreview()
            contact.url = root.url
            contact.isLocalData = true
            contact.loadingLocalData = false
            contact.statusContactPreviewThumbnail.url = ""
            contact.statusContactPreview.emojiHash = "[]"
            append(contact)
            const external = previewData.getStandardLinkPreview()
            external.url = "https://example.org"
            external.isLocalData = true
            external.loadingLocalData = false
            external.standardPreviewThumbnail.url = ""
            append(external)
        }
        function getLinkPreviewType(url) {
            return url === root.url ? Constants.LinkPreviewType.StatusContact : Constants.LinkPreviewType.Standard
        }
    }
    MessageView {
        id: previewFixture
        x: root.width
        width: 600
        unparsedText: "Contact " + root.url + " and https://example.org"
        textAppearance: MessageTextAppearance { theme: previewFixture.Theme }
        previewAppearance: ReplyTextAppearance { theme: previewFixture.Theme }
        linkPreviewModel: previewRows
        messageStore: ChatStores.MessageStore {
            function parseProfileUrl(url) {
                return url === root.url ? {publicKey: "key", displayName: "Alice"} : null
            }
        }
    }

    ListModel {
        id: contacts
        ListElement { pubKey: "key"; displayName: "Local Alice"; thumbnailImage: "avatar.png" }
    }
    ProfileLinkResolver {
        id: resolver
        text: root.url + " " + root.url + " `" + root.url
              + "` https://example.org/u/key https://status.app/c/community"
        contactsModel: contacts
        parseProfileUrl: url => {
            ++root.parseCalls
            return {publicKey: "key", displayName: "Shared Alice"}
        }
    }
    ProfileLinksPage {
        id: pageFixture
        x: root.width
        width: 800
        height: 600
    }

    TestCase {
        name: "ProfileLinks"
        when: windowShown

        function createMessage() {
            const message = createTemporaryObject(messageComponent, root)
            verify(message)
            return message
        }

        function textField(message) {
            const field = findChild(message, "StatusTextMessage_chatText")
            verify(field)
            return field
        }

        function test_inlineSupportIsOptionalAndKeepsRenderer() {
            const message = createTemporaryObject(messageComponent, root, {inlineLinks: ({})})
            verify(message)
            const field = textField(message)
            const support = findChild(message, "StatusTextMessage_inlineLinkSupport")
            verify(support)
            verify(!support.active)
            compare(support.item, null)
            compare(field.text, "Before " + root.url + " after")
            compare(field.inlineIconRects.length, 0)
            field.forceActiveFocus()
            verify(field.activeFocus)

            message.inlineLinks = ({[root.url]: {title: "Alice"}})
            verify(support.active && !!support.item)
            compare(textField(message), field)
            verify(field.activeFocus)
            compare(field.text, "Before Alice after")
            compare(field.inlineIconRects.length, 1)

            message.inlineLinks = ({})
            verify(!support.active)
            compare(support.item, null)
            compare(textField(message), field)
            verify(field.activeFocus)
            compare(field.text, "Before " + root.url + " after")
            compare(field.inlineIconRects.length, 0)
        }

        function test_inlineAndCopy() {
            const message = createMessage()
            const field = textField(message)
            compare(field.text, "Before Alice after")
            compare(field.inlineIconRects.length, 1)
            verify(findChild(message, "inlineLinkAvatar"))
            field.selectAll()
            compare(message.selectedText, "Before " + root.url + " after")
            const span = field.segments.find(s => s.inlineIconOffsets.length > 0)
            compare(span.href, root.url)
            verify(span.mention)
            verify(!span.underline)
            const icon = field.inlineIconRects[0].rect
            compare(field.linkAt(icon.x + icon.width / 2, icon.y + icon.height / 2), root.url)
            const spy = createTemporaryObject(spyComponent, root, {target: message})
            mouseClick(field, icon.x + icon.width / 2, icon.y + icon.height / 2)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], root.url)
        }

        function test_themeAndClearing() {
            const message = createMessage()
            message.messageDetails.inlineLinks = ({[root.url]: {title: "Alice with a very long profile name", image: ""}})
            const field = textField(message)
            field.selectAll()
            for (const style of [Theme.Style.Dark, Theme.Style.Light]) {
                message.Theme.style = style
                compare(message.selectedText, "Before " + root.url + " after")
            }
            message.messageDetails.unparsedText = "plain"
            compare(field.inlineIconRects.length, 0)
            compare(field.text, "plain")
        }

        function test_codeAndAuthoredLabelsStayIntact() {
            const message = createMessage()
            const source = "`" + root.url + "`\n[Custom label](" + root.url + ")\nhttps://example.org"
            message.messageDetails.unparsedText = source
            compare(textField(message).inlineIconRects.length, 0)
            verify(textField(message).text.includes(root.url))
            verify(textField(message).text.includes("Custom label"))
        }

        function test_standaloneLinkKeepsExistingPresentation() {
            const message = createMessage()
            const field = textField(message)
            for (const source of [root.url, " \n" + root.url + "\n", "**" + root.url + "**"]) {
                message.messageDetails.unparsedText = source
                compare(field.inlineIconRects.length, 0)
                compare(findChild(message, "StatusTextMessage_inlineLinkSupport").item, null)
                verify(field.text.includes(root.url))
            }
            message.messageDetails.unparsedText = "Contact " + root.url
            compare(field.inlineIconRects.length, 1)
            compare(field.text, "Contact Alice")
        }

        function test_quotesRepeatedLinksAndPartialSelection() {
            const message = createMessage()
            message.messageDetails.unparsedText = "> " + root.url + " and " + root.url
            const field = textField(message)
            compare(field.inlineIconRects.length, 2)
            field.selectAll()
            compare(message.selectedText, "> " + root.url + " and " + root.url)
            // Leading padding, icon and gap occupy four document characters.
            field.select(4, 9)
            compare(message.selectedText, "> Alice")
        }

        function test_backgroundStaysWithTranslatedMessageAfterColorChange() {
            const message = createMessage()
            message.x = 100
            message.y = 100
            message.messageDetails.unparsedText = "Contact " + root.url
            const field = textField(message)
            const icon = field.inlineIconRects[0].rect
            for (const color of ["red", "blue"]) {
                message.textAppearance.mentionBackground = color
                const image = grabImage(root)
                const scale = image.width / root.width
                let matches = 0
                for (let x = icon.x + icon.width; x < icon.x + icon.width + 25; ++x) {
                    for (let y = icon.y; y < icon.y + icon.height; ++y) {
                        const point = field.mapToItem(root, x, y)
                        const pixel = image.pixel(Math.floor(point.x * scale), Math.floor(point.y * scale))
                        if (Qt.colorEqual(pixel, color))
                            ++matches
                    }
                }
                verify(matches > 10, "Inline background must stay behind its label after changing to " + color)
            }
        }
    }

    TestCase {
        id: resolverLoaded
        name: "ProfileLinksResolverLoaded"
        when: windowShown && resolver.links[root.url]?.title === "Local Alice"

        function test_metadataAndDeduplication() {
            compare(root.parseCalls, 1)
            compare(resolver.links[root.url].image, "avatar.png")
            contacts.setProperty(0, "displayName", "Renamed Alice")
        }
    }

    TestCase {
        id: resolverRenamed
        name: "ProfileLinksResolverRenamed"
        when: resolverLoaded.completed && resolver.links[root.url]?.title === "Renamed Alice"

        function test_contactUpdate() {
            compare(resolver.links[root.url].title, "Renamed Alice")
            resolver.text = "https://status.app/u/invalid"
            resolver.parseProfileUrl = url => null
        }
    }

    TestCase {
        name: "ProfileLinksResolverCleared"
        when: resolverRenamed.completed && Object.keys(resolver.links).length === 0

        function test_parserRebinding() {
            compare(Object.keys(resolver.links).length, 0)
        }
    }

    TestCase {
        name: "ProfileLinksStorybook"
        readonly property var message: windowShown ? findChild(pageFixture, "profileLinkMessage") : null
        readonly property var field: message && Object.keys(message.messageDetails.inlineLinks).length
            ? findChild(message, "StatusTextMessage_chatText") : null
        when: windowShown && field?.inlineIconRects.length === 1

        function test_resolvedProfileAndTheme() {
            verify(field.text.includes("JohnDoe.ETH"))
            const avatar = findChild(pageFixture, "inlineLinkAvatar")
            verify(avatar)
            verify(avatar.asset.name.startsWith("data:image/svg+xml,"))
            for (const style of [Theme.Style.Dark, Theme.Style.Light]) {
                pageFixture.Theme.style = style
                compare(field.inlineIconRects.length, 1)
            }
        }
    }

    TestCase {
        id: viewLoaded
        name: "ProfileLinksMessageView"
        readonly property var field: viewFixture.status === Loader.Ready
            ? findChild(viewFixture, "StatusTextMessage_chatText") : null
        when: windowShown && field?.text === "Alice contact" && field.inlineIconRects.length === 1

        function test_navigationAndCopy() {
            viewFixture.visible = true
            const spy = createTemporaryObject(spyComponent, root, {target: Global, signalName: "activateDeepLink"})
            const icon = field.inlineIconRects[0].rect
            mouseClick(field, icon.x + icon.width / 2, icon.y + icon.height / 2)
            mouseClick(field, icon.x + icon.width + 12, icon.y + icon.height / 2)
            compare(spy.count, 2)
            compare(spy.signalArguments[0][0], root.url)
            compare(spy.signalArguments[1][0], root.url)
            field.selectAll()
            compare(field.selectedText, root.url + " contact")
            viewFixture.visible = false
            viewFixture.unparsedText = "Another message"
        }
    }

    TestCase {
        name: "ProfileLinksMessageViewRebound"
        readonly property var field: viewLoaded.field
        when: viewLoaded.completed && field?.text === "Another message"

        function test_oldLinkRemoved() {
            compare(field.inlineIconRects.length, 0)
        }
    }

    TestCase {
        id: inlinePreviews
        name: "ProfileLinksInlinePreviews"
        readonly property var field: previewFixture.status === Loader.Ready
            ? findChild(previewFixture, "StatusTextMessage_chatText") : null
        readonly property var message: {
            let item = field
            while (item && !(item instanceof StatusMessage))
                item = item.parent
            return item
        }
        property var linksView: null
        property var contactCard: null
        when: windowShown && field?.text.includes("Contact Alice") && !!message

        function test_onlyMatchingPreviewIsOmitted() {
            linksView = findChild(previewFixture, "LinksMessageView")
            verify(linksView)
            contactCard = findChild(linksView, "linkPreviewCard_" + root.url)
            verify(contactCard)
            compare(message.linkPreviewModel, previewRows)
            tryCompare(contactCard, "visible", false)
            const externalCard = findChild(linksView, "linkPreviewCard_https://example.org")
            verify(externalCard)
            tryCompare(externalCard, "visible", true)
            compare(externalCard.url, "https://example.org")
            tryVerify(() => linksView.implicitHeight > 0)
            compare(previewRows.count, 2)
            previewRows.remove(1)
            previewFixture.unparsedText = root.url
        }
    }

    TestCase {
        id: standalonePreview
        name: "ProfileLinksStandalonePreview"
        when: inlinePreviews.completed && inlinePreviews.field?.text === root.url
              && inlinePreviews.message?.linkPreviewModel === previewRows

        function test_standalonePreviewIsRestored() {
            compare(previewRows.count, 1)
            compare(inlinePreviews.field.inlineIconRects.length, 0)
            tryCompare(inlinePreviews.contactCard, "visible", true)
            compare(inlinePreviews.contactCard.url, root.url)
            tryVerify(() => inlinePreviews.linksView.implicitHeight > 0)
            verify(inlinePreviews.linksView.parent.visible)
            previewFixture.unparsedText = root.url + " contact"
        }
    }

    TestCase {
        name: "ProfileLinksRecycledPreview"
        when: standalonePreview.completed && inlinePreviews.field?.text === "Alice contact"
              && inlinePreviews.message?.linkPreviewModel === previewRows

        function test_rebindOmitsDuplicateWithoutLeavingSpace() {
            compare(previewRows.count, 1)
            compare(inlinePreviews.field.inlineIconRects.length, 1)
            tryCompare(inlinePreviews.contactCard, "visible", false)
            tryCompare(inlinePreviews.linksView, "implicitHeight", 0)
            tryCompare(inlinePreviews.linksView.parent, "visible", false)
        }
    }

}
