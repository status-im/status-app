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
 * It is built to avoid flashing the drawer when the state changes and allow the user to see the keycard states.
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
    property string currentState: ""
    
    /// Emitted when the user dismisses the drawer without completing the operation
    signal dismissed()
    
    // ============================================================
    // STATE MANAGEMENT
    // ============================================================
    
    KeycardChannelStateManager {
        id: stateManager
        backendState: root.currentState
        
        onReadyToOpen: {
            if (!root.opened) {
                root.open()
            }
        }
        
        onReadyToClose: {
            root.close()
        }
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
        id: content
        spacing: Theme.padding
        
        // State display
        KeycardStateDisplay {
            id: stateDisplay
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            opacity: stateManager.displayState !== "" ? 1 : 0
            
            states: [
                State {
                    name: "waiting"
                    when: stateManager.displayState === stateManager.stateWaitingForCard
                    PropertyChanges {
                        target: stateDisplay
                        iconSource: Assets.png("onboarding/carousel/keycard")
                        title: qsTr("Ready to scan")
                        description: qsTr("Please tap your Keycard to the back of your device")
                        isError: false
                        showLoading: false
                    }
                },
                State {
                    name: "reading"
                    when: stateManager.displayState === stateManager.stateReading
                    PropertyChanges {
                        target: stateDisplay
                        iconSource: Assets.png("onboarding/status_generate_keycard")
                        title: qsTr("Reading Keycard")
                        description: qsTr("Please keep your Keycard in place")
                        isError: false
                        showLoading: true
                    }
                },
                State {
                    name: "success"
                    when: stateManager.displayState === stateManager.stateSuccess
                    PropertyChanges {
                        target: stateDisplay
                        iconSource: Assets.png("onboarding/status_key")
                        title: qsTr("Success")
                        description: qsTr("Keycard operation completed successfully")
                        isError: false
                        showLoading: false
                    }
                },
                State {
                    name: "error"
                when: stateManager.displayState === stateManager.stateError
                    PropertyChanges {
                        target: stateDisplay
                        iconSource: Assets.png("onboarding/status_generate_keys")
                        title: qsTr("Keycard Error")
                        description: qsTr("An error occurred. Please try again.")
                        isError: true
                        showLoading: false
                    }
                },
                State {
                    name: "not-supported"
                    when: stateManager.displayState === stateManager.stateNotSupported
                    PropertyChanges {
                        target: stateDisplay
                        iconSource: Assets.png("onboarding/status_generate_keys")
                        title: qsTr("Keycard Not Supported")
                        description: qsTr("Your device does not support keycard operations. Please try again with a different device.")
                        isError: true
                        showLoading: false
                    }
                },
                State {
                    name: "not-available"
                    when: stateManager.displayState === stateManager.stateNotAvailable
                    PropertyChanges {
                        target: stateDisplay
                        iconSource: Assets.png("onboarding/status_generate_keys")
                        title: qsTr("Keycard Not Available")
                        description: qsTr("Please enable NFC on your device to use the Keycard.")
                        isError: true
                        showLoading: false
                    }
                }
            ]
        }
        
        // Dismiss button (only show when not in success state)
        StatusButton {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
            Layout.leftMargin: Theme.xlPadding * 2
            Layout.rightMargin: Theme.xlPadding * 2
            opacity: stateManager.displayState !== "success" && stateManager.displayState !== "" ? 1 : 0
            text: qsTr("Dismiss")
            type: StatusButton.Type.Normal
            
            onClicked: {
                root.dismissed()
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: Theme.padding
        }
    }
}
