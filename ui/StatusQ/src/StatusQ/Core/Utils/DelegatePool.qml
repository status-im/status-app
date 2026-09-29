pragma ComponentBehavior: Bound

import QtQuick

/*
  A reservoir of pre-built delegate items. Storage and construction only: it
  knows nothing about model roles, and binding an item to a row is the
  caller's job.

  `acquire` answers through a callback rather than a return value, which is what
  lets it answer *late* - after a simulated dress delay, or after an
  asynchronous incubation when the pool is dry. Callers must therefore tolerate
  both a synchronous and a deferred answer.

  Parked items are children of this item, which is itself invisible, so nothing
  parked is drawn and nothing parked sits inside a row that might be destroyed.
*/
Item {
    id: root

    // What to build.
    property Component delegate: null

    // How many items to keep pre-built. Filled one per event-loop turn rather
    // than in one burst, so a large target is not a startup stall.
    property int target: 0

    // Incubate rather than construct when the pool has to grow.
    property bool asynchronous: true

    // Artificial delay before an acquire is answered, drawn per acquire. Not
    // a cost the pool has: it exists so a harness can stand in for a slow
    // delegate, and so callers are exercised against a late answer. Requests wait
    // concurrently - each has its own due time - so a window's worth of rows
    // takes about maxDelay in total rather than maxDelay each. Zero means
    // answer synchronously, which is the case worth testing: it makes the
    // callback fire inside the caller's own handler.
    property int minDelay: 0
    property int maxDelay: 0

    readonly property int builtCount: d.builtCount
    readonly property int availableCount: d.parkedCount
    readonly property int acquiredCount: d.acquiredCount

    visible: false
    width: 0
    height: 0

    // `immediate` skips the simulated delay for this one acquire.
    function acquire(parent, callback, immediate) {
        if (!root.delegate) {
            console.warn("DelegatePool: no delegate set; cannot acquire")
            return
        }

        const delay = (immediate === true || root.maxDelay <= 0) ? 0
                    : root.minDelay
                      + Math.round(Math.random()
                                   * Math.max(0, root.maxDelay - root.minDelay))

        if (delay <= 0) {
            d.serve(parent, callback)
            return
        }

        d.queue.push({ parent, callback, dueAt: Date.now() + delay })
        deliveryTimer.running = true
    }

    function release(obj) {
        if (!obj)
            return

        if (d.parked.indexOf(obj) !== -1)
            return      // double release

        if (!d.owned(obj)) {
            console.warn("DelegatePool: released an item this pool did not build")
            return
        }

        d.park(obj)
        d.acquiredCount--
        d.republish()
    }

    QtObject {
        id: d

        property var parked: []
        property var queue: []
        property var built: []

        property int builtCount: 0
        property int acquiredCount: 0

        // `parked` is a plain array and mutating it notifies nothing, so the
        // count lives in its own property and is republished by hand.
        property int parkedCount: 0

        function republish() {
            d.parkedCount = d.parked.length
        }

        function owned(obj) {
            return d.built.indexOf(obj) !== -1
        }

        function park(obj) {
            obj.parent = root
            obj.visible = false
            obj.enabled = false
            d.parked.push(obj)
        }

        function dress(obj, parent) {
            obj.parent = parent
            obj.visible = true
            obj.enabled = true
            d.acquiredCount++
            d.republish()
        }

        // Takes a parked item, or builds one if there is none.
        function serve(parent, callback) {
            // The row that asked may be gone by the time a deferred delivery
            // arrives - a destroyed QObject reads as null from JS.
            if (!parent)
                return

            if (d.parked.length > 0) {
                const obj = d.parked.pop()

                d.dress(obj, parent)
                callback(obj)
                return
            }

            d.build((obj) => {
                if (!parent) {      // gone while we were building
                    d.park(obj)
                    d.republish()
                    return
                }

                d.dress(obj, parent)
                callback(obj)
            })
        }

        // Builds one item, parked and ready, and hands it to `callback`.
        function build(callback) {
            if (!root.asynchronous) {
                const obj = root.delegate.createObject(root)

                if (!obj) {
                    console.warn("DelegatePool: building the delegate failed")
                    return
                }

                obj.visible = false
                obj.enabled = false
                d.built.push(obj)
                d.builtCount++
                callback(obj)
                return
            }

            const incubator = root.delegate.incubateObject(root, {}, Qt.Asynchronous)

            function settle(status) {
                if (status === Component.Error) {
                    console.warn("DelegatePool: incubating the delegate failed:",
                                 incubator.errorString())
                    return
                }

                if (status !== Component.Ready)
                    return

                const obj = incubator.object

                obj.visible = false
                obj.enabled = false
                d.built.push(obj)
                d.builtCount++
                callback(obj)
            }

            // An incubation can already be finished here, in which case
            // onStatusChanged never fires.
            if (incubator.status === Component.Loading)
                incubator.onStatusChanged = settle
            else
                settle(incubator.status)
        }

        // One timer for all pending requests: each is delivered once its own
        // due time has passed, so they wait in parallel.
        function deliverDue() {
            const now = Date.now()
            const waiting = []

            for (let i = 0; i < d.queue.length; ++i) {
                const request = d.queue[i]

                if (request.dueAt > now)
                    waiting.push(request)
                else
                    d.serve(request.parent, request.callback)
            }

            d.queue = waiting

            if (d.queue.length === 0)
                deliveryTimer.running = false
        }

        // One per turn, so filling a large target does not block.
        function fillOne() {
            if (d.builtCount >= root.target)
                return

            d.build((obj) => {
                d.parked.push(obj)
                d.republish()
                fillTimer.restart()
            })
        }
    }

    Timer {
        id: deliveryTimer

        interval: 16
        repeat: true

        onTriggered: d.deliverDue()
    }

    Timer {
        id: fillTimer

        interval: 0

        onTriggered: d.fillOne()
    }

    onTargetChanged: fillTimer.restart()

    Component.onCompleted: fillTimer.restart()
}
