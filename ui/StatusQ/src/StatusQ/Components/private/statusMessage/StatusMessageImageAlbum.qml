import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

RowLayout {
    id: root

    property var album: []
    property int albumCount: 0
    property real imageWidth: 144
    property int shapeType: -1
    property real loadingComponentHeight: 194

    // Switches scaling mode for AnimatedImage:
    // - false (default): PreserveAspectFit → full image visible, may letterbox.
    // - true: PreserveAspectCrop → fills container, may crop edges.
    property bool isFillCropMode: false

    // Controls whether a flexible "filler" Item is added at the end of the row.
    // - true (default): the row expands to fill all available width, and images
    //   are aligned to the left. Useful when the parent expects the row to span
    //   its full width.
    // - false: no filler is used; the row width matches exactly the content,
    //   with no extra space or trailing gap.
    property bool addFiller: true

    // Determines whether album images respond to user click.
    // - true (default): images are clickable; each image installs a MouseArea
    //   and emits the `imageClicked` signal when tapped or clicked.
    // - false: images are display-only with no interaction.
    property bool imageClickable: true

    // Cursor shape used when hovering over clickable album images.
    // - Default: Qt.PointingHandCursor (hand icon).
    // - Common alternatives: Qt.ArrowCursor, Qt.CrossCursor, etc.
    property int imageCursorShape: Qt.PointingHandCursor

    signal imageClicked(var image, var mouse, var imageSource)

    QtObject {
        id: d

        readonly property int totalAlbumItems: root.album && root.album.length !== undefined
                                               ? root.album.length
                                               : 0
    }

    spacing: 9
    Repeater {
        model: root.albumCount

        delegate: Loader {
            active: true
            objectName: "album_image_loader_" + index
            readonly property bool imageLoaded: index < d.totalAlbumItems
            readonly property bool isLastImagePlaceholder: root.albumCount < d.totalAlbumItems &&
                                                           index === root.albumCount - 1
            readonly property string imagePath: imageLoaded ? root.album[index] : ""
            sourceComponent: isLastImagePlaceholder ? lastImagePlaceholderComponent :
                                                      imageLoaded ? imageComponent : imagePlaceholderComponent
        }
    }

    Component {
        id: imageComponent
        StatusImageMessage {
            Layout.alignment: Qt.AlignLeft
            isFillCropMode: root.isFillCropMode
            imageWidth: root.imageWidth
            source: imagePath
            shapeType: root.shapeType
            imageClickable: root.imageClickable
            imageCursorShape: root.imageCursorShape

            onClicked: (image, mouse, imageSource) => root.imageClicked(image, mouse, imageSource)
        }
    }

    Component {
        id: imagePlaceholderComponent
        LoadingComponent {
            radius: 4
            height: root.loadingComponentHeight
            width: root.imageWidth
        }
    }

    Component {
        id: lastImagePlaceholderComponent
        Rectangle {
            color: Theme.palette.primaryColor1
            radius: 16
            height: root.isFillCropMode ? root.imageWidth : root.loadingComponentHeight
            width: root.imageWidth

            StatusBaseText {
                readonly property int reminingItems: d.totalAlbumItems - root.albumCount + 1
                anchors.centerIn: parent
                color: Theme.palette.indirectColor1
                font.pixelSize: Theme.fontSize(19)
                font.weight: Font.Medium
                text: reminingItems + "+"
            }
        }
    }

    // Filler
    Item {
        Layout.fillWidth: true
        visible: root.addFiller
    }
}
