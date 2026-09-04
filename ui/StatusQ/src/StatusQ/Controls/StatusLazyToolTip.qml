import QtQuick

import StatusQ.Controls

/*!
   \qmltype StatusLazyToolTip
   \inherits Loader
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief A StatusToolTip that is not built until it is first hovered.

   Components created in bulk - every StatusBaseButton, StatusListItem or
   message row - would otherwise each build a Popup subtree for a hover that
   may never happen. Configure this like a StatusToolTip; it watches \c target
   for hover itself, and the popup is created the first time that hover
   happens and is kept alive from then on.

   \c enabled is the owner's say in whether a tooltip may appear at all. It
   gates the hover watch as well as the popup, so an owner that is itself
   disabled never builds one.

   \c visible reports that the tooltip is being shown; \c opened follows once
   the show delay has elapsed. Neither is something the owner sets.

   \qml
        StatusLazyToolTip {
            target: root
            text: qsTr("Copy")
        }
   \endqml

   Set \c textProvider instead of \c text when producing the text is itself
   expensive. It is pulled on every show, so neither the popup nor its text
   costs anything at creation.

   \qml
        StatusLazyToolTip {
            target: root
            enabled: !root.showFullTimestamp
            textProvider: () => LocaleUtils.formatDateTime(root.timestamp)
        }
   \endqml

   For a list of components available see StatusQ.
*/
Loader {
    id: root

    /*!
       Item watched for hover and positioned against. Defaults to the item this
       was declared in, which is what an inline StatusToolTip would have used.
    */
    property Item target: root.parent

    property string text

    /*!
       Pulled on every show to produce \c text. Assigns \c text when set, so
       the two are alternatives rather than a pair.
    */
    property var textProvider: null

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

    // A StatusToolTip is a Popup, so this never draws anything and stays empty.
    // A Row or Column skips a zero-sized child, but a Layout still gives it a
    // spacing slot - declare one directly in a Layout only if that is wanted.
    width: 0
    height: 0

    visible: hoverHandler.hovered

    active: false

    // Nothing is built for a tooltip with nothing to say - most controls carry
    // one without ever being given text.
    onVisibleChanged: {
        if (!visible)
            return
        if (!!textProvider)
            text = textProvider()
        if (!!text)
            active = true
    }

    onTextChanged: if (root.visible && !!root.text) root.active = true

    // A tooltip is a pointer affordance, so a touch never raises one.
    HoverHandler {
        id: hoverHandler

        parent: root.target
        enabled: root.enabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
    }

    sourceComponent: StatusToolTip {
        id: tip

        // The popup is born at the instant it is asked to show. QQuickToolTip
        // only applies its show delay to an already completed popup, so the
        // show request is withheld until then.
        property bool completed: false
        Component.onCompleted: tip.completed = true

        objectName: root.tooltipObjectName
        parent: root.target
        text: root.text
        orientation: root.orientation
        visible: tip.completed && root.visible && !!tip.text
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
