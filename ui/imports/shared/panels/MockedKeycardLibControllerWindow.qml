import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import shared.controls

import utils

ApplicationWindow {
    id: root

    property var relatedModule

    title: qsTr("Mocked Keycard Lib Controller")
    minimumHeight: 600
    minimumWidth: 450

    QtObject {
        id: d

        property int btnWidth: 30
        property int btnHeight: 30
        property int margin: 16
        property int spacing: 16
    }

    ColumnLayout {
        id: commands
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: d.margin
        spacing: d.spacing

        StatusBaseText {
            text: qsTr("Use this buttons to control the flow")
        }

        Flow {
            Layout.fillWidth: true
            spacing: d.spacing

            StatusButton {
                text: qsTr("Plugin Reader")
                objectName: "pluginReaderButton"

                onClicked: {
                    if (!!root.relatedModule) {
                        root.relatedModule.pluginMockedReaderAction()
                    }
                }
            }

            StatusButton {
                text: qsTr("Unplug Reader")
                objectName: "unplugReaderButton"

                onClicked: {
                    if (!!root.relatedModule) {
                        root.relatedModule.unplugMockedReaderAction()
                    }
                }
            }

            StatusButton {
                text: qsTr("Tap or insert Keycard 1")
                objectName: "insertKeycard1Button"

                onClicked: {
                    if (!!root.relatedModule) {
                        root.relatedModule.insertMockedKeycardAction(1)
                    }
                }
            }

            StatusButton {
                text: qsTr("Tap or insert Keycard 2")
                objectName: "insertKeycard2Button"

                onClicked: {
                    if (!!root.relatedModule) {
                        root.relatedModule.insertMockedKeycardAction(2)
                    }
                }
            }

            StatusButton {
                text: qsTr("Remove Keycard")
                objectName: "removeKeycardButton"

                onClicked: {
                    if (!!root.relatedModule) {
                        root.relatedModule.removeMockedKeycardAction()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }
        }
    }

    MockedKeycardReaderStateSelector {
        id: readerState
        anchors.top: commands.bottom
        anchors.left: parent.left
        anchors.margins: d.margin
        anchors.topMargin: 3 * d.margin
        title: qsTr("Set initial reader state (refers to keycard 1 only)")
    }

    StatusTabBar {
        id: tabBar
        anchors.top: readerState.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: d.margin
        anchors.topMargin: 3 * d.margin

        StatusTabButton {
            width: implicitWidth
            leftPadding: 0
            text: qsTr("Keycard-1")
            objectName: "keycard1Button"
        }

        StatusTabButton {
            width: implicitWidth
            text: qsTr("Keycard-2")
            objectName: "keycard2Button"
        }
    }

    StackLayout {
        anchors.top: tabBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.halfPadding
        currentIndex: tabBar.currentIndex

        KeycardSettingsTab {
            cardIndex: 1

            onRegisterKeycard: {
                if (!!root.relatedModule) {
                    relatedModule.registerMockedKeycard(cardIndex, readerState.selectedState, kcState, kc, kcHelper)
                }
            }
        }

        KeycardSettingsTab {
            cardIndex: 2

            onRegisterKeycard: {
                if (!!root.relatedModule) {
                    relatedModule.registerMockedKeycard(cardIndex, MockedKeycardReaderStateSelector.NoKeycard, kcState, kc, kcHelper)
                }
            }
        }
    }

    component KeycardSettingsTab: StatusScrollView {
        id: keycardSettingsTabRoot

        property int cardIndex

        signal registerKeycard(int kcState, string kc, string kcHelper)

        ColumnLayout {
            spacing: d.spacing

            MockedKeycardStateSelector {
                id: keycardState
                title: qsTr("Keycard %1 - initial keycard state").arg(keycardSettingsTabRoot.cardIndex)
            }

            Column {
                id: customSection
                visible: keycardState.selectedState === MockedKeycardStateSelector.CustomKeycard
                spacing: d.spacing

                StatusInput {
                    id: mockedKeycard
                    objectName: "mockedKeycardInput"
                    label: qsTr("Mocked Keycard")
                    implicitWidth: 400
                    minimumHeight: 200
                    maximumHeight: 200
                    input.multiline: true
                    input.verticalAlignment: TextEdit.AlignTop
                    placeholderText: qsTr("Enter json form of status-go MockedKeycard")
                    errorMessageCmp.text: qsTr("Invalid json format")
                }

                StatusInput {
                    id: mockedKeycardHelper
                    objectName: "specificKeycardDetailsInput"
                    label: qsTr("Specific keycard details")
                    implicitWidth: 400
                    minimumHeight: 200
                    maximumHeight: 200
                    input.multiline: true
                    input.verticalAlignment: TextEdit.AlignTop
                    placeholderText: qsTr("Enter json form of status-go MockedKeycard")
                    errorMessageCmp.text: qsTr("Invalid json format")
                }
            }

            StatusButton {
                text: qsTr("Register Keycard")
                objectName: "registerKeycardButton"
                onClicked: {
                    if (customSection.visible) {
                        mockedKeycard.input.valid = true
                        mockedKeycardHelper.input.valid = true

                        if (mockedKeycard.text != "") {
                            try {
                                JSON.parse(mockedKeycard.text)
                            }
                            catch(e) {
                                mockedKeycard.input.valid = false
                            }
                        }
                        if (mockedKeycardHelper.text != "") {
                            try {
                                JSON.parse(mockedKeycardHelper.text)
                            }
                            catch(e) {
                                mockedKeycardHelper.input.valid = false
                            }
                        }

                        if (!mockedKeycard.input.valid || !mockedKeycardHelper.input.valid) {
                            return
                        }

                        keycardSettingsTabRoot.registerKeycard(keycardState.selectedState,
                                                               mockedKeycard.text,
                                                               mockedKeycardHelper.text)
                    }

                    keycardSettingsTabRoot.registerKeycard(keycardState.selectedState, "", "")
                }
            }
        }
    }
}
