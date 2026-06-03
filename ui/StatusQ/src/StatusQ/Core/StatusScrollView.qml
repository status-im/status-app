import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Templates as T

import StatusQ.Controls
import StatusQ.Core.Utils
import StatusQ.Core.Theme

/*!
   \qmltype StatusScrollView
   \inherits Flickable
   \inqmlmodule StatusQ.Core
   \since StatusQ.Core 0.1
   \brief ScrollView component based on a Flickable with padding and scrollbars.

   The \c StatusScrollView can be used just like a plain ScrollView but without ability to decarate existing Flickable.

   A presenation on using StatusScrollView can be found here:
   https://docs.google.com/presentation/d/1ZZeg9j2fZMV-iHreu_Wsl1u6D9POH7SlUO78ZXNj-AI

   Simple example of how to use it:

   \qml
        StatusScrollView {
            id: scrollView

            // Give scrollview some size
            anchors.fill: parent

            // No need to specify `contentWidth` and `contentHeight`. For a single child item
            // it will be calculated automatically from *implicit* size of the item.
            // This doens't work if the item has no implicit size specified, even having `width`/`height`.

            // Also no need to set `implicitWidth` and `implicitHeight`.

            ColumnLayout {
                width: 400
            }
        }
   \endqml


   If you want the content to fill available width:
    - bind `ScrollView.contentWidth` to `availableWidth`
    - bind content `width` to `availableWidth`

   \qml
        StatusScrollView {
            id: scrollView

            anchors.fill: parent
            contentWidth: availableWidth

            ColumnLayout {
                width: scrollView.availableWidth
            }
        }
   \endqml

   When using inside a popup, there're 2 ways of achivieng nice paddings:

    1. Apply paddings of `StatusScrollView`

        Use when `StatusScrollView` is the only direct child of popup's `contentItem`.
        If you have other items outside the scroll view, you will have to manually apply paddings to them as well.

       \qml
            StatusModal {
                padding: 0

                // Don't override `contentItem`

                StatusScrollView {
                    id: scrollView

                    anchors.fill: parent
                    contentWidth: availableWidth

                    padding: 16 // This is default value

                    Text {
                        width: scrollView.availableWidth
                        wrapMode: Text.WrapAnywhere
                        text: "long text here"
                    }
                }
            }
       \endqml


    2. Apply paddings of the popup and make `StatusScrollView` scroll bars non-attached

       Use when `StatusScrollView`/`StatusListView` is not a direct child of `contentItem`, or it's not the only child.

       Though this requires more coding and custom wrappers, the result is very neat.
       All popup contents are aligned to given paddings, but the scroll bar doesn't overlay
       the content and is positioned right inside the padding.

       This works great for `StatusListView` as well.

       \qml
            StatusModal {
                padding: 16

                ColumnLayout {
                    anchors.fill: parent

                    Text {
                        Layout.fillWidth: true
                        text: "This header is fixed and not scrollable"
                    }

                    Item {
                        // We want to have a non-attached ScrollBar, but the parent can't be a Layout.
                        // So we have to create a simple wrapper and use it as a parent for the ScrollBar

                        id: scrollViewWrapper

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitWidth: scrollView.implicitWidth
                        implicitHeight: scrollView.implicitHeight

                        StatusScrollView {
                            id: scrollView

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: availableWidth

                            padding: 0

                            ScrollBar.vertical: StatusScrollBar {
                                parent: scrollViewWrapper           // parent to wrapper
                                anchors.top: scrollView.top
                                anchors.bottom: scrollView.bottom
                                anchors.left: scrollView.right
                                anchors.leftMargin: 1
                            }

                            Text {
                                width: scrollView.availableWidth
                                wrapMode: Text.WrapAnywhere
                                text: "long scrollable text here"
                            }
                        }
                    }
                }
            }
       \endqml

    If you want to give the popup some default width, but keep the automatic adjustment to screen size,
    set the `StatusScrollView.implicitWidth` to desirable value. This will preseve all automations
    and keep the padding and margins.

   For a list of components available see StatusQ.
*/

T.ScrollView {
    id: root

    readonly property Flickable flickable: root.contentItem

    function ensureVisible(rect) {
        Utils.ensureVisible(flickable, rect)
    }

    function applyFlickableFix() {
        flickable.boundsBehavior = Flickable.StopAtBounds
        flickable.maximumFlickVelocity = 2000
        flickable.synchronousDrag = true
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    padding: 16 // Default value to fit StatusScrollBar with a gentle margin of 1px on each side
    clip: true

    Component.onCompleted: {
        applyFlickableFix()
    }

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Home:
            scrollHome()
            event.accepted = true
            break
        case Qt.Key_End:
            scrollEnd()
            event.accepted = true
            break
        case Qt.Key_PageUp:
            scrollPageUp()
            event.accepted = true
            break
        case Qt.Key_PageDown:
            scrollPageDown()
            event.accepted = true
            break
        }
    }

    function scrollHome() {
        flickable.contentY = 0
    }

    function scrollEnd() {
        flickable.contentY = Math.max(0, flickable.contentHeight - flickable.height)
    }

    function scrollPageUp() {
        root.ScrollBar.vertical.decrease()
    }

    function scrollPageDown() {
        root.ScrollBar.vertical.increase()
    }

    ScrollBar.vertical: StatusScrollBar {
        parent: root
        x: root.mirrored ? 1 : root.width - width - 1
        y: root.topPadding
        height: root.availableHeight
        active: root.ScrollBar.horizontal.active
        policy: ScrollBar.AsNeeded
        visible: resolveVisibility(policy, root.availableHeight, root.contentHeight)
    }

    ScrollBar.horizontal: StatusScrollBar {
        parent: root
        x: root.leftPadding
        y: root.height - height - 1
        width: root.availableWidth
        active: root.ScrollBar.vertical.active
        policy: ScrollBar.AsNeeded
        visible: resolveVisibility(policy, root.availableWidth, root.contentWidth)
    }
}
