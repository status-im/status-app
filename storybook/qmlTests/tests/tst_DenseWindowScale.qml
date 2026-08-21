import QtQuick
import QtTest

import QtModelsToolkit
import SortFilterProxyModel 0.2

/*
 Scale check for the dense window (issue 0022): the dense model can be 100k
 rows, and the window is an SFPM IndexFilter over it whose invalidation is
 O(sourceCount) per window move. Measures what a slide, a teleport, a live
 insert and a hole fill cost at 1k / 10k / 100k source rows through the very
 chain ChatMessagesView uses (RolesRenamingModel -> SFPM + IndexFilter).

 Numbers only — nothing here asserts a budget except an upper sanity bound,
 so a slow machine reports rather than fails.
*/
Item {
    id: root

    width: 400
    height: 300

    // Stand-in for the dense model at scale: a fixed row count, a `loaded`
    // role, dummies for unfetched rows. Only the roles the window chain
    // actually touches, so 100k rows stay buildable in a test.
    ListModel { id: denseSource }

    component WindowChain: QtObject {
        id: chain

        property int windowStart: 0
        property int windowEnd: 29

        readonly property SortFilterProxyModel window: SortFilterProxyModel {
            sourceModel: RolesRenamingModel {
                sourceModel: denseSource

                mapping: [
                    RoleRename { from: "id"; to: "messageId" },
                    RoleRename { from: "timestamp"; to: "messageTimestamp" },
                    RoleRename { from: "contentType"; to: "messageContentType" }
                ]
            }

            filters: IndexFilter {
                minimumIndex: chain.windowStart
                maximumIndex: chain.windowEnd
            }
        }
    }

    TestCase {
        name: "DenseWindowScale"
        when: windowShown

        function fillSource(count) {
            denseSource.clear()
            for (let i = 0; i < count; ++i) {
                denseSource.append({
                    key: "msg-" + i,
                    id: "msg-" + i,
                    loaded: i < 200,
                    timestamp: 1700000000 + i,
                    contentType: 1
                })
            }
        }

        function measure(fn) {
            const t0 = Date.now()
            fn()
            return Date.now() - t0
        }

        function scaleRow(count) {
            const build = measure(() => fillSource(count))
            const chain = createTemporaryObject(chainComp, root)
            verify(!!chain)
            const attach = measure(() => {
                chain.windowStart = 0
                chain.windowEnd = 29
            })
            compare(chain.window.count, 30)

            // a slide: the window walks one 30-row chunk deeper into history
            const slide = measure(() => {
                for (let i = 0; i < 10; ++i) {
                    chain.windowStart += 30
                    chain.windowEnd += 30
                }
            }) / 10
            compare(chain.window.count, 30)

            // a teleport: the window jumps to the far end of the history.
            // Start first — moving the start deeper never admits rows, so the
            // span between the stale bounds and the target is never
            // transiently admitted.
            const teleport = measure(() => {
                chain.windowStart = count - 30
                chain.windowEnd = count - 1
            })
            compare(chain.window.count, 30)

            // the same jump with the bounds written in the wrong order: the
            // whole span between them is admitted for one invalidation
            chain.windowStart = 0
            chain.windowEnd = 29
            const teleportWrongOrder = measure(() => {
                chain.windowEnd = count - 1
                chain.windowStart = count - 30
            })
            compare(chain.window.count, 30)

            // a live message at the newest end, with the window mid-history
            chain.windowStart = Math.floor(count / 2)
            chain.windowEnd = chain.windowStart + 29
            const insert = measure(() => {
                denseSource.insert(0, {
                    key: "live", id: "live", loaded: true,
                    timestamp: 1800000000, contentType: 1
                })
            })

            // a hole fill inside the window: dataChanged only, no insert
            const fill = measure(() => {
                for (let i = 0; i < 30; ++i)
                    denseSource.set(chain.windowStart + i, { loaded: true })
            })

            console.info("[SCALE] rows=" + count
                         + " build=" + build + "ms"
                         + " attach=" + attach + "ms"
                         + " slide=" + slide.toFixed(1) + "ms"
                         + " teleport=" + teleport + "ms"
                         + " teleportWrongOrder=" + teleportWrongOrder + "ms"
                         + " insertNewest=" + insert + "ms"
                         + " fill30=" + fill + "ms")

            return { slide: slide, teleport: teleport, insert: insert,
                     fill: fill, teleportWrongOrder: teleportWrongOrder }
        }

        Component {
            id: chainComp
            WindowChain {}
        }

        function test_windowCostAcrossHistorySizes() {
            const small = scaleRow(1000)
            const medium = scaleRow(10000)
            const large = scaleRow(100000)

            // sanity only: a single window move must stay far below a frame
            // budget even at 100k, or the whole design is unworkable
            verify(large.slide < 100,
                   "a 100k-row window slide must stay usable, took "
                   + large.slide + "ms")
            verify(large.teleport < 200,
                   "a 100k-row teleport must stay usable, took "
                   + large.teleport + "ms")
            verify(large.insert < 200,
                   "a live insert at 100k rows must stay usable, took "
                   + large.insert + "ms")
        }
    }
}
