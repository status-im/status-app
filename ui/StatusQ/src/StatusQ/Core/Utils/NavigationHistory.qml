import QtQml

/*!
   \qmltype NavigationHistory
   \inqmlmodule StatusQ.Core.Utils

   A generic, opaque bounded stack of navigation tokens. Pure data structure —
   no backend, no model access, no UI. Designed to be instantiated wherever
   ordered back-navigation history is needed (e.g. section-scope inside
   AppMain, or subsection-scope inside a section).

   Consecutive duplicates (record(t) when t === top) are silently dropped.
   Empty / null / undefined tokens are ignored. Stack length is bounded by
   maxDepth; the oldest entry is evicted on overflow.
*/
QtObject {
    id: root

    /*! Maximum stack depth. Oldest entry is evicted on overflow. */
    property int maxDepth: 16

    // canGoBack depends on d.depth — a scalar mirror of d.stack.length —
    // because QML does not notify on Array.push/pop mutations of a var array.
    /*! True when there is at least one token to pop. */
    readonly property bool canGoBack: d.depth > 0

    onMaxDepthChanged: {
        d.trim()
    }

    /*!
       Push a token. No-op if equal to the current top (consecutive de-dup),
       or if the token is empty / null / undefined. Caps the stack to maxDepth.
    */
    function record(token) {
        if (token === undefined || token === null || token === "")
            return
        if (d.stack.length > 0 && d.stack[d.stack.length - 1] === token)
            return
        d.stack.push(token)
        d.trim()
    }

    /*!
       Pops and returns the top token. The recorder pushes the *previous*
       section id whenever the active section changes, so the popped value
       IS the next navigation destination — callers should navigate directly
       to the returned token. Returns "" when the stack is empty.
    */
    function back() {
        if (d.stack.length === 0)
            return ""
        const token = d.stack.pop()
        d.depth = d.stack.length
        return token
    }

    /*! Empty the stack. */
    function clear() {
        if (d.stack.length === 0)
            return
        d.stack = []
        d.depth = 0
    }

    readonly property QtObject _d: QtObject {
        id: d
        // depth mirrors d.stack.length; updated by every mutator so canGoBack stays reactive
        property var stack: []
        property int depth: 0

        function trim() {
            while (d.stack.length > Math.max(0, root.maxDepth))
                d.stack.shift()
            d.depth = d.stack.length
        }
    }
}
