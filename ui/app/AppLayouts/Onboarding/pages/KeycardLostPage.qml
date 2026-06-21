import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import shared.status

import utils

OnboardingPage {
    id: root

    signal readSpareKeycardRequested()
    signal stopUsingKeycardForProfileRequested()

    readonly property bool isPortrait: root.width < root.height && root.width <= root.implicitWidth

    title: qsTr("Lost Keycard")

    contentItem: GridLayout {
        rows: root.isPortrait ? 2 : 1
        columns: root.isPortrait ? 1 : 2
        uniformCellWidths: !root.isPortrait

        rowSpacing: Theme.bigPadding
        columnSpacing: Theme.bigPadding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            Layout.preferredHeight: 280
            Layout.minimumWidth: 100
            Layout.minimumHeight: 100

            StatusImage {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                fillMode: Image.PreserveAspectFit
                source: Assets.png("keycard/keycards")
                mipmap: true
            }
        }

        StatusScrollView {
            id: contentScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            contentWidth: availableWidth

            ColumnLayout {
                width: contentScrollView.availableWidth
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Lost Keycard")
                    font.pixelSize: Theme.fontSize(22)
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                StatusSectionHeadline {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding
                    text: qsTr("If you don't have any other spare Keycard")
                }

                StatusListItem {
                    Layout.fillWidth: true
                    title: qsTr("Buy new")
                    subTitle: qsTr("Go to Keycard.tech and order Keycard")
                    components: [
                        StatusIcon {
                            icon: "external-link"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: {
                        root.requestOpenLink(Constants.keycard.general.purchasePage)
                    }
                }

                StatusSectionHeadline {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.padding
                    text: qsTr("If you have a spare Keycard")
                }

                StatusListItem {
                    Layout.fillWidth: true
                    title: qsTr("Read your spare Keycard")
                    subTitle: qsTr("You may need to factory reset it first and then import key pair")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: {
                        root.readSpareKeycardRequested()
                    }
                }

                StatusListItem {
                    Layout.fillWidth: true
                    title: qsTr("Start using profile without Keycard")
                    subTitle: qsTr("Enter recovery phrase for your profile and login to status.")
                    components: [
                        StatusIcon {
                            icon: "next"
                            color: Theme.palette.baseColor1
                        }
                    ]
                    onClicked: root.stopUsingKeycardForProfileRequested()
                }
            }
        }
    }
}
