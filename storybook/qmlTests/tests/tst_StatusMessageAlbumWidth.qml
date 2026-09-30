import QtQuick
import QtQuick.Layouts
import QtTest

import StatusQ.Components

import Models

/*
 Device-observed livelock: an image-album message inside a QQuickLayout host
 diverges — StatusMessageImageAlbum was bound to messageLayout.width, the
 wrapping Loader mirrors its item's width as implicitWidth, and that implicit
 flows back out through the contentItem into the width, adding margins on
 every polish pass (+~57 px, forever, 100% main thread). A ListView host
 masked it by hard-pinning the delegate width; layout hosts (the flickable
 message view) do not.
*/
Item {
    id: root

    width: 600
    height: 800

    Component {
        id: hostComponent

        GridLayout {
            width: 600
            columns: 1

            StatusMessage {
                objectName: "albumMessage"

                Layout.fillWidth: true

                timestamp: Date.now()

                messageDetails {
                    contentType: StatusMessage.ContentType.Image
                    messageText: ""
                    unparsedText: ""
                    amISender: false
                    album: [ModelsData.banners.coinbase, ModelsData.icons.status]
                    albumCount: 2
                    sender.displayName: "Peer"
                }
            }
        }
    }

    TestCase {
        name: "StatusMessageAlbumWidth"
        when: windowShown

        function test_albumMessageWidthStaysBoundedInLayoutHost() {
            const host = createTemporaryObject(hostComponent, root)
            verify(!!host)
            const message = findChild(root, "albumMessage")
            verify(!!message)

            // let several polish passes run — the runaway grows every pass
            for (let i = 0; i < 6; ++i)
                waitForRendering(host)

            const sampled = message.width
            compare(sampled, root.width,
                    "album message must fill its host exactly — neither outgrow nor undershoot it")

            wait(200)
            fuzzyCompare(message.width, sampled, 1,
                         "album message width must be stable across polish passes, "
                         + sampled + " -> " + message.width)
        }
    }
}
