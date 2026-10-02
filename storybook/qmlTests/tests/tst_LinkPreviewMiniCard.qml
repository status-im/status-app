import QtQuick
import QtTest

import shared.controls.chat
import utils

Item {
    id: root

    Component {
        id: componentUnderTest

        LinkPreviewMiniCard {
            previewState: LinkPreviewMiniCard.State.Loaded
            type: Constants.LinkPreviewType.Standard
            linkData {
                title: "Example title"
                domain: "www.example.com"
                type: Constants.StandardLinkPreviewType.Link
            }
            userData.name: "Alice Status"
            communityData.name: "Test Community"
        }
    }

    TestCase {
        name: "LinkPreviewMiniCard"
        when: windowShown

        function createCard(props = {}) {
            const card = createTemporaryObject(componentUnderTest, root, props)
            verify(card)
            return card
        }

        function child(card, objectName) {
            const item = findChild(card, objectName)
            verify(item)
            return item
        }

        function test_standardLinkLoaded_showsTitleAndDomain() {
            const card = createCard()
            compare(child(card, "linkPreviewTitleText").text, "Example title")
            compare(child(card, "linkPreviewSubtitleText").text, "www.example.com")
        }

        function test_loading_hidesSubtitle() {
            const card = createCard({ previewState: LinkPreviewMiniCard.State.Loading })
            compare(child(card, "linkPreviewSubtitleText").visible, false)
            verify(child(card, "linkPreviewTitleText").text.length > 0)
        }

        function test_loadingFailed_hidesSubtitle() {
            const card = createCard({ previewState: LinkPreviewMiniCard.State.LoadingFailed })
            compare(child(card, "linkPreviewSubtitleText").visible, false)
        }

        function test_userProfileLoaded_showsDisplayName() {
            const card = createCard({ type: Constants.LinkPreviewType.StatusContact })
            compare(child(card, "linkPreviewTitleText").text, "Alice Status")
            compare(child(card, "linkPreviewSubtitleText").text, Constants.externalStatusLink)
        }

        function test_communityLoaded_showsCommunityName() {
            const card = createCard({ type: Constants.LinkPreviewType.StatusCommunity })
            compare(child(card, "linkPreviewTitleText").text, "Test Community")
            compare(child(card, "linkPreviewSubtitleText").text, Constants.externalStatusLink)
        }
    }
}
