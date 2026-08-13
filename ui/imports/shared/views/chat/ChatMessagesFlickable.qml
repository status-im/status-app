import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
   \qmltype ChatMessagesFlickable
   \brief Bottom-anchored message view driven purely by model operations
   (productized from PoC #17999).

   Renders exactly the rows its \c model holds, row 0 (newest) at the bottom.
   Paging: when the placeholder standing in for out-of-window messages scrolls
   into the viewport, \c moreUpRequested / \c moreDownRequested ask the owner
   to slide its window. Across model changes the view holds position by
   anchoring to the viewport-edge item, and follows the newest message when it
   was already showing it.
*/
Flickable {
    id: root

    /*!
       Window model. Row 0 is the newest message and is rendered last.
    */
    property alias model: repeater.model

    /*!
       Instantiated once per model row, roles and \c index available as in a
       ListView delegate. The delegate must reverse the order itself with
       \c {Layout.row: view.rowCount - index} so row 0 lands at the bottom.
    */
    property Component delegate

    /*!
       Stands in for the messages that exist outside the window. Scrolling it
       into the viewport is what asks the owner for more rows.
    */
    property Component placeholder

    /*!
       Height given to the placeholder. It doubles as the depth of the region
       in which scrolling asks for more rows, so it must stay well above zero.
    */
    property real placeholderHeight: root.height

    /*!
       Content pinned below the newest message (\c ListView.header equivalent
       for a bottom-to-top list).
    */
    property Component bottomContent

    /*!
       Blank space kept below the bottom-most content.
    */
    property real contentBottomPadding: 0

    property bool moreUpAvailable: false
    property bool moreDownAvailable: false

    readonly property alias count: repeater.count

    /*!
       Number of laid-out rows; the delegate needs it to reverse its layout row.
    */
    readonly property alias rowCount: repeater.count

    /*!
       The newest message of the whole history is in the viewport.
    */
    readonly property bool atNewest: !root.moreDownAvailable && d.atContentBottom

    /*!
       The view is showing (and following) the newest message.
    */
    readonly property alias stickingToNewest: d.stickToBottom

    signal moreUpRequested()
    signal moreDownRequested()

    /*!
       Emitted once the row requested through \c positionAtRow is actually laid
       out and in the viewport.
    */
    signal rowPositioned(int row)

    clip: true
    contentWidth: root.width
    boundsMovement: Flickable.StopAtBounds

    // contentHeight is assigned inside the apply() guard (not bound): setting
    // it makes the Flickable clamp contentY immediately, and that clamp must
    // never read as a user move.
    Component.onCompleted: d.applyContentHeight()

    /*!
       Jump to the newest message and follow it from there on.
    */
    function positionAtNewest() {
        d.releaseAnchor()
        d.pendingRow = -1
        d.seekingNewest = false
        d.stickToBottom = true
        d.goToBottom()
    }

    /*!
       Center the viewport on a window row and keep it there until the user
       scrolls away — the row may still be laid out, in which case it is
       positioned as soon as it is.
    */
    function positionAtRow(row) {
        d.releaseAnchor()
        d.seekingNewest = false
        d.stickToBottom = false
        d.pendingRow = row
        d.restorePosition()
    }

    /*!
       The delegate instance built for a window row, or null when the row is
       outside the window.
    */
    function itemAtRow(row) {
        return repeater.itemAt(row)
    }

    QtObject {
        id: d

        // Derived from the content directly rather than from contentHeight, so
        // it is already correct while reacting to a content height change.
        readonly property real bottomContentY: Math.max(0, content.height - root.height)
        readonly property bool atContentBottom: root.contentY >= d.bottomContentY - 1

        // Whether the viewport was showing the bottom of the content before
        // the last content change, i.e. whether it should follow it.
        property bool stickToBottom: true

        // The user scrolled onto the bottom of a window that still has newer
        // messages behind it — they are heading for the newest, the window
        // just has not caught up. Chase the content bottom until it does,
        // then latch onto the newest for real.
        property bool seekingNewest: false

        // Item the viewport position is measured against while the window is
        // being slid, so rows entering above the viewport do not move it.
        property Item anchorItem: null
        property real anchorOffset: 0

        // Row positionAtRow() was asked to show, kept until the user scrolls.
        property int pendingRow: -1

        readonly property bool placeholderUpVisible:
            topPlaceholder.active && content.y + topPlaceholder.y + topPlaceholder.height > root.contentY
        readonly property bool placeholderDownVisible:
            bottomPlaceholder.active && content.y + bottomPlaceholder.y < root.contentY + root.height

        // From live values, not the bottomContentY binding: inside an
        // onHeightChanged handler the binding still holds the pre-change value.
        function freshBottomY() {
            return Math.max(0, content.height - root.height)
        }

        function clampContentY(y) {
            return Math.max(0, Math.min(d.freshBottomY(), y))
        }

        // All internal writes go through apply()/applyContentHeight() so
        // onContentYChanged can tell them apart from user moves (wheel,
        // touch, scrollbar drags — the scrollbar writes contentY without any
        // movement signals). Save/restore keeps nested calls guarded.
        property bool applyingPosition: false

        function apply(y) {
            const was = applyingPosition
            applyingPosition = true
            root.contentY = y
            applyingPosition = was
        }

        function applyContentHeight() {
            const was = applyingPosition
            applyingPosition = true
            root.contentHeight = Math.max(root.height, content.height)
            applyingPosition = was
        }

        function goToBottom() {
            d.apply(d.freshBottomY())
        }

        function releaseAnchor() {
            anchorItem = null
        }

        // Which viewport edge the anchor was taken at, so an eviction re-arm
        // stays on the same side.
        property bool anchorAtTop: true

        // Anchors on the built row closest to the given viewport edge, so that
        // row keeps its place on screen while the window slides. \a excluded
        // is a row on its way out, which must not be anchored on again.
        function anchorAtViewportEdge(top, excluded) {
            anchorAtTop = top
            const edge = top ? root.contentY : root.contentY + root.height
            let best = null
            let bestDistance = Number.MAX_VALUE
            let fallback = null
            for (let i = 0; i < repeater.count; ++i) {
                const item = repeater.itemAt(i)
                if (!item || item === excluded)
                    continue
                // an unpolished row still sits at y 0 — a position no laid-out
                // delegate can hold while the top placeholder occupies it —
                // so its geometry cannot be measured yet
                if (item.y === 0 && topPlaceholder.active) {
                    fallback = item
                    continue
                }
                const distance = Math.abs(content.y + item.y - edge)
                if (distance < bestDistance) {
                    bestDistance = distance
                    best = item
                }
            }
            if (!best) {
                // never trade a working anchor for an unmeasurable one
                if (anchorItem && anchorItem !== excluded)
                    return
                if (fallback && excluded) {
                    // survivors are not re-laid yet; the evicted row's
                    // position is the only trustworthy coordinate — hand its
                    // offset over and let the next polish walk it into place
                    anchorItem = fallback
                    anchorOffset = content.y + excluded.y - root.contentY
                } else {
                    anchorItem = null
                    anchorOffset = 0
                }
                return
            }
            anchorItem = best
            anchorOffset = content.y + best.y - root.contentY
        }

        function restorePosition() {
            if (d.seekingNewest) {
                // keep chasing the content bottom while the window catches
                // up with the newest; latch on once it has
                d.goToBottom()
                if (!root.moreDownAvailable) {
                    d.seekingNewest = false
                    d.stickToBottom = true
                    d.releaseAnchor()
                }
                return
            }
            if (d.pendingRow >= 0) {
                const target = repeater.itemAt(d.pendingRow)
                // height > 0 keeps a pre-polish item from being positioned on
                // stale geometry
                if (target && target.height > 0) {
                    d.apply(d.clampContentY(
                                content.y + target.y + target.height / 2 - root.height / 2))
                    // hand over to the anchor: later content changes hold this
                    // row in place without re-firing the request — the window
                    // may slide meanwhile, making the row a different message
                    const row = d.pendingRow
                    d.anchorItem = target
                    d.anchorOffset = content.y + target.y - root.contentY
                    d.pendingRow = -1
                    root.rowPositioned(row)
                    return
                }
            }
            if (d.stickToBottom) {
                d.goToBottom()
                return
            }
            if (d.anchorItem)
                d.apply(d.clampContentY(content.y + d.anchorItem.y - d.anchorOffset))
        }
    }

    onHeightChanged: {
        d.applyContentHeight()
        d.restorePosition()
    }

    // A slide replaces rows on one side of the window with rows on the other,
    // which moves the surviving rows without changing the content height.
    Connections {
        target: d.anchorItem

        function onYChanged() {
            d.restorePosition()
        }
    }

    // Sticking is derived from position: any contentY write outside the
    // apply() guard is a user move — wheel, touch, and scrollbar drags,
    // which emit no movement signals at all. Landing on the newest message
    // re-sticks, leaving it unsticks; anything in between keeps the view
    // anchored where the user put it, so content changes above or below it
    // hold it in place. "Newest" is the atNewest semantic, not the content
    // bottom: the bottom of a window slid into history has newer messages
    // behind it and must not stick.
    onContentYChanged: {
        if (d.applyingPosition)
            return
        d.pendingRow = -1
        const atBottom = root.contentY >= d.freshBottomY() - 1
        d.stickToBottom = atBottom && !root.moreDownAvailable
        d.seekingNewest = atBottom && root.moreDownAvailable
        if (d.stickToBottom)
            d.releaseAnchor()
        else
            d.anchorAtViewportEdge(true)
    }

    // Level-triggered while a placeholder is in the viewport: one request per
    // tick until the window covers it or the owner reports nothing more to
    // show. The owner is expected to guard backend fetches.
    Timer {
        interval: 150
        repeat: true
        running: (root.moreUpAvailable && d.placeholderUpVisible)
                 || (root.moreDownAvailable && d.placeholderDownVisible)
        triggeredOnStart: true

        onTriggered: {
            // an empty view has nothing to anchor on, and unsticking it would
            // leave it parked at the top once rows arrive
            if (repeater.count === 0)
                return
            if (root.moreUpAvailable && d.placeholderUpVisible) {
                // keep an already-armed anchor: re-picking mid-churn can land
                // on a freshly inserted row whose geometry has not been
                // polished yet, pinning the view to a stale position
                if (!d.anchorItem)
                    d.anchorAtViewportEdge(true)
                // only a view that left the content bottom stops following it:
                // with short content the placeholder is visible at the bottom
                // too, and rows still to come must keep landing there
                if (!d.atContentBottom)
                    d.stickToBottom = false
                root.moreUpRequested()
            } else if (root.moreDownAvailable && d.placeholderDownVisible) {
                if (!d.anchorItem)
                    d.anchorAtViewportEdge(false)
                root.moreDownRequested()
            }
        }
    }

    // Rows are laid out oldest first so the newest message ends up at the
    // bottom; the explicit row assignment reverses the model order without a
    // proxy, keeping the model's index semantics intact.
    GridLayout {
        id: content

        property real previousHeight: 0

        columns: 1
        columnSpacing: 0
        rowSpacing: 0

        width: root.width
        height: implicitHeight
        y: Math.max(0, root.height - height)

        onHeightChanged: {
            if (height === previousHeight)
                return
            previousHeight = height
            d.applyContentHeight()
            d.restorePosition()
        }

        Loader {
            id: topPlaceholder

            Layout.row: 0
            Layout.column: 0
            Layout.fillWidth: true
            Layout.preferredHeight: active ? root.placeholderHeight : 0

            active: root.moreUpAvailable
            visible: active
            sourceComponent: root.placeholder
        }

        // The delegate is instantiated directly by the repeater: routing it
        // through a wrapping Loader would create it in the component's own
        // creation context and hide the model roles.
        Repeater {
            id: repeater

            delegate: root.delegate

            // The row leaving the window may be the one the viewport is
            // measured against. The survivors still hold their pre-relayout
            // positions here, so the offset taken now is the one to keep.
            onItemRemoved: (index, item) => {
                if (item === d.anchorItem)
                    d.anchorAtViewportEdge(d.anchorAtTop, item)
            }
        }

        Loader {
            id: bottomPlaceholder

            Layout.row: repeater.count + 1
            Layout.column: 0
            Layout.fillWidth: true
            Layout.preferredHeight: active ? root.placeholderHeight : 0

            active: root.moreDownAvailable
            visible: active
            sourceComponent: root.placeholder
        }

        Loader {
            Layout.row: repeater.count + 2
            Layout.column: 0
            Layout.fillWidth: true

            active: !!root.bottomContent
            visible: active
            sourceComponent: root.bottomContent
        }

        Item {
            Layout.row: repeater.count + 3
            Layout.column: 0
            Layout.fillWidth: true
            Layout.preferredHeight: root.contentBottomPadding
        }
    }
}
