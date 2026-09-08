import QtQml
import QtQuick

/*!
  Dev-only, zero-input repro driver. Enabled by the `autoReproScenario` root
  context property (STATUS_AUTO_REPRO env var on desktop,
  -d:AUTO_REPRO_SCENARIO=... for mobile builds). Empty scenario = inert.

  Scenario "wallet-switch": activate the wallet section, then jump to another
  section (`target`) while it is still coming up. "wallet-settings" is an
  alias for target=settings. Repeats with a growing delay so the
  switch lands at every phase of the wallet incubation. A 1s heartbeat line
  keeps logging while the GUI thread is alive, so a freeze shows up as the
  heartbeat stopping and a crash as the process going away.

    STATUS_AUTO_REPRO="wallet-switch:target=chat,at=immediate,loops=30"

  target  settings | chat | home | communities                 (default settings)
  at      immediate | activate | loading | loaded              (default immediate)
          immediate = switch to settings in the same call stack that activated
          the wallet (no event processing in between); the others arm `delay`
          from that loader phase
  delay   ms from that point to the settings switch          (default 0)
  step    delay increment per loop                            (default 40)
  loops   iterations                                          (default 30)
  settle  ms to rest in settings before the next loop         (default 2000)
  park    wallet | none: section to leave active when done, so the next app
          start opens on it (default wallet; use with a restart-per-loop runner)
*/
QtObject {
    id: root

    required property string scenario
    required property bool ready
    required property Loader walletLoader

    signal walletRequested()
    signal sectionRequested(string target)

    readonly property bool enabled: d.name === "wallet-switch" || d.name === "wallet-settings"
    readonly property string phase: d.phase

    function parse(scenario) {
        const sep = scenario.indexOf(":")
        const name = sep < 0 ? scenario : scenario.substring(0, sep)
        const result = { name: name.trim() }
        if (sep < 0)
            return result
        for (const pair of scenario.substring(sep + 1).split(",")) {
            const eq = pair.indexOf("=")
            if (eq < 0)
                continue
            const key = pair.substring(0, eq).trim()
            const value = pair.substring(eq + 1).trim()
            result[key] = isNaN(Number(value)) ? value : Number(value)
        }
        return result
    }

    readonly property QtObject priv: QtObject {
        id: d

        readonly property var parsed: root.parse(root.scenario)
        readonly property string name: parsed.name ?? ""
        readonly property string target: parsed.target ?? "settings"
        readonly property string at: parsed.at ?? "immediate"
        readonly property int step: parsed.step ?? 40
        readonly property int loops: parsed.loops ?? 30
        readonly property int settle: parsed.settle ?? 2000
        readonly property string park: parsed.park ?? "wallet"

        property int delay: parsed.delay ?? 0
        property int loop: 0
        // idle | waiting | armed | settling | done
        property string phase: "idle"

        function log(msg) {
            console.info("[autoRepro] loop=%1 delay=%2 phase=%3 walletLoader.status=%4 :: %5"
                         .arg(loop).arg(delay).arg(phase).arg(root.walletLoader.status).arg(msg))
        }

        function start() {
            if (phase !== "idle")
                return
            log("start scenario=%1 target=%2 at=%3 step=%4 loops=%5 settle=%6"
                .arg(name).arg(target).arg(at).arg(step).arg(loops).arg(settle))
            heartbeat.start()
            nextLoop()
        }

        function nextLoop() {
            if (loop >= loops) {
                if (park === "wallet")
                    root.walletRequested()
                phase = "done"
                heartbeat.stop()
                log("done, no crash/freeze reproduced (parked on %1)".arg(park))
                return
            }
            phase = "waiting"
            if (root.walletLoader.active) {
                log("wallet already active (saved section) - checking phase")
                if (at === "immediate") { phase = "armed"; doSwitch(); return }
                maybeArm()
            } else {
                log("activating wallet")
                root.walletRequested()
                if (at === "immediate") { phase = "armed"; doSwitch(); return }
            }
        }

        // Called on every wallet loader state change while waiting
        function maybeArm() {
            if (phase !== "waiting" || !root.walletLoader.active)
                return
            const status = root.walletLoader.status
            const hit = at === "activate"
                      || (at === "loading" && status === Loader.Loading)
                      || (at === "loaded" && status === Loader.Ready)
            if (!hit)
                return
            phase = "armed"
            log("armed, switching to %1 in %2ms".arg(target).arg(delay))
            switchTimer.interval = delay
            switchTimer.start()
        }

        function doSwitch() {
            log("switching to %1 NOW".arg(target))
            root.sectionRequested(target)
            phase = "settling"
            log("switched, settling %1ms".arg(settle))
            settleTimer.interval = settle
            settleTimer.start()
        }

        function finishLoop() {
            loop += 1
            delay += step
            nextLoop()
        }
    }

    readonly property Timer switchTimer: Timer {
        id: switchTimer
        repeat: false
        onTriggered: d.doSwitch()
    }

    readonly property Timer settleTimer: Timer {
        id: settleTimer
        repeat: false
        onTriggered: d.finishLoop()
    }

    readonly property Timer heartbeat: Timer {
        id: heartbeat
        interval: 1000
        repeat: true
        onTriggered: d.log("hb")
    }

    readonly property Connections walletConns: Connections {
        target: root.walletLoader
        function onActiveChanged() { d.maybeArm() }
        function onStatusChanged() { d.maybeArm() }
    }

    onReadyChanged: if (ready && enabled) Qt.callLater(d.start)
    Component.onCompleted: if (ready && enabled) Qt.callLater(d.start)
}
