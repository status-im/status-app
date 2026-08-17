import QtQml

/*
   Latched skeleton→panel promotion for one section-chrome slot.

   `up` rises when the panel is ready and no chrome panel-switch animation is
   running — retargeting a slot mid-animation stutters it — holds through
   later animations, and drops as soon as the panel is gone (unloaded or
   re-incubating). Feed `switchOngoing` from the chrome's
   panelSwitchStarted/panelSwitchEnded pair.
*/
QtObject {
    id: root

    required property bool ready
    required property bool switchOngoing

    readonly property bool up: d.up

    readonly property QtObject d: QtObject {
        id: d

        property bool up: false

        function update() {
            if (!root.ready)
                up = false
            else if (!root.switchOngoing)
                up = true
        }
    }

    onReadyChanged: d.update()
    onSwitchOngoingChanged: d.update()
    Component.onCompleted: d.update()
}
