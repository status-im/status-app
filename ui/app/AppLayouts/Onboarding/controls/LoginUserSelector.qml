pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

Control {
    id: root

    // [{keyUid:string, username:string, thumbnailImage:string, colorId:int, order:int, keycardCreatedAccount:bool}]
    required property var model
    required property bool currentKeycardLocked
    required property bool isKeycardEnabled

    readonly property string selectedProfileKeyId: currentEntry.value
    readonly property var selectedProfileItem: currentEntry.available ? currentEntry.item : null
    readonly property bool keycardCreatedAccount: currentEntry.available ? currentEntry.item.keycardCreatedAccount : false

    signal onboardingCreateProfileFlowRequested()
    signal onboardingLoginFlowRequested()
    signal onboardingManageProfilesFlowRequested()

    function setSelection(keyUid: string) : void {
        let selection = keyUid
        if (!ModelUtils.contains(root.model, "keyUid", selection)) // get first item if not existing (or empty)
            selection = ModelUtils.get(root.model, 0, "keyUid")

        currentEntry.value = selection
    }

    onModelChanged: Qt.callLater(() => setSelection(selectedProfileKeyId))

    Connections {
        target: root.model?.ModelCount ?? null

        function onCountChanged() : void {
            root.setSelection(root.selectedProfileKeyId)
        }
    }

    QtObject {
        id: d

        readonly property int maxPopupHeight: 300
        readonly property int delegateHeight: 64
        readonly property int visibleProfilesCount: dropdownProfilesModel.count
    }

    ModelEntry {
        id: currentEntry

        sourceModel: root.model
        key: "keyUid"
        value: ""
    }

    SortFilterProxyModel {
        id: dropdownProfilesModel

        sourceModel: root.model
        sorters: RoleSorter {
            roleName: "order"
        }
        filters: [
            FastExpressionFilter {
                expectedRoles: ["keyUid", "username"]
                expression: !!model.keyUid && !!model.username
            },
            ValueFilter { // don't show the currently selected item
                roleName: "keyUid"
                value: root.selectedProfileKeyId
                inverted: true
            }
        ]
    }

    contentItem: LoginUserSelectorDelegate {
        id: userSelectorButton
        states: [
            State {
                when: currentEntry.available
                PropertyChanges {
                    userSelectorButton.label: currentEntry.item.username
                    userSelectorButton.image: currentEntry.item.thumbnailImage
                    userSelectorButton.colorId: currentEntry.item.colorId
                    userSelectorButton.keycardCreatedAccount: currentEntry.item.keycardCreatedAccount
                    userSelectorButton.keycardLocked: root.currentKeycardLocked
                    userSelectorButton.keycardEnabled: root.isKeycardEnabled
                }
            }
        ]
        background: Rectangle {
            color: userSelectorButton.hovered ? Theme.palette.baseColor2 : "transparent"
            border.width: 1
            border.color: Theme.palette.baseColor2
            radius: Theme.radius
        }
        rightPadding: spacing + Theme.padding + chevronIcon.width

        StatusIcon {
            id: chevronIcon
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron-down"
            color: Theme.palette.baseColor1
        }

        onClicked: dropdown.opened ? dropdown.close() : dropdown.open()
    }

    StatusDropdown {
        id: dropdown
        objectName: "dropdown"

        bottomSheetAllowed: true

        directParent: root
        relativeY: root.height + 2
        width: root.width

        verticalPadding: Theme.halfPadding
        horizontalPadding: 0

        contentItem: ColumnLayout {
            spacing: 0
            StatusScrollView {
                id: profilesScrollView

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(d.visibleProfilesCount * d.delegateHeight, d.maxPopupHeight)
                visible: d.visibleProfilesCount > 0
                contentWidth: availableWidth
                padding: 0

                ColumnLayout {
                    width: profilesScrollView.availableWidth
                    spacing: 0

                    Repeater {
                        model: dropdownProfilesModel

                        LoginUserSelectorDelegate {
                            id: profileDelegate

                            required property var model

                            readonly property bool hasProfileData: !!profileDelegate.model.keyUid && !!profileDelegate.model.username

                            Layout.fillWidth: true
                            Layout.preferredHeight: profileDelegate.hasProfileData ? d.delegateHeight : 0
                            visible: profileDelegate.hasProfileData
                            label: profileDelegate.model.username
                            image: profileDelegate.model.thumbnailImage
                            colorId: profileDelegate.model.colorId
                            keycardCreatedAccount: profileDelegate.model.keycardCreatedAccount
                            keycardEnabled: root.isKeycardEnabled
                            enabled: !profileDelegate.model.keycardCreatedAccount ? true : root.isKeycardEnabled
                            onClicked: {
                                dropdown.close()
                                root.setSelection(profileDelegate.model.keyUid)
                            }
                        }
                    }
                }
            }
            StatusMenuSeparator {
                Layout.fillWidth: true
                visible: d.visibleProfilesCount > 0
            }
            LoginUserSelectorDelegate {
                Layout.fillWidth: true
                Layout.preferredHeight: d.delegateHeight
                objectName: "createProfileDelegate"
                label: qsTr("Create profile")
                image: "add"
                isAction: true
                onClicked: {
                    dropdown.close()
                    root.onboardingCreateProfileFlowRequested()
                }
            }
            LoginUserSelectorDelegate {
                Layout.fillWidth: true
                Layout.preferredHeight: d.delegateHeight
                objectName: "logInDelegate"
                label: qsTr("Log in")
                image: "profile"
                isAction: true
                onClicked: {
                    dropdown.close()
                    root.onboardingLoginFlowRequested()
                }
            }
            LoginUserSelectorDelegate {
                Layout.fillWidth: true
                Layout.preferredHeight: d.delegateHeight
                objectName: "manageProfilesDelegate"
                label: qsTr("Manage profiles")
                image: "settings"
                isAction: true
                onClicked: {
                    dropdown.close()
                    root.onboardingManageProfilesFlowRequested()
                }
            }
        }
    }
}
