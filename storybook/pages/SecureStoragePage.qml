import QtQml
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import Storybook

Page {
    id: root

    Logs { id: logs }

    function statusName(status) {
        switch (status) {
        case SecureStorage.StatusSuccess: return "Success"
        case SecureStorage.StatusNotSupported: return "NotSupported"
        case SecureStorage.StatusGenericError: return "GenericError"
        case SecureStorage.StatusUnavailable: return "Unavailable"
        case SecureStorage.StatusNotFound: return "NotFound"
        case SecureStorage.StatusIndeterminate: return "Indeterminate"
        default: return "Unknown(%1)".arg(status)
        }
    }

    SecureStorage {
        id: secureStorage

        service: "StatusStorybook.SecureStorage"

        onAvailableChanged: logs.logEvent("availableChanged", ["available"], [available])
    }

    Component.onCompleted: {
        logs.logEvent("initial state", ["service", "available"],
                      [secureStorage.service, secureStorage.available])
        if (!secureStorage.available)
            logs.logEvent("hint", ["message"],
                          ["unavailable on macOS usually means an unsigned build: the " +
                           "data-protection keychain needs keychain entitlements (proper " +
                           "code signing); every operation then reports Unavailable"])
    }

    Frame {
        anchors.fill: logsView
        anchors.margins: -1
    }

    LogsView {
        id: logsView

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 2

        height: 200

        clip: true
        logText: logs.logText
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(480, parent.width - 32)

        Text {
            text: `Secure storage available: ${secureStorage.available ? "✅" : "❌"}`
        }

        Text {
            Layout.fillWidth: true
            visible: !secureStorage.available
            wrapMode: Text.WordWrap
            text: "Unavailable — on macOS this is expected for unsigned/dev builds "
                  + "(the data-protection keychain requires code-signing entitlements). "
                  + "The operations below still run and log their status."
        }

        RowLayout {
            Text {
                text: "Account"
            }
            TextField {
                id: accountInput
                text: "1"
                placeholderText: "Account"
            }
        }
        RowLayout {
            Text {
                text: "Credential"
            }
            TextField {
                id: credentialInput
                text: "11"
                placeholderText: "Credential"
            }
        }
        RowLayout {
            // The operations stay enabled even while the backend reports unavailable:
            // they are safe (each just returns a status), and probing is exactly how an
            // unavailable backend is diagnosed.
            // This page handles storybook-typed test data only, so printing the values
            // to the console is deliberate (the app never logs real credentials).
            Button {
                text: "Set"
                onClicked: {
                    console.info(`SecureStorage.setCredential(account="${accountInput.text}", credential="${credentialInput.text}")`)
                    const status = secureStorage.setCredential(accountInput.text, credentialInput.text)
                    console.info(`SecureStorage.setCredential -> ${root.statusName(status)}`)
                    logs.logEvent("SetCredential", ["account", "status"],
                                  [accountInput.text, root.statusName(status)])
                }
            }
            Button {
                text: "Get"
                onClicked: {
                    const result = secureStorage.getCredential(accountInput.text)
                    console.info(`SecureStorage.getCredential(account="${accountInput.text}") -> `
                                 + `${root.statusName(result.status)}, credential="${result.credential}"`)
                    logs.logEvent("GetCredential", ["account", "status", "credential", "matchesInput"],
                                  [accountInput.text, root.statusName(result.status),
                                   result.credential,
                                   result.credential === credentialInput.text])
                }
            }
            Button {
                text: "Has"
                onClicked: {
                    const status = secureStorage.hasCredential(accountInput.text)
                    logs.logEvent("HasCredential", ["account", "status"],
                                  [accountInput.text, root.statusName(status)])
                }
            }
            Button {
                text: "Delete"
                onClicked: {
                    const status = secureStorage.deleteCredential(accountInput.text)
                    logs.logEvent("DeleteCredential", ["account", "status"],
                                  [accountInput.text, root.statusName(status)])
                }
            }
        }
    }
}
