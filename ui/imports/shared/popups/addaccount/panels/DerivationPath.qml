import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils

import "../stores"
import "../../common"

GridLayout {
    id: root

    property AddAccountStore store

    columns: 3
    columnSpacing: Theme.padding
    rowSpacing: Theme.halfPadding

    QtObject {
        id: d

        readonly property int oneHalfWidth: (root.width - root.columnSpacing) * 0.5
    }

    StatusBaseText {
        Layout.fillWidth: true
        text: qsTr("Derivation Path")
    }

    StatusLinkText {
        objectName: "AddAccountPopup-ResetDerivationPath"
        enabled: !root.store.selectedOrigin.migratedToColdWallet &&
                 root.store.derivedAddressModel.count > 0 &&
                 root.store.addAccountModule.suggestedDerivationPath !== root.store.addAccountModule.derivationPath
        text: qsTr("Reset")
        color: enabled? Theme.palette.primaryColor1 : Theme.palette.baseColor1

        onClicked: {
            root.store.resetDerivationPath()
        }
    }

    StatusBaseText {
        Layout.preferredWidth: d.oneHalfWidth
        text: qsTr("Account")
    }

    RowLayout {
        Layout.preferredWidth: d.oneHalfWidth
        Layout.columnSpan: 2

        DerivationPathInput {
            id: derivationPathInput
            objectName: "AddAccountPopup-DerivationPathInput"

            Layout.fillWidth: true
            enabled: root.store.derivedAddressModel.count > 0

            levelsLimit: 4  // Allow only 5 separators in the derivation path

            onDerivationPathChanged: {
                let t = derivationPath
                if(t.length > 0) {
                    if(root.store.derivationPathRegEx.test(t)) {
                        root.store.changeDerivationPathPostponed(t)
                    } else {
                        root.store.addAccountModule.derivationPath = t
                    }
                }
            }

            onEditingFinished: {
                root.store.submitPopup(null)
            }

            input.rightComponent: StatusIcon {
                icon: "chevron-down"
                color: Theme.palette.baseColor1
                visible: !root.store.selectedOrigin.migratedToColdWallet

                StatusMouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        derivationPathSelection.popup(0, derivationPathInput.height + Theme.halfPadding)
                    }
                }
            }

            DerivationPathSelection {
                id: derivationPathSelection

                roots: root.store.roots
                translation: root.store.translation
                selectedRootPath: root.store.selectedRootPath

                onSelected: function(rootPath) {
                    root.store.changeRootDerivationPath(rootPath)
                    derivationPathInput.resetDerivationPath(root.store.selectedRootPath, root.store.addAccountModule.derivationPath)
                }
            }

            Component.onCompleted: {
                derivationPathInput.resetDerivationPath(root.store.selectedRootPath, root.store.addAccountModule.derivationPath)
            }
        }

        Connections {
            target: root.store.addAccountModule
            function onDerivationPathChanged() {
                derivationPathInput.resetDerivationPath(root.store.selectedRootPath, root.store.addAccountModule.derivationPath)
            }
        }

        // Propagate the error state to the store
        Binding {
            target: root.store
            property: "derivationPathEditingNotValid"
            value: derivationPathInput.errorMessage !== ""
        }
    }

    StatusListItem {
        id: generatedAddress
        objectName: "AddAccountPopup-GeneratedAddress"
        Layout.preferredWidth: d.oneHalfWidth
        Layout.preferredHeight: derivationPathInput.height
        color: "transparent"
        border.width: 1
        border.color: Theme.palette.baseColor2
        enabled: root.store.derivedAddressModel.count > 1
        statusListItemTitle.elide: Qt.ElideMiddle
        loading: root.store.derivedAddressModel.count === 0

        title: {
            if (!!root.store.selectedDerivedAddress && root.store.selectedDerivedAddress.address !== "") {
                return root.store.selectedDerivedAddress.address
            }
            else if (root.store.derivedAddressModel.count > 1) {
                return qsTr("Select address")
            }

            return Constants.zeroAddress
        }

        components: [
            StatusIcon {
                visible: root.store.derivedAddressModel.count > 1
                icon: "chevron-down"
                color: Theme.palette.baseColor1
            }
        ]

        onClicked: {
            accountAddressSelection.popup(-generatedAddress.x, generatedAddress.y + generatedAddress.height + Theme.halfPadding)
        }

        AccountAddressSelection {
            id: accountAddressSelection
            objectName: "AddAccountPopup-GeneratedAddressesList"
            width: root.width
            store: root.store

            onSelected: function(address) {
                accountAddressSelection.close()
                root.store.changeSelectedDerivedAddress(address)
            }
        }
    }

    RowLayout {
        Layout.preferredWidth: d.oneHalfWidth
        Layout.columnSpan: 2

        StatusBaseText {
            id: basePathName

            Layout.fillWidth: true
            visible: !errorMessageText.visible && !warningMessageText.visible

            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.baseColor1
            text: root.store.translation(root.store.selectedRootPath, true)
        }
        StatusBaseText {
            id: errorMessageText

            Layout.fillWidth: true
            visible: !!derivationPathInput.errorMessage

            font.pixelSize: basePathName.font.pixelSize
            color: Theme.palette.dangerColor1

            text: derivationPathInput.errorMessage
        }
        StatusBaseText {
            id: warningMessageText

            Layout.fillWidth: true
            visible: !!derivationPathInput.warningMessage

            font.pixelSize: basePathName.font.pixelSize
            color: Theme.palette.warningColor1

            text: derivationPathInput.warningMessage
        }
    }

    AddressDetails {
        Layout.preferredWidth: d.oneHalfWidth
        addressDetailsItem: root.store.selectedDerivedAddress
        defaultMessage: ""
        defaultMessageCondition: !root.store.selectedDerivedAddress || root.store.selectedDerivedAddress.address === ""
    }

    StatusCheckBox {
        objectName: "AddAccountPopup-ConfirmAddingNonEthDerivationPath"
        visible: root.store.derivationPathOutOfTheDefaultStatusDerivationTree
        Layout.fillWidth: true
        Layout.columnSpan: 3
        text: qsTr("I understand that this non-Ethereum derivation path is incompatible with Keycard")
        onToggled: {
            root.store.derivationPathOutOfTheDefaultStatusDerivationTreeConfirmed = checked
        }
    }
}
