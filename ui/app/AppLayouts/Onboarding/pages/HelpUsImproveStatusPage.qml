import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import AppLayouts.Onboarding.controls

import utils

OnboardingPage {
    id: root

    title: qsTr("Help us improve Status")

    signal shareUsageDataRequested(bool enabled)
    signal privacyPolicyRequested()

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(400, root.availableWidth)
            spacing: root.padding
            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.fontSize(22)
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Your usage data helps us make Status better")
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StatusImage {
                Layout.preferredWidth: 300
                Layout.preferredHeight: 300
                Layout.topMargin: Theme.bigPadding
                Layout.bottomMargin: Theme.bigPadding
                Layout.alignment: Qt.AlignHCenter
                source: Assets.png("onboarding/status_totebag_artwork_1")
            }

            StatusButton {
                objectName: "btnShare"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 320
                text: qsTr("Share usage data")
                onClicked: root.shareUsageDataRequested(true)
            }
            StatusButton {
                objectName: "btnDontShare"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 320
                text: qsTr("Skip sharing")
                isOutline: true
                onClicked: root.shareUsageDataRequested(false)
            }
        }
    }

    OnboardingInfoButton {
        anchors.right: parent.right
        anchors.top: parent.top
        objectName: "infoButton"
        onClicked: helpUsImproveDetails.createObject(root).open()
    }

    Component {
        id: helpUsImproveDetails
        StatusDialog {
            objectName: "helpUsImproveDetailsPopup"
            title: qsTr("Help us improve Status")
            width: 480
            standardButtons: Dialog.Ok
            okButtonText: qsTr("Got it")
            padding: 20
            destroyOnClose: true
            contentItem: ColumnLayout {
                spacing: 20
                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("We’ll collect anonymous analytics and diagnostics from your app to enhance Status’s quality and performance.")
                    wrapMode: Text.WordWrap
                }
                OnboardingFrame {
                    Layout.fillWidth: true
                    dropShadow: false
                    padding: Theme.padding
                    cornerRadius: Theme.radius
                    contentItem: ColumnLayout {
                        spacing: 12
                        BulletPoint {
                            Layout.fillWidth:  true

                            text: qsTr("Gather basic usage data, like clicks and page views")
                            checked: true
                        }
                        BulletPoint {
                            Layout.fillWidth:  true

                            text: qsTr("Gather core diagnostics, like bandwidth usage")
                            checked: true
                        }
                        BulletPoint {
                            Layout.fillWidth:  true

                            text: qsTr("Never collect your profile information or wallet address")
                        }
                        BulletPoint {
                            Layout.fillWidth:  true

                            text: qsTr("Never collect information you input or send")
                        }
                        BulletPoint {
                            Layout.fillWidth:  true

                            text: qsTr("Never sell your usage analytics data")
                        }
                    }
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("For more details and other cases where we handle your data, refer to our %1.")
                      .arg(Utils.getStyledLink(qsTr("Privacy Policy"), "#privacy", hoveredLink, Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    onLinkActivated: {
                        if (link == "#privacy") {
                            close()
                            root.privacyPolicyRequested()
                        }
                    }
                    HoverHandler {
                        // Qt CSS doesn't support custom cursor shape
                        cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
                    }
                }
            }
        }
    }
}
