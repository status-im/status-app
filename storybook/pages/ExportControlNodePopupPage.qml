import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

import AppLayouts.Communities.popups
import AppLayouts.Profile.stores as ProfileStores

import utils

import Storybook

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }

    function openDialog() {
        popupComponent.createObject(popupBg)
    }

    Component.onCompleted: openDialog()

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            id: popupBg
            anchors.fill: parent

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: openDialog()
            }
        }
    }

    ListModel {
        id: fakeDevicesModel
        ListElement {
            name: "Device 1 (osx)"
            deviceType: "osx"
            timestamp: 123456789
            isCurrentDevice: true
            enabled: true
        }
        ListElement {
            name: "Device 2 (windows)"
            deviceType: "windows"
            timestamp: 123456789123
            isCurrentDevice: false
            enabled: false
        }
        ListElement {
            name: "Device 3 (android)"
            deviceType: "android"
            timestamp: 0
            isCurrentDevice: false
            enabled: true
        }
        ListElement {
            name: "Device 4 (ios)"
            deviceType: "ios"
            timestamp: 0
            isCurrentDevice: false
            enabled: true
        }
        ListElement {
            name: "Device 5 (desktop)"
            deviceType: "desktop"
            timestamp: 0
            isCurrentDevice: false
            enabled: true
        }
    }

    Component {
        id: popupComponent
        ExportControlNodePopup {
            id: popup
            anchors.centerIn: parent
            modal: false
            visible: true
            closePolicy: Popup.NoAutoClose
            destroyOnClose: true
            community: QtObject {
                property string id: "1"
                property string name: "Socks"
                property string image: ctrlHasImage.checked ? Assets.png("tokens/UNI") : ""
                property string color: "orchid"
            }
            devicesStore: ProfileStores.DevicesStore {
                function loadDevices() {}

                property bool isDeviceSetup: true

                property var devicesModule: QtObject {
                    property bool devicesLoading
                    property bool devicesLoadingError
                }

                property var devicesModel: ctrlHasSyncedDevices.checked ? fakeDevicesModel : null
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 160

        logsView.logText: logs.logText

        Column {
            Switch {
                id: ctrlHasSyncedDevices
                text: "Has synced devices"
            }
            Switch {
                id: ctrlHasImage
                text: "Has community image"
                checked: true
            }
        }
    }
}

// category: Popups
// status: good
// https://www.figma.com/file/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?type=design&node-id=36894-685070&mode=design&t=6k1ago8SSQ5Ip9J8-0
// https://www.figma.com/file/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?type=design&node-id=37275-289960&mode=design&t=6k1ago8SSQ5Ip9J8-0
// https://www.figma.com/file/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?type=design&node-id=37275-290036&mode=design&t=6k1ago8SSQ5Ip9J8-0
