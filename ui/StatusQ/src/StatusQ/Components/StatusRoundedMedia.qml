import QtQuick
import QtQml
import StatusQ.Core
import StatusQ.Core.Theme

/*!
    \qmltype StatusRoundedMedia
    \inherits StatusRoundedComponent
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Specialization of StatusRoundedComponent which handles different media types as content.

    This component is a StatusRoundedComponent which is able to display several types of media using
    the corresponding component according to the provided \l{https://www.iana.org/assignments/media-types/media-types.xhtml}{media type}, 
    with the posibility of diplaying a fallback image if the media fails to load properly.
    
    The list of supported media types and how the component to display them is chosen is the following:
    
    - \c image
    Initially, we try to display the media using StatusAnimatedImage. If loading fails, we try using
    StatusImage. If that results in an error as well, we display the fallback image using StatusImage.

    - \c video
    Initially, we try to display the media using StatusVideo. If that results in an error, 
    we display the fallback image using StatusImage.

    - For any other media type, we default to showing the fallback image using StatusImage.

    Example of how to use it:

    \qml
        StatusRoundedMedia {
            width: 100
            height: 100
            mediaUrl: "qrc:/demoapp/data/test-video.avi"
            mediaType: "video"
            fallbackImageUrl: "qrc:/demoapp/data/test-image.png"
        }
    \endqml
*/
StatusRoundedComponent {
    id: root

    enum MediaType {
        Image,
        Video,
        Unknown
    }

    /*!
        \qmlproperty url StatusRoundedMedia::mediaUrl

        Used to set the source for the main media we want to display.

    */
    property url mediaUrl

    /*!
        \qmlproperty string StatusRoundedMedia::mediaType

         \l{https://www.iana.org/assignments/media-types/media-types.xhtml}{Media type} corresponding to the media pointed to by mediaUrl.

    */
    property string mediaType

    /*!
        \qmlproperty url StatusRoundedMedia::fallbackImageUrl

        Image shown in case attempting to load the media pointed to by mediaUrl results in an error.

    */
    property url fallbackImageUrl

    /*!
        \qmlproperty int StatusRoundedMedia::fillMode
        helps set fillModel for the Media file loaded
    */
    property int fillMode: Image.PreserveAspectFit

    /*!
        \qmlproperty int StatusRoundedMedia::manualMaxDimension
        is used to set dimension for the image in case of portrait or landscape
        when fillMode = Image.PreserveAspectFit
        if not set the width/height of parent will be considered
    */
    property int manualMaxDimension: 0

    /*!
        \qmlproperty bool StatusRoundedMedia::allowAnimation

        When false, always render a still — for small tiles where the animation
        URL is the full-size asset.
    */
    property bool allowAnimation: true

    /*!
        \qmlproperty bool StatusRoundedMedia::interactive

        Enable mouse interaction with the media.
    */
    property bool interactive: false

    /*!
        \qmlproperty bool StatusRoundedMedia::isEmpty

        Media source is empty.
    */
    property bool isEmpty: false

    readonly property int componentMediaType: {
        if (!root.allowAnimation)
            return StatusRoundedMedia.MediaType.Image
        if (root.mediaType.startsWith("image"))
            return StatusRoundedMedia.MediaType.Image
        if (root.mediaType.startsWith("video"))
            return StatusRoundedMedia.MediaType.Video
        return StatusRoundedMedia.MediaType.Unknown
    }

    signal imageClicked(var image, bool plain)
    signal videoClicked(url mediaUrl)
    signal openImageContextMenu(url url, bool isGif, real x, real y)
    signal openVideoContextMenu(url url, real x, real y)

    isLoading: {
        if (mediaLoader.status === Loader.Ready) {
            return mediaLoader.item.isLoading
        }
        return true
    }

    Binding on isError {
        when: mediaLoader.status === Loader.Ready
        value: mediaLoader.item ? mediaLoader.item.isError : true
        delayed: true
        restoreMode: Binding.RestoreBindingOrValue
    }

    onIsErrorChanged: {
        if (isError) {
            d.errorCounter = d.errorCounter + 1
            processError()
        }
    }

    Binding on isEmpty {
        when: mediaLoader.status === Loader.Ready
        value: !!mediaLoader.item && mediaLoader.item.source.toString() === ""
        delayed: true
        restoreMode: Binding.RestoreBindingOrValue
    }

    QtObject {
        id: d
        property bool isFallback: false
        property int errorCounter: 0
        property bool plainImage: false

        function reset() {
            isFallback = false
            errorCounter = 0
            plainImage = false
        }
    }

    implicitWidth: {
        // Use Painted width so that the rectangle follow width of the image actually painted
        if(!!mediaLoader.item && (mediaLoader.item.paintedWidth > 0 || mediaLoader.item.paintedHeight > 0)) {
            return mediaLoader.item.paintedWidth
        }
        return root.manualMaxDimension
    }
    implicitHeight: {
        // Use Painted height so that the rectangle follows height of the image actually painted
        if(!!mediaLoader.item && (mediaLoader.item.paintedWidth > 0 || mediaLoader.item.paintedHeight > 0)) {
            return mediaLoader.item.paintedHeight
        }
        return root.manualMaxDimension
    }

    StatusMouseArea {
        anchors.fill: parent
        enabled: root.enabled && root.interactive && mediaLoader.visible && mediaLoader.item
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (root.isError || root.isEmpty) {
                return
            }
            if (mouse.button === Qt.RightButton) {
                if (d.isFallback || componentMediaType === StatusRoundedMedia.MediaType.Image) {
                    root.openImageContextMenu(mediaLoader.item.source, !!mediaLoader.item.playing, mouse.x, mouse.y)
                } else if (componentMediaType === StatusRoundedMedia.MediaType.Video) {
                    root.openVideoContextMenu(mediaUrl, mouse.x, mouse.y)
                }

                return
            }

            if (!d.isFallback && componentMediaType === StatusRoundedMedia.MediaType.Video) {
                root.videoClicked(root.mediaUrl)
            } else {
                root.imageClicked(mediaLoader.item, d.plainImage)
            }
        }
    }

    Component.onCompleted: updateMediaLoader()
    onAllowAnimationChanged: updateMediaLoader()
    onMediaUrlChanged: updateMediaLoader()
    onComponentMediaTypeChanged: updateMediaLoader()
    onFallbackImageUrlChanged: updateMediaLoader()

    Loader {
        id: mediaLoader
        anchors.centerIn: parent
        // In case manualMaxDimension is not defined then use parent width and height instead
        width: root.manualMaxDimension === 0 ? parent.width : root.manualMaxDimension
        height: root.manualMaxDimension === 0 ? parent.height : root.manualMaxDimension
        visible: !root.isError && !root.isLoading
    }

    function updateMediaLoader() {
        d.reset()
        if (root.mediaUrl.toString() !== "") {
            if (componentMediaType === StatusRoundedMedia.MediaType.Image) {
                mediaLoader.setSource(root.allowAnimation ? "StatusAnimatedImage.qml"
                                                          : "StatusImage.qml",
                                    {
                                        "source": root.mediaUrl,
                                        "fillMode": root.fillMode,
                                        "sourceSize": Qt.size(width, height)
                                    });
                return
            } else if (componentMediaType === StatusRoundedMedia.MediaType.Video) {
                mediaLoader.setSource("StatusVideo.qml",
                                    {
                                        "source": root.mediaUrl,
                                        "fillMode": root.fillMode
                                    });
                return
            }
        }
        setFallbackImage()
    }

    function processError() {
        if (!d.isFallback) {
            // AnimatedImage sometimes cannot load stuff that plan Image can, try that first.
            // With animation disallowed the media is already a plain Image, so retrying the
            // same URL would only download it a second time.
            if (root.allowAnimation && componentMediaType === StatusRoundedMedia.MediaType.Image
                    && d.errorCounter <= 1) {
                d.plainImage = true
                mediaLoader.setSource("StatusImage.qml",
                                    {
                                        "source": root.mediaUrl,
                                        "fillMode": root.fillMode,
                                        "sourceSize": Qt.size(width, height)
                                    })
                return
            } else if (root.fallbackImageUrl !== "") {
                setFallbackImage()
                return
            }
        }
        setEmptyComponent()
    }

    function setFallbackImage() {
        d.plainImage = true
        d.isFallback = true
        mediaLoader.setSource("StatusImage.qml",
                            {
                                "source": root.fallbackImageUrl,
                                "fillMode": root.fillMode,
                                "sourceSize": Qt.size(width, height)
                            })
    }

    function setEmptyComponent() {
        d.plainImage = true
        mediaLoader.setSource("StatusImage.qml",
                            {
                                "source": "",
                                "fillMode": root.fillMode,
                                "sourceSize": Qt.size(-1, -1)
                            });
    }
}
