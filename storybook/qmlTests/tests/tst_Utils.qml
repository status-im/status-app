import QtQuick

import QtTest

import utils

Item {
    id: root

    readonly property string cloudinaryImage:
        "https://res.cloudinary.com/alchemyapi/image/upload/convert-png/nft"
    readonly property string cloudinaryVideo:
        "https://res.cloudinary.com/alchemyapi/video/fetch/f_png,so_0/nft.mp4"

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
}
