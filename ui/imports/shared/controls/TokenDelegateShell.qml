import QtQuick

import StatusQ.Core.Theme

/*!
   \qmltype TokenDelegateShell
   \inherits Item
   \inqmlmodule shared.controls
   \brief Cheap stand-in for a token row, with the rich row behind an async Loader.

   A \c ListView refill is a single uninterruptible call inside the window's
   polish phase, and visible delegates are created with \c AsynchronousIfNested —
   so a list laid out after its enclosing Loader is already Ready builds every
   visible row synchronously. This shell is what the refill builds instead: row
   geometry plus placeholder tiles, with \c sourceComponent incubated afterwards
   in metered bites.

   \qml
        delegate: TokenDelegateShell {
            width: ListView.view.width
            sourceComponent: TokenDelegate { width: parent.width }
        }
   \endqml
*/
Item {
    id: root

    //! The rich row. Always incubated; never built by the list's refill.
    property alias sourceComponent: contentLoader.sourceComponent

    readonly property alias contentItem: contentLoader.item
    readonly property bool contentReady: contentLoader.status === Loader.Ready

    /*!
       Row height before the content exists. 64 is StatusListItem's floor for a
       title + subtitle row, which is what TokenDelegate resolves to; the two
       staying equal is what keeps contentHeight and the scroll position still
       while rows fill in, and tst_TokenDelegateShell guards it.
    */
    readonly property int placeholderHeight: 64

    implicitHeight: !!contentLoader.item ? contentLoader.item.implicitHeight
                                         : root.placeholderHeight
    height: implicitHeight

    Loader {
        id: contentLoader

        asynchronous: true
        width: root.width
    }

    // Tiles in the shape of the row, mirroring WalletAssetListSkeleton: the list
    // fills over the whole incubated phase, and a blank row for that long reads
    // as breakage rather than as loading.
    Item {
        id: placeholder

        anchors.fill: parent
        visible: !root.contentReady

        readonly property color tileColor: Theme.palette.statusLoadingHighlight

        Rectangle {
            x: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: width / 2
            color: placeholder.tileColor
        }
        Rectangle {
            x: Theme.padding + 32 + Theme.padding
            y: parent.height / 2 - 16
            width: 90
            height: 15
            radius: 4
            color: placeholder.tileColor
        }
        Rectangle {
            x: Theme.padding + 32 + Theme.padding
            y: parent.height / 2 + 5
            width: 130
            height: 12
            radius: 4
            color: placeholder.tileColor
        }
        Rectangle {
            x: parent.width - Theme.padding - width
            y: parent.height / 2 - 16
            width: 100
            height: 15
            radius: 4
            color: placeholder.tileColor
        }
        Rectangle {
            x: parent.width - Theme.padding - width
            y: parent.height / 2 + 5
            width: 130
            height: 12
            radius: 4
            color: placeholder.tileColor
        }
    }
}
