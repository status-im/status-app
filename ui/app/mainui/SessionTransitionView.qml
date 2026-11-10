import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

// What the window shows while a session ends (see SessionView.phase on the Nim side)
Control {
    id: root

    // Mirrors SessionPhase (src/app/boot/session_view.nim)
    enum Phase {
        Active,
        Ending,
        DrainTimeout,
        LogoutTimeout,
        LogoutFailed,
        StartFailed
    }

    property int phase: SessionTransitionView.Phase.Active
    // "Close Status" on mobile, where the app is not quit from a menu
    property bool isMobile

    signal retryRequested()
    signal quitRequested()

    QtObject {
        id: d

        readonly property bool failed: root.phase === SessionTransitionView.Phase.LogoutFailed
                                       || root.phase === SessionTransitionView.Phase.StartFailed
        readonly property bool waiting: root.phase === SessionTransitionView.Phase.DrainTimeout
                                        || root.phase === SessionTransitionView.Phase.LogoutTimeout
    }

    background: Rectangle {
        color: Theme.palette.background
    }

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 2 * Theme.xlPadding, 420)
            spacing: Theme.padding

            StatusLoadingIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: !d.failed
            }

            StatusBaseText {
                objectName: "sessionTransitionTitle"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.secondaryAdditionalTextSize
                font.weight: Font.Medium
                text: {
                    switch (root.phase) {
                    case SessionTransitionView.Phase.DrainTimeout:
                        return qsTr("Finishing background work…")
                    case SessionTransitionView.Phase.LogoutTimeout:
                        return qsTr("Still signing out…")
                    case SessionTransitionView.Phase.LogoutFailed:
                        return qsTr("Signing out did not complete")
                    case SessionTransitionView.Phase.StartFailed:
                        return qsTr("Signed out, but Status could not get ready")
                    default:
                        return qsTr("Signing out…")
                    }
                }
            }

            StatusBaseText {
                objectName: "sessionTransitionDetails"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.palette.baseColor1
                visible: text !== ""
                text: {
                    switch (root.phase) {
                    case SessionTransitionView.Phase.DrainTimeout:
                    case SessionTransitionView.Phase.LogoutTimeout:
                        return qsTr("This is taking longer than usual. Status continues by itself once it's done, or you can close it now.")
                    case SessionTransitionView.Phase.LogoutFailed:
                        return qsTr("Your account may still be signed in. Try again, or close Status.")
                    case SessionTransitionView.Phase.StartFailed:
                        return qsTr("Your account is signed out, but the login screen could not be prepared. Try again, or close Status.")
                    default:
                        return ""
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.padding
                spacing: Theme.padding
                visible: d.failed || d.waiting

                StatusButton {
                    objectName: "sessionTransitionRetryButton"
                    visible: d.failed
                    text: qsTr("Retry")
                    onClicked: root.retryRequested()
                }

                StatusButton {
                    objectName: "sessionTransitionQuitButton"
                    type: d.failed ? StatusBaseButton.Type.Normal : StatusBaseButton.Type.Danger
                    text: root.isMobile ? qsTr("Close Status") : qsTr("Quit")
                    onClicked: root.quitRequested()
                }
            }
        }
    }
}
