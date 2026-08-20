import QtQuick

import StatusQ.Core.Theme

/*!
   \qmltype WalletAccountDelegateShell
   \inherits Item
   \inqmlmodule AppLayouts.Wallet.controls
   \brief Cheap stand-in for an account row, with the rich row behind an async Loader.

   A \c ListView refill is a single uninterruptible call inside the window's
   polish phase, and visible delegates are created with \c AsynchronousIfNested —
   so a list laid out after its enclosing Loader is already Ready builds every
   visible row synchronously. This shell is what the refill builds instead: row
   geometry plus placeholder tiles, with \c sourceComponent incubated afterwards
   in metered bites. Same shape as \c TokenDelegateShell (issues/0007).

   \qml
        delegate: WalletAccountDelegateShell {
            width: ListView.view.width
            sourceComponent: StatusListItem { width: parent.width }
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
       title + subtitle row, which is what an account row resolves to; the two
       staying equal is what keeps contentHeight and the scroll position still
       while rows fill in, and tst_WalletAccountDelegateShell guards it.
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

    // Tiles in the shape of the row, mirroring WalletAccountsSkeleton: the list
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
            width: 40
            height: 40
            radius: width / 2
            color: placeholder.tileColor
        }
        Rectangle {
            x: Theme.padding + 40 + Theme.padding
            y: parent.height / 2 - 15
            width: 120
            height: 14
            radius: 4
            color: placeholder.tileColor
        }
        Rectangle {
            x: Theme.padding + 40 + Theme.padding
            y: parent.height / 2 + 3
            width: 80
            height: 12
            radius: 4
            color: placeholder.tileColor
        }
    }
}
