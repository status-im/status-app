import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core

/*
 Configuration analysis for StatusTimeStampLabel
 ===============================================
 Configurations:
 - relative mode (default): today / yesterday / this-week / this-year /
   previous-year buckets                    → test_relativeBuckets
 - full mode (showFullTimestamp)            → test_fullTimestampMode
 - hover → tooltip with the full date-time  → test_hoverTooltip
 - relative label vs the shared clock tick  → test_relativeLabelIgnoresSecondsTicks
*/
Item {
    id: root

    width: 400
    height: 200

    Component {
        id: labelComp
        StatusTimeStampLabel {}
    }

    Component {
        id: spyComp
        SignalSpy {}
    }

    TestCase {
        name: "StatusTimeStampLabel"
        when: windowShown

        readonly property int dayMs: 24 * 60 * 60 * 1000

        // INTENT (perf): the hover tooltip is a pure desktop nicety; it must
        // not be instantiated with the label (dozens per chat switch, never
        // shown on touch devices)
        function test_tooltipNotInstantiatedBeforeHover() {
            const label = createTemporaryObject(labelComp, root,
                                                {timestamp: Date.now()})
            verify(!!label)
            waitForRendering(label)

            compare(findChild(label, "timestampTooltip"), null,
                    "tooltip must not exist before the first hover")
        }

        function test_relativeBuckets() {
            const now = Date.now()
            const stamps = [
                now - 60 * 1000,          // today
                now - dayMs,              // yesterday
                now - 3 * dayMs,          // weekday bucket
                now - 40 * dayMs,         // this year (usually)
                now - 400 * dayMs         // previous year
            ]
            for (let i = 0; i < stamps.length; ++i) {
                const label = createTemporaryObject(labelComp, root, { timestamp: stamps[i] })
                verify(!!label)
                compare(label.text, LocaleUtils.formatRelativeTimestamp(stamps[i]),
                        "bucket " + i)
            }
        }

        function test_fullTimestampMode() {
            const ts = Date.now() - 3 * dayMs
            const label = createTemporaryObject(labelComp, root, {
                timestamp: ts,
                showFullTimestamp: true
            })
            compare(label.text, LocaleUtils.formatDateTime(ts))
        }

        // INTENT (perf): formatRelativeTimestamp is day-granular ("Today 14:23"),
        // so the label must follow the shared timer's DAY counter, not its
        // per-second one. Bound to seconds it re-formats every visible row once
        // a second forever — pure GUI-thread churn for a value that cannot move.
        // The timer does not run offscreen, so the ticks are driven directly
        // through the singleton's own timer object instead of waiting on wall time.
        function test_relativeLabelIgnoresSecondsTicks() {
            const label = createTemporaryObject(labelComp, root,
                                                { timestamp: Date.now() - 60 * 1000 })
            verify(!!label)
            waitForRendering(label)

            const initialText = label.text
            const initialDays = StatusSharedUpdateTimer.daysActive
            const initialSeconds = StatusSharedUpdateTimer.secondsActive
            const textSpy = createTemporaryObject(spyComp, root, {
                target: label, signalName: "textChanged" })

            for (let i = 0; i < 5; ++i)
                StatusSharedUpdateTimer.d.tick()

            compare(StatusSharedUpdateTimer.secondsActive, initialSeconds + 5,
                    "the ticks must have actually advanced the per-second counter")
            compare(StatusSharedUpdateTimer.daysActive, initialDays,
                    "seconds ticks within the same day must not advance the day counter")
            compare(label.clockTick, initialDays,
                    "the label's clock dependency must not move on seconds ticks")
            compare(textSpy.count, 0,
                    "the relative label must not re-format on seconds ticks")
            compare(label.text, initialText)
        }

        // The day counter is what the label DOES depend on: crossing local
        // midnight has to advance it, or "Today 23:59" would never become
        // "Yesterday 23:59" for a chat left open overnight.
        function test_dayBoundaryAdvancesTheDayCounter() {
            const timer = StatusSharedUpdateTimer.d
            const before = StatusSharedUpdateTimer.daysActive

            // pretend the last tick landed on yesterday's midnight
            timer.dayStart = timer.dayStart - dayMs
            timer.tick()

            compare(StatusSharedUpdateTimer.daysActive, before + 1,
                    "crossing a day boundary must advance the day counter")
            const label = createTemporaryObject(labelComp, root,
                                                { timestamp: Date.now() - dayMs })
            verify(!!label)
            compare(label.clockTick, StatusSharedUpdateTimer.daysActive,
                    "the label must follow the day counter")
            // and it settles back onto the real day, so one boundary counts once
            timer.tick()
            compare(StatusSharedUpdateTimer.daysActive, before + 1,
                    "a further tick on the same day must not advance it again")
        }

        function test_hoverTooltip() {
            // The full-date tooltip is driven by a HoverHandler, which does
            // not react reliably to QtTest's synthetic mouseMove in this
            // harness; StatusLazyToolTip covers the hover path itself.
            skip("HoverHandler does not react to synthetic hover here")
        }
    }
}
