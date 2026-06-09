import QtQml

import StatusQ.Core.Utils as SQUtils

/*!
   \qmltype SubsectionNavigationHistory
   \inqmlmodule StatusQ.Core.Utils

   Subsection-scope back history for a single app section. Records the previous
   \c currentKey whenever it changes; \c tryGoBack() pops the newest still-valid
   key and emits \c navigateRequested for the owner to navigate to it.

   The recording is async-safe: it ignores the \c currentKey change caused by our
   own back-navigation (matched by token), so it stays correct even when the
   section's setter applies asynchronously (e.g. chat's \c setActiveItem).
*/
QtObject {
    id: root

    /*! Bound by the owner to the active-subsection identity (string or int). */
    property var currentKey

    /*!
       Optional \c {function(token) -> bool}; tokens it rejects (subsections that
       no longer exist) are skipped on pop. The token is always a string, so
       coerce as needed, e.g.
       \c {validateFn: key => ModelUtils.indexOf(model, role, parseInt(key)) >= 0}.
    */
    property var validateFn: null

    /*! Emitted when the owner should navigate to \c key (wire to its setter). */
    signal navigateRequested(var key)

    /*! True when there is at least one key to pop. */
    readonly property bool canGoBack: d.history.canGoBack

    /*! Pop the newest still-valid key and request navigation to it. */
    function tryGoBack() {
        while (d.history.canGoBack) {
            const token = d.history.back()
            if (token === "")
                continue
            if (root.validateFn && !root.validateFn(token))
                continue // subsection gone; pop next
            d.pendingBackTarget = token
            root.navigateRequested(token)
            return true
        }
        return false
    }

    /*!
       Dismiss the active subsection: it won't be recorded when the user next
       navigates away. Call when Back returns to the section's list/root view —
       an explicit dismissal must not be retraced later.
    */
    function dropLeaf() {
        d.lastKey = ""
    }

    /*! Empty the history and clear any in-flight back guard. */
    function clear() {
        d.history.clear()
        d.pendingBackTarget = undefined
    }

    onCurrentKeyChanged: {
        const cur = d.norm(root.currentKey)
        const prev = d.norm(d.lastKey)
        d.lastKey = root.currentKey

        // Our own back-navigation settling: consume the guard, don't record.
        if (d.pendingBackTarget !== undefined && cur === d.norm(d.pendingBackTarget)) {
            d.pendingBackTarget = undefined
            return
        }
        // Any other change while a back is in flight cancels the guard.
        d.pendingBackTarget = undefined

        if (prev !== "")
            d.history.record(prev)
    }

    Component.onCompleted: d.lastKey = root.currentKey

    readonly property QtObject _d: QtObject {
        id: d

        // Token currentKey is expected to settle to from our own tryGoBack();
        // while set, the matching currentKey change is not recorded.
        property var pendingBackTarget: undefined
        property var lastKey: undefined

        readonly property NavigationHistory history: SQUtils.NavigationHistory {}

        // Normalize to a string token (ints and strings share one path).
        function norm(k) {
            if (k === undefined || k === null)
                return ""
            return "" + k
        }
    }
}
