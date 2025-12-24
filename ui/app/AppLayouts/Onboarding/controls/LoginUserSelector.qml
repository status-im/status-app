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
    readonly property bool keycardCreatedAccount: currentEntry.available ? currentEntry.item.keycardCreatedAccount : false

    signal onboardingCreateProfileFlowRequested()
    signal onboardingLoginFlowRequested()
    signal onboardingManageProfilesFlowRequested()

    function setSelection(keyUid: string) {
        let selection = keyUid
        if (!ModelUtils.contains(root.model, "keyUid", selection)) // get first item if not existing (or empty)
            selection = ModelUtils.get(root.model, 0, "keyUid")

        currentEntry.value = selection
    }

    QtObject {
        id: d

        readonly property int maxPopupHeight: 300
        readonly property int delegateHeight: 64
    }

    ModelEntry {
        id: currentEntry

        sourceModel: root.model
        key: "keyUid"
        value: ""
    }

    contentItem: LoginUserSelectorDelegate {
        id: userSelectorButton
        states: [
            State {
                when: currentEntry.available
                PropertyChanges {
                    target: userSelectorButton

                    label: currentEntry.item.username
                    image: currentEntry.item.thumbnailImage
                    colorId: currentEntry.item.colorId
                    keycardCreatedAccount: currentEntry.item.keycardCreatedAccount
                    keycardLocked: root.currentKeycardLocked
                    keycardEnabled: root.isKeycardEnabled
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

        bottomSheetAllowed: false

        directParent: root
        relativeY: root.height + 2
        width: root.width

        verticalPadding: Theme.halfPadding
        horizontalPadding: 0

        contentItem: ColumnLayout {
            spacing: 0
            StatusListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumHeight: d.maxPopupHeight
                id: userSelectorPanel
                model: SortFilterProxyModel {
                    id: proxyModel
                    sourceModel: root.model
                    sorters: RoleSorter {
                        roleName: "order"
                    }
                    filters: [
                        ValueFilter { // don't show the currently selected item
                            roleName: "keyUid"
                            value: root.selectedProfileKeyId
                            inverted: true
                        }
                    ]
                }
                implicitHeight: contentHeight
                spacing: 0
                delegate: LoginUserSelectorDelegate {
                    width: ListView.view.width
                    height: d.delegateHeight
                    label: model.username
                    image: model.thumbnailImage
                    colorId: model.colorId
                    keycardCreatedAccount: model.keycardCreatedAccount
                    keycardEnabled: root.isKeycardEnabled
                    enabled: !model.keycardCreatedAccount ? true : root.isKeycardEnabled
                    onClicked: {
                        dropdown.close()
                        root.setSelection(model.keyUid)
                    }
                }
            }
            StatusMenuSeparator {
                Layout.fillWidth: true
                visible: proxyModel.count > 0
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
