import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog

/**
 * @brief A drawer that displays the current keycard channel state.
 * 
 * This channel drawer will inform the user about the current keycard channel state.
 * It is built to avoid flasing the drawer when the state changes and allow the user to see the keycard states.
 * The drawer will display the current state and the next state will be displayed after a short delay.
 * The drawer will close automatically after the success, error or idle state is displayed.
 * Some states can be dismissed by the user.
 */

StatusDialog {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================
    
    /// The current keycard channel state from the backend
    /// Expected values: "idle", "waiting-for-keycard", "reading", "error"
    property string currentState: "idle"
    
    /// Emitted when the user dismisses the drawer without completing the operation
    signal dismissed()
    
    // ============================================================
    // INTERNAL STATE MANAGEMENT - Queue-based approach
    // ============================================================
    
    QtObject {
        id: d
        
        // Timing constants
        readonly property int minimumStateDuration: 600 // ms - minimum time to show each state
        readonly property int successDisplayDuration: 1200 // ms - how long to show success before closing
        readonly property int transitionDuration: 50 // ms - fade animation duration
        
        // Display states (internal representation)
        readonly property string stateWaitingForCard: "waiting-for-card"
        readonly property string stateReading: "reading"
        readonly property string stateSuccess: "success"
        readonly property string stateError: "error"
        readonly property string stateIdle: "" // empty = not showing anything
        
        // Current display state (what the user sees)
        property string displayState: stateIdle
        
        // State queue - stores states to be displayed
        property var stateQueue: []
        
        // Track previous backend state for success detection
        property string previousBackendState: "idle"
        
        /// Map backend state to display state
        function mapBackendStateToDisplayState(backendState) {
            switch(backendState) {
                case "waiting-for-keycard":
                    return stateWaitingForCard
                case "reading":
                    return stateReading
                case "error":
                    return stateError
                case "idle":
                    // Success detection: were we just reading?
                    if (previousBackendState === "reading") {
                        return stateSuccess
                    }
                    return stateIdle
                default:
                    return stateIdle
            }
        }
        
        /// Add a state to the queue
        function enqueueState(state) {            
            // Don't queue if it's the same as the last queued state
            if (stateQueue.length > 0 && stateQueue[stateQueue.length - 1] === state) {
                console.log("KeycardChannelDrawer: Skipping duplicate state in queue")
                return
            }
            
            // Don't queue if it's the same as current display state and queue is empty
            if (stateQueue.length === 0 && state === displayState) {
                console.log("KeycardChannelDrawer: Skipping - same as current display state")
                return
            }
            
            stateQueue.push(state)
            
            // If timer not running, start processing immediately
            if (!stateTimer.running) {
                processNextState()
            }
        }
        
        /// Process the next state from the queue
        function processNextState() {            
            if (stateQueue.length === 0) {
                return
            }
            
            const nextState = stateQueue.shift() // Remove and get first item
            
            // Set the display state
            displayState = nextState
            
            // Open drawer if showing a state
            if (nextState !== stateIdle && !root.opened) {
                root.open()
            }
            
            // Determine timer duration based on state
            if (nextState === stateSuccess) {
                stateTimer.interval = successDisplayDuration
            } else if (nextState === stateIdle) {
                // Closing - clear any remaining queue (stale states from before completion)
                root.close()
                if (stateQueue.length > 0) {
                    processNextState()
                }
                return
            } else {
                stateTimer.interval = minimumStateDuration
            }
            
            // Start timer for next transition
            stateTimer.restart()
        }
        
        /// Handle backend state changes
        function onBackendStateChanged() {
            const newDisplayState = mapBackendStateToDisplayState(root.currentState)
            
            // Special handling: Backend went to idle unexpectedly (not after reading)
            // Clear everything and close immediately
            if (newDisplayState === stateIdle && displayState !== stateSuccess) {
                console.log("KeycardChannelDrawer: Unexpected idle, clearing and closing")
                stateQueue = []
                stateTimer.stop()
                displayState = stateIdle
                previousBackendState = root.currentState
                root.close()
                return  // Don't process further
            }
            
            // Update previous state tracking
            previousBackendState = root.currentState
            
            // Enqueue the new state
            enqueueState(newDisplayState)
            
            // If we just enqueued success, also enqueue idle to close the drawer after
            if (newDisplayState === stateSuccess) {
                enqueueState(stateIdle)
            }
        }
        
        /// Clear queue and reset to idle
        function clearAndClose() {
            stateQueue = []
            stateTimer.stop()
            displayState = stateIdle
            root.close()
        }
    }
    
    // Single timer that handles all state transitions
    Timer {
        id: stateTimer
        repeat: false
        onTriggered: {
            // When timer fires, move to next state in queue
            d.processNextState()
        }
    }
    
    // Watch for backend state changes - push to queue
    onCurrentStateChanged: {
        d.onBackendStateChanged()
    }
    
    // Initialize on component load
    Component.onCompleted: {
        d.previousBackendState = root.currentState
        d.onBackendStateChanged()
    }
    
    // ============================================================
    // DIALOG CONFIGURATION
    // ============================================================
    
    closePolicy: Popup.NoAutoClose
    modal: true
    
    header: null
    footer: null
    padding: Theme.padding

    implicitWidth: 480
    
    // ============================================================
    // CONTENT
    // ============================================================
    
    contentItem: ColumnLayout {
        spacing: Theme.padding
        
        // State display area
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 300            
            // Waiting for card state
            KeycardStateDisplay {
                id: waitingDisplay
                anchors.fill: parent
                visible: opacity > 0
                opacity: d.displayState === d.stateWaitingForCard ? 1 : 0
                
                iconSource: Assets.png("onboarding/carousel/keycard")
                title: qsTr("Insert Keycard")
                description: qsTr("Please tap your Keycard to the back of your device")
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: d.transitionDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            
            // Reading state
            KeycardStateDisplay {
                id: readingDisplay
                anchors.fill: parent
                visible: opacity > 0
                opacity: d.displayState === d.stateReading ? 1 : 0
                
                iconSource: Assets.png("onboarding/status_generate_keycard")
                title: qsTr("Reading Keycard")
                description: qsTr("Please keep your Keycard in place")
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: d.transitionDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            
            // Success state
            KeycardStateDisplay {
                id: successDisplay
                anchors.fill: parent
                visible: opacity > 0
                opacity: d.displayState === d.stateSuccess ? 1 : 0
                
                iconSource: Assets.png("onboarding/status_key")
                title: qsTr("Success")
                description: qsTr("Keycard operation completed successfully")
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: d.transitionDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            
            // Error state
            KeycardStateDisplay {
                id: errorDisplay
                anchors.fill: parent
                visible: opacity > 0
                opacity: d.displayState === d.stateError ? 1 : 0
                
                iconSource: Assets.png("onboarding/status_generate_keys")
                title: qsTr("Keycard Error")
                description: qsTr("An error occurred. Please try again.")
                isError: true
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: d.transitionDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
        
        // Dismiss button (only show when not in success state)
        StatusButton {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
            Layout.leftMargin: Theme.xlPadding * 2
            Layout.rightMargin: Theme.xlPadding * 2
            // Preserve the spacing for the button even if it's not visible
            opacity: d.displayState !== d.stateSuccess && d.displayState !== d.stateIdle ? 1 : 0
            text: qsTr("Dismiss")
            type: StatusButton.Type.Normal
            
            onClicked: {
                d.clearAndClose()
                root.dismissed()
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
