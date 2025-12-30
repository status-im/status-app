import QtQuick

import utils

/**
 * @brief State manager for KeycardChannelDrawer
 * 
 * Manages the queue-based state transitions for keycard operations.
 * Handles timing, state transitions, and provides signals for UI updates.
 * This component is separate from the UI to enable independent testing
 * and maintain separation of concerns.
 */
QtObject {
    id: root
    
    // ============================================================
    // PUBLIC API
    // ============================================================
    
    /// Input: Backend state from the keycard system
    /// Expected values: "idle", "waiting-for-keycard", "reading", "error", "not-supported", "not-available"
    property string backendState: Constants.keycardChannelState.idle
    
    /// Output: Current display state for the UI
    /// Values: "", "waiting-for-card", "reading", "success", "error", "not-supported", "not-available"
    readonly property string displayState: d.displayState
    
    /// Configuration: Minimum time to show each state (ms)
    property int minimumStateDuration: 600
    
    /// Configuration: How long to show success before closing (ms)
    property int successDisplayDuration: 1200

    // Display states definition
    // These are slightly different from the backend states
    readonly property string stateSuccess: "success"
    readonly property string stateIdle: ""
    readonly property string stateReading: Constants.keycardChannelState.reading
    readonly property string stateError: Constants.keycardChannelState.error
    readonly property string stateWaitingForCard: Constants.keycardChannelState.waitingForKeycard
    readonly property string stateNotSupported: Constants.keycardChannelState.notSupported
    readonly property string stateNotAvailable: Constants.keycardChannelState.notAvailable
    
    /// Signals
    signal readyToOpen()   // Drawer should open
    signal readyToClose()  // Drawer should close
    
    /// Public method: Clear queue and reset to idle
    function clearAndClose() {
        d.clearAndClose()
    }
    
    // ============================================================
    // INTERNAL IMPLEMENTATION
    // ============================================================
    
    property QtObject d: QtObject {
        // Current display state (what the user sees)
        property string displayState: stateIdle
        
        // State queue - stores states to be displayed
        property var stateQueue: []
        
        // Track previous backend state for success detection
        property string previousBackendState: Constants.keycardChannelState.idle
        
        /// Map backend state to display state
        function mapBackendStateToDisplayState(backendState) {
            switch(backendState) {
                case Constants.keycardChannelState.waitingForKeycard:
                case Constants.keycardChannelState.reading:
                case Constants.keycardChannelState.error:
                    return backendState
                case Constants.keycardChannelState.idle:
                    // Success detection: were we just reading?
                    if (previousBackendState === Constants.keycardChannelState.reading) {
                        return stateSuccess
                    }
                    return stateIdle
                case Constants.keycardChannelState.notSupported:
                    return stateNotSupported
                case Constants.keycardChannelState.notAvailable:
                    return stateNotAvailable
                default:
                    return stateIdle
            }
        }
        
        /// Add a state to the queue
        function enqueueState(state) {
            // Don't queue if it's the same as the last queued state
            if (stateQueue.length > 0 && stateQueue[stateQueue.length - 1] === state) {
                return
            }
            
            // Don't queue if it's the same as current display state and queue is empty
            if (stateQueue.length === 0 && state === displayState) {
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
            
            // Signal to open drawer if showing a state
            if (nextState !== stateIdle) {
                root.readyToOpen()
            }
            
            // Determine timer duration based on state
            if (nextState === stateSuccess) {
                stateTimer.interval = root.successDisplayDuration
            } else if (nextState === stateIdle) {
                // Closing - signal to close drawer
                root.readyToClose()
                // Clear any remaining queue (stale states from before completion)
                if (stateQueue.length > 0) {
                    processNextState()
                }
                return
            } else {
                stateTimer.interval = root.minimumStateDuration
            }
            
            // Start timer for next transition
            stateTimer.restart()
        }
        
        /// Handle backend state changes
        function onBackendStateChanged() {
            const newDisplayState = mapBackendStateToDisplayState(root.backendState)
            
            // Special handling: Backend went to idle unexpectedly (not after reading)
            // Clear everything and close immediately
            if (newDisplayState === stateIdle && displayState !== stateSuccess) {
                stateQueue = []
                stateTimer.stop()
                displayState = stateIdle
                previousBackendState = root.backendState
                root.readyToClose()
                return  // Don't process further
            }
            
            // Update previous state tracking
            previousBackendState = root.backendState
            
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
            root.readyToClose()
        }
    }
    
    // Single timer that handles all state transitions
    property Timer stateTimer: Timer {
        id: stateTimer
        repeat: false
        onTriggered: {
            // When timer fires, move to next state in queue
            d.processNextState()
        }
    }
    
    // Watch for backend state changes - push to queue
    onBackendStateChanged: {
        d.onBackendStateChanged()
    }
    
    // Initialize on component load
    Component.onCompleted: {
        d.previousBackendState = root.backendState
        d.onBackendStateChanged()
    }
}

