import QtQuick
import QtQuick.Window

/*!
    \qmltype SectionPanelSlot
    \inqmlmodule StatusQ.Layout
    \internal
    \brief Holds one of a section's panels and gives it the slot's box.

    A drop-in replacement for \c LayoutItemProxy in the places where
    \l StatusSectionLayout hands a panel to its portrait or landscape
    sub-layout. It differs in two ways, both of which exist to stop a burst of
    host sizes turning into a burst of relayouts of a populated panel:

    \list
    \li it never writes a degenerate box — while the slot is collapsed or
        detached the panel keeps its last good geometry instead of being
        squashed to 0 and restored a few frames later;
    \li while \l frozen it stops tracking the slot altogether, so a run of
        intermediate sizes (a device rotation walks the window through nine of
        them) costs one relayout instead of nine. Outside the bracket it is a
        live pass-through, so a desktop window drag still tracks.
    \endlist

    \section2 Arbitration

    The same panel is bound into both sub-layouts at once, so two slots target
    it and exactly one may own it. The rule is claim-on-live, never release: a
    slot takes the panel when it becomes \l live and does nothing when it stops
    being live. \l live requires the slot to be effectively visible \e and in a
    scene, which is what separates the two sub-layouts (\c LayoutChooser makes
    the chosen one visible and the other not) and also excludes a slot sitting
    in a \c SwipeView page that has been taken out of the view — such a page has
    no parent, and a parentless item reports \c visible \c true.
*/
Item {
    id: root

    /*!
        The panel this slot owns. Changing it releases the previous one.
    */
    property Item target: null

    /*!
        While true the slot stops writing geometry to \l target: the panel keeps
        the last box it was given until the bracket is lifted. Reparenting still
        happens, so the panel is never left out of the scene.
    */
    property bool frozen: false

    /*!
        True when this slot is the one that should own \l target and can
        describe a real box for it.
    */
    readonly property bool live: root.visible && root.Window.window !== null
                                 && root.width > 0 && root.height > 0

    // A held panel can be larger than the slot for the length of a transition.
    clip: root.frozen

    onLiveChanged: root.apply()
    onWidthChanged: root.apply()
    onHeightChanged: root.apply()
    onFrozenChanged: root.apply()

    onTargetChanged: {
        if (d.owned && d.owned !== root.target && d.owned.parent === root)
            d.owned.parent = null
        d.owned = null
        root.apply()
    }

    QtObject {
        id: d
        property Item owned: null
    }

    function apply() {
        const t = root.target
        if (!t || !root.live)
            return
        const adopting = t.parent !== root
        if (adopting) {
            t.parent = root
            t.x = 0
            t.y = 0
        }
        d.owned = t
        // Hold the last good box - but only if there is one. A panel that has
        // never been sized has nothing to hold, so a bracket in flight when it
        // arrives must not park it at 0x0 for the length of the transition.
        if (root.frozen && t.width > 0 && t.height > 0)
            return
        // On adoption, write unconditionally even when the value is unchanged.
        // A section that pre-sized its panel from the published slot geometry
        // arrives already the right size, and leaving that binding in place
        // would let the panel track the slot behind the slot's back - defeating
        // the bracket. An assignment of an equal value breaks the binding
        // without emitting a change.
        if (adopting || t.width !== root.width)
            t.width = root.width
        if (adopting || t.height !== root.height)
            t.height = root.height
    }

    Component.onCompleted: root.apply()
}
