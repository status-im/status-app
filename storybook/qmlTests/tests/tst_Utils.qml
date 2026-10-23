import QtQuick

import QtTest

import utils
import StatusQ.Core.Theme

Item {
    id: root

    readonly property string cloudinaryImage:
        "https://res.cloudinary.com/alchemyapi/image/upload/convert-png/nft"
    readonly property string cloudinaryVideo:
        "https://res.cloudinary.com/alchemyapi/video/fetch/f_png,so_0/nft.mp4"

    ListModel {
        id: activeNetworks

        ListElement { chainId: 1; layer: 1 }
        ListElement { chainId: 11155111; layer: 1 }
    }

    TestCase {
        name: "Utils_preferredOrFirstL1ChainId"

        function test_prefersAnActiveChain() {
            compare(Utils.preferredOrFirstL1ChainId(activeNetworks, 11155111), 11155111)
        }

        function test_fallsBackToTheFirstLayerOneChain() {
            compare(Utils.preferredOrFirstL1ChainId(activeNetworks, 84532), 1)
        }

        function test_prefersSepoliaWhenTestnetsAreEnabled() {
            compare(Utils.defaultSwapLaunchChainId(activeNetworks, true), 11155111)
        }

        function test_usesFirstLayerOneWhenTestnetsAreDisabled() {
            compare(Utils.defaultSwapLaunchChainId(activeNetworks, false), 1)
        }
    }

    TestCase {
        name: "Utils_resizedMediaSource"

        function test_pointsAreTurnedIntoPixels_data() {
            return [
                {tag: "grid tile", points: 150, expected: "w_300"},
                {tag: "detail view", points: 240, expected: "w_480"},
                {tag: "rounded up", points: 33.4, expected: "w_67"},
            ]
        }

        function test_pointsAreTurnedIntoPixels(data) {
            const result = Utils.resizedMediaSource(root.cloudinaryImage, data.points)
            compare(result, "https://res.cloudinary.com/alchemyapi/image/upload/"
                          + data.expected + ",c_limit,f_auto,q_auto/convert-png/nft")
        }

        function test_noWidthFallsBackToTheTileWidth() {
            // The default is a tile, so it must agree with what a tile asks for.
            compare(Utils.resizedMediaSource(root.cloudinaryImage),
                    Utils.resizedMediaSource(root.cloudinaryImage,
                                             Utils.defaultCollectibleTileWidth))
        }

        function test_videoFetchIsTransformedAheadOfTheStillFrameChain() {
            // A transformation placed before f_png,so_0 chains with it rather
            // than replacing it, which is what keeps the still frame a still.
            compare(Utils.resizedMediaSource(root.cloudinaryVideo, 240),
                    "https://res.cloudinary.com/alchemyapi/video/fetch/"
                    + "w_480,c_limit,f_auto,q_auto/f_png,so_0/nft.mp4")
        }

        function test_untouched_data() {
            return [
                {tag: "not cloudinary",
                 url: "https://i.seadn.io/s/raw/files/nft.jpg?w=1000"},
                {tag: "cloudinary, other delivery path",
                 url: "https://res.cloudinary.com/alchemyapi/raw/upload/blob"},
                {tag: "already carries a width",
                 url: "https://res.cloudinary.com/alchemyapi/image/upload/w_300,c_limit/nft"},
                {tag: "already carries a width, not first",
                 url: "https://res.cloudinary.com/alchemyapi/image/upload/c_limit,w_300/nft"},
                {tag: "local status-go media server",
                 url: "http://localhost:52286/collectibles?uid=1"},
            ]
        }

        function test_untouched(data) {
            compare(Utils.resizedMediaSource(data.url, 240), data.url)
        }

        function test_emptyStaysEmpty() {
            compare(Utils.resizedMediaSource("", 240), "")
            compare(Utils.resizedMediaSource(undefined, 240), "")
        }
    }

    TestCase {
        name: "Utils_collectibleSources"

        readonly property string thumbnail:
            "https://res.cloudinary.com/alchemyapi/image/upload/thumbnailv2/nft"
        readonly property string image:
            "https://res.cloudinary.com/alchemyapi/image/upload/convert-png/nft"

        function test_thumbnailIsPreferredOverTheImage() {
            compare(Utils.collectibleMediaSource(thumbnail, image), thumbnail)
            compare(Utils.collectibleMediaSource("", image), image)
            compare(Utils.collectibleMediaSource("", ""), "")
        }

        function test_thumbnailSourceCarriesTheHint() {
            compare(Utils.collectibleThumbnailSource(thumbnail, image, 150),
                    Utils.resizedMediaSource(thumbnail, 150))
        }

        function test_mediaSourceIsTheFallbackWithoutAHint() {
            // What the media components degrade to, so it must stay untouched.
            compare(Utils.collectibleMediaSource(thumbnail, image), thumbnail)
        }
    }

    TestCase {
        name: "Utils_isStatusDeepLink"

        function test_recognizesOnlyStatusDeepLinks_data() {
            return [
                {tag: "Status custom scheme", link: "status-app://cc/community-id", expected: true},
                {tag: "Status HTTPS link", link: "https://status.app/cc/community-id", expected: true},
                {tag: "Status HTTP link", link: "http://status.app/cc/community-id", expected: true},
                {tag: "lookalike host", link: "https://status.app.attacker.example/cc/community-id", expected: false},
                {tag: "Status host in query", link: "https://attacker.example/?next=status.app", expected: false},
                {tag: "custom scheme in query", link: "https://attacker.example/?next=status-app://cc/community-id", expected: false},
                {tag: "unsupported Status scheme", link: "ftp://status.app/cc/community-id", expected: false},
                {tag: "invalid URL", link: "status.app/cc/community-id", expected: false}
            ]
        }

        function test_recognizesOnlyStatusDeepLinks(data) {
            compare(Utils.isStatusDeepLink(data.link), data.expected)
        }
    }

    TestCase {
        name: "Utils_gifLinks"

        function test_isGifLink_data() {
            return [
                {tag: "Klipy", url: "https://static.klipy.com/ii/935d7ab9d8c6202580a668421940ec81/23/12/Baqa16H5.gif", expected: true},
                {tag: "uppercase extension", url: "https://media.example.com/animation.GIF", expected: true},
                {tag: "query string", url: "https://media.example.com/animation.gif?width=320", expected: true},
                {tag: "fragment", url: "https://media.example.com/animation.gif#preview", expected: true},
                {tag: "other image", url: "https://media.example.com/image.webp", expected: false},
                {tag: "suffix only", url: "https://media.example.com/animation.gifx", expected: false},
                {tag: "bare filename", url: "animation.gif", expected: false}
            ]
        }

        function test_isGifLink(data) {
            compare(Utils.isGifLink(data.url), data.expected)
        }

        function test_gifLinks_data() {
            return [
                {tag: "single GIF", text: "https://media.example.com/animation.gif", expected: 1},
                {tag: "spaces", text: "https://media.example.com/one.gif  https://media.example.com/two.gif", expected: 2},
                {tag: "newlines", text: "https://media.example.com/one.gif\nhttps://media.example.com/two.gif", expected: 2},
                {tag: "mixed whitespace", text: "\thttps://media.example.com/one.gif\r\n https://media.example.com/two.gif ", expected: 2},
                {tag: "non-GIF", text: "https://media.example.com/image.png", expected: 0},
                {tag: "missing", text: undefined, expected: 0}
            ]
        }

        function test_gifLinks(data) {
            compare(Utils.gifLinks(data.text).length, data.expected)
        }

        function test_isGifOnlyText_data() {
            return [
                {tag: "single GIF", text: "https://media.example.com/animation.gif", expected: true},
                {tag: "multiple GIFs", text: "https://media.example.com/one.gif\nhttps://media.example.com/two.gif", expected: true},
                {tag: "surrounding whitespace", text: "  https://media.example.com/animation.gif  ", expected: true},
                {tag: "text and GIF", text: "look at this https://media.example.com/animation.gif", expected: false},
                {tag: "empty", text: "", expected: false},
                {tag: "missing", text: undefined, expected: false},
                {tag: "non-GIF", text: "https://media.example.com/image.png", expected: false}
            ]
        }

        function test_isGifOnlyText(data) {
            compare(Utils.isGifOnlyText(data.text), data.expected)
        }
    }

    TestCase {
        name: "Utils_swapProviderDappDetails"

        function test_knownProviderIsResolvedByProcessorName() {
            const details = Utils.getSwapProviderDappDetails(Constants.swap.relayProcessorName)
            verify(!!details)
            compare(details.name, Constants.swap.relayName)
            compare(details.url, Constants.swap.relayUrl)
            compare(details.icon, Assets.png("swap/%1".arg(Constants.swap.relayIcon)))

            compare(Utils.getSwapProviderDappDetails(Constants.swap.lifiProcessorName).name, Constants.swap.lifiName)
            compare(Utils.getSwapProviderDappDetails(Constants.swap.paraswapProcessorName).name, Constants.swap.paraswapName)
        }

        function test_unknownOrEmptyProviderYieldsNothing() {
            compare(Utils.getSwapProviderDappDetails("SomethingElse"), undefined)
            compare(Utils.getSwapProviderDappDetails(""), undefined)
            compare(Utils.getSwapProviderDappDetails(undefined), undefined)
        }

        function test_swapProviderDisplayName_data() {
            return [
                { tag: "Relay", processorName: Constants.swap.relayProcessorName, expected: Constants.swap.relayName },
                { tag: "LiFi", processorName: Constants.swap.lifiProcessorName, expected: Constants.swap.lifiName },
                { tag: "Paraswap", processorName: Constants.swap.paraswapProcessorName, expected: Constants.swap.paraswapName },
                { tag: "a processor without a brand name is shown as it is", processorName: "Hop", expected: "Hop" },
                { tag: "nothing known", processorName: "", expected: "" },
            ]
        }

        function test_swapProviderDisplayName(data) {
            compare(Utils.swapProviderDisplayName(data.processorName), data.expected)
        }
    }
}
