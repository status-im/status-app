import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Profile.stores as ProfileStores

import SortFilterProxyModel

StatusDialog {
    id: root

    required property var community
    property ProfileStores.DevicesStore devicesStore

    width: 640

    onAboutToShow: {
        devicesStore.loadDevices()
    }

    QtObject {
        id: d
        readonly property var devices: SortFilterProxyModel {
            sourceModel: root.devicesStore.devicesModel
            sorters: [
                RoleSorter {
                    roleName: "isCurrentDevice"
                    sortOrder: Qt.DescendingOrder
                    priority: 2
                },
                RoleSorter {
                    roleName: "isMobile"
                    priority: 1 // Higher number === higher priority
                }
            ]
            proxyRoles: FastExpressionRole {
                name: "isMobile"
                expression: model.deviceType === "ios" || model.deviceType === "android"
                expectedRoles: ["deviceType"]
            }
        }
        readonly property var syncedDesktopDevices: SortFilterProxyModel {
            sourceModel: root.devicesStore.devicesModel
            filters: FastExpressionFilter {
                expectedRoles: ["isCurrentDevice", "enabled", "deviceType"]
                expression: !model.isCurrentDevice && model.enabled && (model.deviceType !== "ios" && model.deviceType !== "android")
            }
        }

        readonly property bool hasSyncedDesktopDevices: syncedDesktopDevices.count
    }

    header: StatusDialogHeader {
        headline.title: qsTr("How to move the %1 control node to another device").arg(root.community.name)
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusSmartIdenticon {
            width: 32
            height: 32
            name: root.community?.name ?? ""
            asset.name: root.community?.image ?? ""
            asset.isImage: !!asset.name
            asset.color: root.community?.color ?? ""
        }
    }

    contentItem: ColumnLayout {
        spacing: 20

        Paragraph {
            text: d.hasSyncedDesktopDevices ? qsTr("Any of your synced <b>desktop</b> devices can be the control node for this Community:")
                                            : qsTr("You don’t currently have any <b>synced desktop devices</b>. You will need to sync another desktop device before you can move the %1 control node to it. Does the device you want to use as the control node currently have Status installed?").arg(root.community.name)
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.bigPadding
            Layout.rightMargin: Theme.bigPadding
            sourceComponent: d.hasSyncedDesktopDevices ? devicesInstructions : noDevicesInstructions
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusButton {
                text: qsTr("Close")
                onClicked: root.close()
            }
        }
    }

    Component {
        id: devicesInstructions

        ColumnLayout {
            spacing: Theme.padding

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: -40
                Layout.rightMargin: -40
                Layout.preferredHeight: devicesView.implicitHeight
                Layout.fillHeight: true
                color: Theme.palette.baseColor2

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -parent.Layout.leftMargin
                    anchors.rightMargin: -parent.Layout.rightMargin
                    anchors.topMargin: 28
                    anchors.bottomMargin: 28
                    color: Theme.palette.indirectColor4
                    radius: Theme.radius
                    clip: true

                    StatusListView {
                        id: devicesView
                        width: parent.width
                        implicitHeight: contentHeight
                        height: parent.height

                        spacing: 0
                        visible: !root.devicesStore.devicesModule.devicesLoading &&
                                 !root.devicesStore.devicesModule.devicesLoadingError &&
                                 root.devicesStore.isDeviceSetup

                        model: d.devices

                        delegate: ItemDelegate {
                            id: deviceDelegate
                            width: ListView.view.width
                            implicitHeight: 64
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            horizontalPadding: Theme.padding
                            verticalPadding: 12
                            text: model.name
                            enabled: model.enabled && !model.isMobile
                            background: null
                            contentItem: RowLayout {
                                spacing: Theme.padding
                                StatusRoundIcon {
                                    Layout.alignment: Qt.AlignLeading
                                    asset.name: SQUtils.Utils.deviceIcon(model.deviceType)
                                    asset.color: model.isCurrentDevice ? Theme.palette.successColor1 : enabled ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
                                    asset.bgColor: model.isCurrentDevice ? Theme.palette.successColor3 : enabled ? Theme.palette.primaryColor3 : Theme.palette.baseColor2
                                }
                                StatusBaseText {
                                    Layout.fillWidth: true
                                    color: enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
                                    text: deviceDelegate.text
                                }
                                StatusBaseText {
                                    Layout.alignment: Qt.AlignTrailing
                                    visible: model.isCurrentDevice
                                    color: Theme.palette.successColor1
                                    text: qsTr("Control node (this device)")
                                }
                                StatusBaseText {
                                    Layout.alignment: Qt.AlignTrailing
                                    visible: model.isMobile
                                    color: Theme.palette.baseColor1
                                    text: qsTr("Not eligible (desktop only)")
                                }
                            }
                        }
                    }
                }
            }

            Instruction {
                text: qsTr("1. On the device you want to make the control node <font color='%1'>login using this profile</font>").arg(Theme.palette.directColor1)
            }
            Row {
                Layout.fillWidth: true
                spacing: 4
                Instruction {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("2. Go to")
                }
                StatusRoundIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    asset.name: "show"
                }
                Paragraph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 Admin Overview").arg(root.community.name)
                }
            }
            Instruction {
                text: qsTr("3. Click <font color='%1'>Make this device the control node</font>").arg(Theme.palette.directColor1)
            }
        }
    }

    Component {
        id: noDevicesInstructions
        ColumnLayout {
            spacing: Theme.padding

            StatusSwitchTabBar {
                id: switchBar
                Layout.fillWidth: true
                StatusSwitchTabButton {
                    text: qsTr("Status installed on other device")
                }
                StatusSwitchTabButton {
                    text: qsTr("Status not installed on other device")
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: switchBar.currentIndex
                ColumnLayout {
                    Instruction {
                        text: qsTr("On this device...")
                    }
                    Row {
                        Layout.fillWidth: true
                        spacing: 4
                        Instruction {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("1. Go to")
                        }
                        StatusRoundIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            asset.name: "settings"
                        }
                        Paragraph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Settings")
                        }
                    }
                    Row {
                        Layout.fillWidth: true
                        spacing: 4
                        Instruction {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("2. Go to")
                        }
                        StatusRoundIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            asset.name: "rotate"
                        }
                        Paragraph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Syncing")
                        }
                    }
                    Instruction {
                        text: qsTr("3. Click <font color='%1'>Setup Syncing</font> and sync your other devices").arg(Theme.palette.directColor1)
                    }
                    Instruction {
                        text: qsTr("4. Click <font color='%1'>How to move control node</font> again for next instructions").arg(Theme.palette.directColor1)
                    }
                }
                ColumnLayout {
                    Instruction {
                        text: qsTr("1. Install and launch Status on the device you want to use as the control node")
                    }
                    Instruction {
                        text: qsTr("2. On that device, click <font color='%1'>I already use Status</font>").arg(Theme.palette.directColor1)
                    }
                    Instruction {
                        text: qsTr("3. Click <font color='%1'>Scan or enter sync code</font> and sync your new device").arg(Theme.palette.directColor1)
                    }
                    Instruction {
                        text: qsTr("4. Click <font color='%1'>How to move control node</font> again for next instructions").arg(Theme.palette.directColor1)
                    }
                }
            }
        }
    }

    component Paragraph: StatusBaseText {
        Layout.fillWidth: true
        Layout.minimumHeight: 40
        font.pixelSize: Theme.primaryTextFontSize
        lineHeightMode: Text.FixedHeight
        lineHeight: 22
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
    }

    component Instruction: Paragraph {
        color: Theme.palette.baseColor1
    }
}
