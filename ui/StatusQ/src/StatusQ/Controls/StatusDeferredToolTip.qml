import QtQuick

import StatusQ.Controls

/*!
   \qmltype StatusDeferredToolTip
   \inherits Loader
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief A StatusToolTip that is not built until it is first asked to show.

   Controls that declare one tooltip per instance - every StatusBaseButton,
   StatusFlatRoundButton or StatusListItem - otherwise build a Popup subtree per
   instance for a hover that may never happen. Configure this like a
   StatusToolTip and drive \c visible; the popup is created the first time
   \c visible turns true and is kept alive from then on.

   \qml
        StatusDeferredToolTip {
            target: root
            text: qsTr("Copy")
            visible: !!text && root.hovered
        }
   \endqml

   For a list of components available see StatusQ.
*/
Loader {
    id: root

    /*!
       Item the tooltip is positioned against. Defaults to the item this was
       declared in, which is what an inline StatusToolTip would have used.
    */
    property Item target: root.parent

    property string text
    property int orientation: StatusToolTip.Orientation.Top

    /*!
       Negative values keep StatusToolTip's own defaults.
    */
    property int maxWidth: -1
    property int delay: -1

    /*!
       Keeps the arrow pointing at the centre of \c target once the popup is
       clamped against the window edge.
    */
    property bool centerArrowOnTarget: false

    /*!
       objectName given to the tooltip once it is created.
    */
    property string tooltipObjectName

    readonly property bool opened: !!item && item.opened

    // Unlike a StatusToolTip - a Popup, and so not a visual child - this
    // placeholder is an Item, and it turns visible while the tooltip shows.
    // Declare it outside positioners and layouts, or it will claim a cell there.
    visible: false
    width: 0
    height: 0

    active: false
    onVisibleChanged: if (visible) active = true

    sourceComponent: StatusToolTip {
        id: tip

        // The popup is born at the instant it is asked to show. QQuickToolTip
        // only applies its show delay to an already completed popup, so the show
        // request is withheld until then.
        property bool completed: false
        Component.onCompleted: tip.completed = true

        objectName: root.tooltipObjectName
        parent: root.target
        text: root.text
        orientation: root.orientation
        visible: tip.completed && root.visible
        offset: root.centerArrowOnTarget && !!root.target
                ? -(tip.x + tip.width / 2 - root.target.width / 2)
                : 0

        // Overrides only where the owner asked for one, so that anything it
        // left alone keeps the value StatusToolTip and the style resolve.
        Binding on maxWidth { when: root.maxWidth >= 0; value: root.maxWidth }
        Binding on delay { when: root.delay >= 0; value: root.delay }
        Binding on y { when: root.y !== 0; value: root.y }
    }
}
